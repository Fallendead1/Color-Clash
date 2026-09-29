-- The only owner of round state (GDD 03.6, 11.3 RoundService). Drives the pure RoundMachine at 10 Hz and
-- orchestrates loading, spawning, results freeze and the full reset. UI, weapons and content never run their own
-- round loops or timers.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local RoundMachine = require(Shared.Round.RoundMachine)
local Teams = require(Shared.Round.Teams)

local DevGate = require(script.Parent.Parent.DevGate)

local RoundService = {}

local M = GameConfig.Match

local net, diagnostics, team, loadout, paint, character, map, combat
local machine = nil
local loadDone, loadFailed, resetDone = false, false, false
local pausedTotal = 0
local pauseStartedAt: number? = nil
local lastResults = nil
local currentMap = nil
local serverSeed = math.random(1, 1_000_000)
local accumulator = 0
local tickConn: RBXScriptConnection? = nil

local function realNow(): number
	return Workspace:GetServerTimeNow()
end

local function settings()
	return {
		MinimumReady = DevGate.get("MinimumReady", M.PublicMinimumReady),
		Capacity = M.ServerCapacity,
		CountdownSeconds = DevGate.get("CountdownSeconds", M.CountdownSeconds),
		FullLobbyCountdownSeconds = M.FullLobbyCountdownSeconds,
		LoadingTimeoutSeconds = M.LoadingTimeoutSeconds,
		IntroSeconds = DevGate.get("IntroSeconds", M.IntroSeconds),
		LiveSeconds = DevGate.get("LiveSeconds", M.LiveSeconds),
		ResultsSeconds = DevGate.get("ResultsSeconds", M.ResultsSeconds),
		IntermissionSeconds = DevGate.get("IntermissionSeconds", M.IntermissionSeconds),
		VacancyGraceSeconds = M.VacancyGraceSeconds,
		FinalCueSeconds = M.FinalCueSeconds,
	}
end

function RoundService:Init(ctx)
	net = ctx.services.NetService
	diagnostics = ctx.services.DiagnosticsService
	team = ctx.services.TeamService
	loadout = ctx.services.LoadoutService
	paint = ctx.services.PaintService
	character = ctx.services.CharacterService
	map = ctx.services.MapService
	combat = ctx.services.CombatService
	machine = RoundMachine.new(settings(), realNow())
end

-- Match clock: real server time minus paused durations; frozen while in VacancyPause (GDD 03.6).
function RoundService.matchNow(): number
	if pauseStartedAt then
		return pauseStartedAt - pausedTotal
	end
	return realNow() - pausedTotal
end

function RoundService.state(): string
	return machine.state
end

function RoundService.matchId(): number
	return machine.matchId
end

function RoundService.isCombatLive(): boolean
	return machine.state == "Live"
end

function RoundService.isPaused(): boolean
	return machine.state == "VacancyPause"
end

function RoundService.isMatchActive(): boolean
	local s = machine.state
	return s == "Loading" or s == "Intro" or s == "Live" or s == "VacancyPause"
end

-- Authoritative deadline in real server time (for "strictly before RoundEndTime" checks).
function RoundService.roundEndTime(): number?
	return machine.roundEndTime
end

-- True when an authoritative impact at real time `t` is inside the live window (GDD 03.4).
function RoundService.acceptsImpactAt(t: number): boolean
	return machine.state == "Live" and machine.roundEndTime ~= nil and t < machine.roundEndTime
end

local function statePayload()
	local desc = currentMap
	return {
		m = machine.matchId,
		state = machine.state,
		deadline = machine.deadline,
		roundEndTime = machine.roundEndTime,
		remaining = machine:remainingLive(realNow()),
		serverNow = realNow(),
		minimumReady = machine.settings.MinimumReady,
		outcome = machine.outcome,
		map = desc and { id = desc.mapId, name = desc.displayName, fixture = desc.isFixture, version = desc.mapVersion } or nil,
	}
end

local function broadcastState()
	net.fireAll("RoundState", statePayload())
end

function RoundService.sendStateTo(player: Player)
	net.fire(player, "RoundState", statePayload())
	if lastResults and (machine.state == "Results") then
		net.fire(player, "RoundState", { k = "Results", results = lastResults })
	end
end

---------------------------------------------------------------------------------------------------------------
-- Transition work
---------------------------------------------------------------------------------------------------------------

local function beginLoading()
	loadDone, loadFailed = false, false
	local matchId = machine.matchId
	task.spawn(function()
		local desc, errors = map.loadNext()
		if machine.matchId ~= matchId or machine.state ~= "Loading" then
			return -- superseded
		end
		if not desc then
			warn("[ColorClash] map load failed: " .. table.concat(errors, "; "))
			net.fireAll("Notice", { k = "LoadingFailed", detail = errors[1] })
			loadFailed = true
			return
		end
		currentMap = desc
		paint.setMap(desc, matchId)
		character.buildBarriers()
		if combat then
			combat.prepareMatch(desc, matchId)
		end
		local seed = (serverSeed + matchId * 7919) % 2147483647
		local participants = team.formTeams(seed)
		if #participants == 0 then
			loadFailed = true
			return
		end
		local perTeam = { [1] = 0, [2] = 0 }
		for _, p in participants do
			local side = team.teamOf(p)
			perTeam[side] += 1
			loadout.lockForMatch(p)
			loadout.resetMatchResources(p)
			character.spawnForMatch(p, side, perTeam[side])
		end
		character.resetStats()
		paint.syncAll()
		diagnostics.event("MatchLoaded", { match = matchId, map = desc.mapId, fixture = desc.isFixture, players = #participants, seed = seed })
		loadDone = true
	end)
end

local function enterResults()
	local totals = paint.freeze()
	if combat then
		combat.endRound()
	end
	local outcome = machine.outcome
	local score = nil
	if totals and totals.total > 0 then
		score = Teams.score(totals.a, totals.b, totals.total)
	end
	local rows = {}
	for _, p in team.participants() do
		local s = character.stats(p)
		table.insert(rows, {
			userId = p.UserId,
			name = p.DisplayName,
			team = team.teamOf(p),
			weapon = loadout.kit(p).Id,
			paint = paint.contributionOf(p),
			eliminations = s.eliminations,
			assists = s.assists,
			deaths = s.deaths,
		})
	end
	table.sort(rows, function(a, b)
		if a.paint ~= b.paint then
			return a.paint > b.paint
		end
		return a.userId < b.userId
	end)
	local aText, bText, nText
	if score then
		aText, bText, nText = Teams.formatPercents(score)
	end
	lastResults = {
		m = machine.matchId,
		outcome = if outcome == "NoContest" then "NoContest" elseif score then score.outcome else "NoContest",
		a = score and score.a,
		b = score and score.b,
		neutral = score and score.neutral,
		total = score and score.total,
		aText = aText,
		bText = bText,
		neutralText = nText,
		hash = totals and totals.hash,
		players = rows,
		map = currentMap and currentMap.mapId,
		fixture = currentMap and currentMap.isFixture,
	}
	net.fireAll("RoundState", { k = "Results", results = lastResults })
	diagnostics.event("RoundEnded", {
		match = machine.matchId,
		outcome = lastResults.outcome,
		a = lastResults.a,
		b = lastResults.b,
		total = lastResults.total,
	})
end

local function doReset()
	resetDone = false
	if combat then
		combat.reset()
	end
	paint.clear()
	character.clearBarriers()
	map.unload()
	currentMap = nil
	team.clearTeams()
	loadout.unlockAll()
	character.returnAllToStaging()
	pausedTotal = 0
	pauseStartedAt = nil
	resetDone = true
end

local function onEvents(events)
	local changed = false
	for _, e in events do
		if e.kind == "Transition" then
			changed = true
			diagnostics.event("RoundTransition", { from = e.from, to = e.to, reason = e.reason, match = e.matchId })
			if e.to == "Loading" then
				beginLoading()
			elseif e.to == "Live" then
				if e.from == "VacancyPause" then
					if pauseStartedAt then
						pausedTotal += realNow() - pauseStartedAt
					end
					pauseStartedAt = nil
					if combat then
						combat.setPaused(false)
					end
				else
					diagnostics.event("RoundStarted", { match = machine.matchId })
				end
			elseif e.to == "VacancyPause" then
				pauseStartedAt = realNow()
				if combat then
					combat.setPaused(true)
				end
				net.fireAll("Notice", { k = "VacancyPause" })
			elseif e.to == "Results" then
				if pauseStartedAt then
					pausedTotal += realNow() - pauseStartedAt
					pauseStartedAt = nil
				end
				enterResults()
			elseif e.to == "Reset" or (e.to == "Waiting" and e.reason and string.find(e.reason, "loading")) then
				-- Normal reset, or a recoverable loading failure: undo setup and return everyone to staging. After a
				-- loading failure the machine itself decides the next state (it may already be counting down again).
				doReset()
			end
		elseif e.kind == "FinalCue" then
			net.fireAll("Notice", { k = "FinalCue" })
		elseif e.kind == "NoContest" then
			net.fireAll("Notice", { k = "NoContest", text = e.reason })
		elseif e.kind == "CountdownShortened" or e.kind == "CountdownCanceled" or e.kind == "DeadlineShifted" then
			changed = true
		end
	end
	if changed then
		broadcastState()
	end
end

function RoundService.step()
	local a, b = team.teamCounts()
	if DevGate.get("AllowEmptyTeam", false) then
		-- dev-only solo practice / 1-client tests: never pause for an empty team. Reports must say "solo practice".
		a, b = math.max(a, 1), math.max(b, 1)
	end
	local events = machine:step(realNow(), {
		readyCount = team.readyCount(),
		teamA = a,
		teamB = b,
		loadDone = loadDone,
		loadFailed = loadFailed,
		resetDone = resetDone,
	})
	if machine.state ~= "Loading" then
		loadDone, loadFailed = false, false
	end
	if machine.state ~= "Reset" then
		resetDone = false
	end
	if #events > 0 then
		onEvents(events)
	end
end

function RoundService:Start()
	tickConn = RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.1 then
			accumulator = 0
			RoundService.step()
		end
	end)
	-- periodic state heartbeat so clients re-anchor timers after drift or missed messages
	task.spawn(function()
		while tickConn do
			task.wait(5)
			broadcastState()
		end
	end)
end

function RoundService:Stop()
	if tickConn then
		tickConn:Disconnect()
		tickConn = nil
	end
end

-- Join handling (GDD 03.5): staging first; current state and paint are sent before any combat activity.
function RoundService.onPlayerJoined(player: Player)
	if player.Parent ~= Players then
		return
	end
	RoundService.sendStateTo(player)
	character.spawnInStaging(player)
	if currentMap and paint.grid() then
		paint.syncPlayer(player)
	end
end

-- A ready player during an active match backfills when the rules allow (GDD 03.5, FLOW-09/10).
function RoundService.onPlayerReady(player: Player)
	if not RoundService.isMatchActive() or team.isParticipating(player) then
		return
	end
	if machine.state == "Loading" then
		return -- teams are formed from the ready list at the end of loading
	end
	if not machine:allowsBackfill(realNow(), M.BackfillMinimumRemainingSeconds) then
		net.fire(player, "Notice", { k = "BackfillClosed" })
		return
	end
	local side = team.backfill(player)
	if not side then
		net.fire(player, "Notice", { k = "MatchFull" })
		return
	end
	loadout.lockForMatch(player)
	loadout.resetMatchResources(player) -- a late join starts at zero ultimate (GDD 08.2)
	if not paint.isSynced(player) then
		paint.syncPlayer(player)
	end
	character.spawnForMatch(player, side, nil)
	broadcastState()
end

-- Tests/dev harness: rebuild the machine settings after DevGate overrides (no remote reaches this).
function RoundService.applyDevSettings()
	if DevGate.enabled() then
		machine.settings = settings()
	end
end

-- Tests/dev harness: bring the live deadline to now (no remote reaches this; refused outside dev mode).
function RoundService.devEndLiveNow(): boolean
	if not DevGate.enabled() then
		return false
	end
	if machine.state == "Live" then
		machine.roundEndTime = realNow()
	elseif machine.state == "VacancyPause" then
		machine.graceEnd = realNow()
	end
	return true
end

function RoundService.lastResults()
	return lastResults
end

function RoundService.currentMap()
	return currentMap
end

function RoundService.machine()
	return machine
end

return RoundService
