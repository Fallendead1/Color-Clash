-- Ready roster, capacity, team formation, backfill and idle handling (GDD 03.2, 03.5, 11.3 TeamService).
-- Player attributes (replicated, read-only for clients): CCTeam (0 none, 1 A, 2 B), CCReady (bool),
-- CCParticipating (bool: part of the current match).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Teams = require(Shared.Round.Teams)
local Validate = require(Shared.Protocol.Validate)

local TeamService = {}

local M = GameConfig.Match

type Record = {
	ready: boolean,
	team: number,
	participating: boolean,
	joinedAt: number,
	lastInput: number,
	idleFlagged: boolean,
}

local records: { [Player]: Record } = {}
local net, diagnostics, round
local character, paintService -- live scoreboard stats (read only)
local kickReasons: { [Player]: string } = {}
local tieSide = 1
local rosterDirty = false

local function setAttrs(player: Player, rec: Record)
	player:SetAttribute("CCTeam", rec.team)
	player:SetAttribute("CCReady", rec.ready)
	player:SetAttribute("CCParticipating", rec.participating)
	rosterDirty = true
end

function TeamService:Init(ctx)
	net = ctx.services.NetService
	diagnostics = ctx.services.DiagnosticsService
	round = ctx.services.RoundService
	character = ctx.services.CharacterService
	paintService = ctx.services.PaintService
end

local function onJoin(player: Player)
	local now = os.clock()
	records[player] = { ready = false, team = 0, participating = false, joinedAt = now, lastInput = now, idleFlagged = false }
	setAttrs(player, records[player])
	diagnostics.event("SessionStarted", { player = player.UserId })
end

function TeamService:Start()
	for _, p in Players:GetPlayers() do
		onJoin(p)
	end
	Players.PlayerAdded:Connect(onJoin)
	Players.PlayerRemoving:Connect(function(player)
		records[player] = nil
		rosterDirty = true
		diagnostics.event("SessionEnded", TeamService.sessionEndData(player))
		kickReasons[player] = nil
	end)
	net.on("Ready", GameConfig.Net.ReadyRequestsPerSecond, function(player, payload)
		local rec = records[player]
		if not rec or not Validate.shape(payload, { ready = true }, 1) or not Validate.boolean(payload.ready) then
			diagnostics.count("Ready.rejected")
			return
		end
		TeamService.touch(player)
		if rec.ready ~= payload.ready then
			rec.ready = payload.ready
			setAttrs(player, rec)
			diagnostics.event("ReadyChanged", { player = player.UserId, ready = rec.ready })
		end
		net.fire(player, "ActionResult", { k = "Ready", ok = true, ready = rec.ready })
		if rec.ready and round then
			round.onPlayerReady(player)
		end
	end)
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(1)
			tick += 1
			TeamService.tickIdle(os.clock())
			-- live stats refresh every 2 s during a match (scoreboard); immediately on roster changes
			if rosterDirty or (tick % 2 == 0 and round and round.isMatchActive()) then
				rosterDirty = false
				net.fireAll("Roster", TeamService.roster())
			end
		end
	end)
end

-- Why a session ended (GDD 15.1, OBS-03): the KNOWN exit fact ("left" or an explicit server kick reason) is kept
-- separate from performance data, which is attached only as a labelled correlation and never as the cause.
function TeamService.sessionEndData(player: Player): { [string]: any }
	local perf = character and character.lastPerf(player)
	return {
		player = player.UserId,
		reason = kickReasons[player] or "left",
		causeInferred = false,
		lastClientFrameMsP95 = perf and perf.frameMsP95, -- correlation only; nil when unknown
	}
end

-- The only way server code removes a player: records the explicit reason first. (No latency-based kicks exist.)
function TeamService.kick(player: Player, reason: string)
	kickReasons[player] = "kicked:" .. reason
	player:Kick(reason)
end

-- Tests: mark a pending kick reason without kicking.
function TeamService.devMarkKick(player: Player, reason: string?)
	kickReasons[player] = if reason then "kicked:" .. reason else nil
end

-- Meaningful input from the player (actions, ready changes, movement reported by the character service).
function TeamService.touch(player: Player)
	local rec = records[player]
	if rec then
		rec.lastInput = os.clock()
		rec.idleFlagged = false
	end
end

-- Idle players become Unready after 60 s; idle live participants are only flagged (GDD 03.5).
function TeamService.tickIdle(now: number)
	for player, rec in records do
		if now - rec.lastInput >= M.IdleUnreadySeconds then
			if rec.ready then
				rec.ready = false
				setAttrs(player, rec)
				diagnostics.event("ReadyChanged", { player = player.UserId, ready = false, reason = "idle" })
				net.fire(player, "Notice", { k = "IdleUnready" })
			end
			if rec.participating and not rec.idleFlagged then
				rec.idleFlagged = true
				diagnostics.event("IdleInLiveRound", { player = player.UserId })
			end
		end
	end
end

function TeamService.readyPlayers(): { Player }
	local list = {}
	for player, rec in records do
		if rec.ready and player.Parent == Players then
			table.insert(list, player)
		end
	end
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)
	return list
end

function TeamService.readyCount(): number
	return #TeamService.readyPlayers()
end

-- Forms teams from ready players with a reproducible seed. Returns the participants.
function TeamService.formTeams(seed: number): { Player }
	local ready = TeamService.readyPlayers()
	local ids = {}
	local byId = {}
	for _, p in ready do
		table.insert(ids, p.UserId)
		byId[p.UserId] = p
	end
	local assignment = Teams.form(ids, seed, M.TeamCap)
	local participants = {}
	for id, side in assignment do
		local p = byId[id]
		local rec = records[p]
		rec.team = side
		rec.participating = true
		setAttrs(p, rec)
		table.insert(participants, p)
	end
	tieSide = if seed % 2 == 0 then 2 else 1
	diagnostics.event("TeamsFormed", { seed = seed, count = #participants })
	return participants
end

-- Assigns a late joiner to the smaller team (tie alternates). Returns the side or nil if full.
function TeamService.backfill(player: Player): number?
	local rec = records[player]
	if not rec or rec.participating then
		return rec and rec.team
	end
	local a, b = TeamService.teamCounts()
	local side = Teams.backfillSide(a, b, M.TeamCap, tieSide)
	if not side then
		return nil
	end
	if a == b then
		tieSide = 3 - tieSide
	end
	rec.team = side
	rec.participating = true
	setAttrs(player, rec)
	diagnostics.event("MatchJoined", { player = player.UserId, team = side, backfill = true })
	return side
end

function TeamService.teamCounts(): (number, number)
	local a, b = 0, 0
	for player, rec in records do
		if rec.participating and player.Parent == Players then
			if rec.team == 1 then
				a += 1
			elseif rec.team == 2 then
				b += 1
			end
		end
	end
	return a, b
end

function TeamService.teamOf(player: Player): number
	local rec = records[player]
	return rec and rec.team or 0
end

function TeamService.isParticipating(player: Player): boolean
	local rec = records[player]
	return rec ~= nil and rec.participating
end

function TeamService.participants(): { Player }
	local list = {}
	for player, rec in records do
		if rec.participating and player.Parent == Players then
			table.insert(list, player)
		end
	end
	return list
end

function TeamService.teamPlayers(team: number): { Player }
	local list = {}
	for player, rec in records do
		if rec.participating and rec.team == team and player.Parent == Players then
			table.insert(list, player)
		end
	end
	return list
end

-- Clears teams after a match (ready state persists; GDD 03.2).
function TeamService.clearTeams()
	for player, rec in records do
		rec.team = 0
		rec.participating = false
		setAttrs(player, rec)
	end
end

function TeamService.isReady(player: Player): boolean
	local rec = records[player]
	return rec ~= nil and rec.ready
end

-- Server-side helper for tests and dev harnesses only (no remote reaches this).
function TeamService.setReadyServer(player: Player, ready: boolean)
	local rec = records[player]
	if rec then
		rec.ready = ready
		TeamService.touch(player)
		setAttrs(player, rec)
	end
end

function TeamService.roster(): { any }
	local list = {}
	for player, rec in records do
		local s = if character then character.stats(player) else nil
		table.insert(list, {
			userId = player.UserId,
			name = player.DisplayName,
			team = rec.team,
			ready = rec.ready,
			participating = rec.participating,
			eliminations = s and s.eliminations or 0,
			assists = s and s.assists or 0,
			deaths = s and s.deaths or 0,
			paint = if paintService then paintService.contributionOf(player) else 0,
		})
	end
	table.sort(list, function(a, b)
		return a.userId < b.userId
	end)
	return list
end

return TeamService
