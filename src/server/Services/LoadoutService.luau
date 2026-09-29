-- Legal kit selection plus the server-owned paint tank and ultimate meter (GDD 05.3, 07.4, 08.2, 11.3).
-- Kits are free; selection is locked for live participants and fixed through death until intermission.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Weapons = require(Shared.Config.Weapons)
local Validate = require(Shared.Protocol.Validate)
local UltimateCredit = require(Shared.Combat.UltimateCredit)

local DevGate = require(script.Parent.Parent.DevGate)

local LoadoutService = {}

local T = GameConfig.Tank

type Record = {
	selected: string,
	locked: string?, -- kit fixed for the current match
	paint: number,
	lastUse: number, -- match-clock time of the last paint-consuming action
	ultimate: any,
}

local records: { [Player]: Record } = {}
local net, diagnostics, team, round, settings

function LoadoutService:Init(ctx)
	net = ctx.services.NetService
	diagnostics = ctx.services.DiagnosticsService
	team = ctx.services.TeamService
	round = ctx.services.RoundService
	settings = ctx.services.SettingsService
end

local function onJoin(player: Player)
	local saved = settings and settings.savedLoadout(player)
	local id = if saved and Weapons.Defs[saved] then saved else Weapons.Default
	records[player] = {
		selected = id,
		locked = nil,
		paint = T.Capacity,
		lastUse = -math.huge,
		ultimate = UltimateCredit.new(GameConfig.Ultimate, 0),
	}
	player:SetAttribute("CCWeapon", id)
end

function LoadoutService:Start()
	for _, p in Players:GetPlayers() do
		onJoin(p)
	end
	Players.PlayerAdded:Connect(onJoin)
	Players.PlayerRemoving:Connect(function(p)
		records[p] = nil
	end)
	net.on("SelectLoadout", GameConfig.Net.LoadoutRequestsPerSecond, function(player, id)
		local ok, reason = LoadoutService.select(player, id)
		net.fire(player, "ActionResult", { k = "Loadout", ok = ok, id = LoadoutService.selected(player), reason = reason })
	end)
end

-- Returns ok, reason. Rejects unknown ids and changes during live participation (UI-03).
function LoadoutService.select(player: Player, id: any): (boolean, string?)
	local rec = records[player]
	if not rec then
		return false, "no_record"
	end
	if not Validate.string(id, GameConfig.Net.MaxStringLength) or not Weapons.Defs[id] then
		diagnostics.count("Loadout.rejected.unknown")
		return false, "unknown_kit"
	end
	if rec.locked and team.isParticipating(player) and round and round.isMatchActive() then
		diagnostics.count("Loadout.rejected.locked")
		return false, "locked_in_match"
	end
	team.touch(player)
	if rec.selected ~= id then
		rec.selected = id
		player:SetAttribute("CCWeapon", id)
		if settings then
			settings.setLoadout(player, id)
		end
	end
	return true, nil
end

function LoadoutService.selected(player: Player): string
	local rec = records[player]
	return rec and rec.selected or Weapons.Default
end

-- Locks the current selection for a match participant.
function LoadoutService.lockForMatch(player: Player)
	local rec = records[player]
	if rec then
		rec.locked = rec.selected
		player:SetAttribute("CCWeapon", rec.locked)
	end
end

-- The kit in force for combat; unknown/missing falls back to the default only here (loadout recovery, GDD 11.5).
function LoadoutService.kit(player: Player): any
	local rec = records[player]
	local id = rec and (rec.locked or rec.selected) or Weapons.Default
	return Weapons.Defs[id] or Weapons.Defs[Weapons.Default]
end

function LoadoutService.unlockAll()
	for _, rec in records do
		rec.locked = nil
	end
end

---------------------------------------------------------------------------------------------------------------
-- Paint tank
---------------------------------------------------------------------------------------------------------------

function LoadoutService.paint(player: Player): number
	local rec = records[player]
	return rec and rec.paint or 0
end

-- Atomic spend: succeeds only if the full cost is available (GDD 05.3). `now` is match-clock time.
function LoadoutService.trySpend(player: Player, cost: number, now: number): boolean
	local rec = records[player]
	if not rec or cost < 0 then
		return false
	end
	if rec.paint + 1e-6 < cost then
		return false
	end
	rec.paint = math.max(0, rec.paint - cost)
	rec.lastUse = now
	return true
end

-- Continuous drain (roll/push): deducts up to `amount`; returns the amount actually deducted.
function LoadoutService.drain(player: Player, amount: number, now: number): number
	local rec = records[player]
	if not rec or amount <= 0 then
		return 0
	end
	local d = math.min(rec.paint, amount)
	rec.paint -= d
	rec.lastUse = now
	return d
end

function LoadoutService.sinceLastUse(player: Player, now: number): number
	local rec = records[player]
	return if rec then now - rec.lastUse else math.huge
end

function LoadoutService.refill(player: Player, amount: number)
	local rec = records[player]
	if rec and amount > 0 then
		rec.paint = math.min(T.Capacity, rec.paint + amount)
	end
end

function LoadoutService.fillTank(player: Player)
	local rec = records[player]
	if rec then
		rec.paint = T.Capacity
		rec.lastUse = -math.huge
	end
end

---------------------------------------------------------------------------------------------------------------
-- Ultimate meter (server-owned)
---------------------------------------------------------------------------------------------------------------

function LoadoutService.creditUltimate(player: Player, globalCells: { number })
	local rec = records[player]
	if not rec then
		return
	end
	local now = round and round.matchNow() or os.clock()
	local gained = rec.ultimate:credit(globalCells, now)
	if gained > 0 then
		diagnostics.count("Ultimate.gain", gained)
	end
end

function LoadoutService.ultimate(player: Player): number
	local rec = records[player]
	return rec and rec.ultimate.meter or 0
end

function LoadoutService.spendUltimate(player: Player): boolean
	local rec = records[player]
	return rec ~= nil and rec.ultimate:spend()
end

function LoadoutService.onEliminated(player: Player)
	local rec = records[player]
	if rec then
		rec.ultimate:onEliminated(GameConfig.Combat.UltimateRetainOnDeath)
	end
end

function LoadoutService.resetMatchResources(player: Player)
	local rec = records[player]
	if rec then
		rec.ultimate:reset(0)
		rec.paint = T.Capacity
		rec.lastUse = -math.huge
	end
end

-- Tests/dev only: set the meter directly (no remote reaches this; refused outside dev mode).
function LoadoutService.setUltimateForTests(player: Player, value: number): boolean
	local rec = records[player]
	if rec and DevGate.enabled() then
		rec.ultimate.meter = value
		return true
	end
	return false
end

-- Tests/dev only: swap the locked kit mid-match (no remote reaches this; refused outside dev mode).
function LoadoutService.devSetKit(player: Player, id: string): boolean
	local rec = records[player]
	if not rec or not DevGate.enabled() or not Weapons.Defs[id] then
		return false
	end
	rec.selected = id
	if rec.locked then
		rec.locked = id
	end
	player:SetAttribute("CCWeapon", id)
	return true
end

return LoadoutService
