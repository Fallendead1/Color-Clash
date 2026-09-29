-- Accepted actions, projectile simulation, hits, damage and attribution (GDD 06, 07, 08, 11.3 CombatService).
-- Phase 01: lifecycle skeleton used by the other services. Weapons are implemented from Phase 04 on.

local CombatService = {}

local activityByPlayer: { [Player]: any } = {}
local paused = false

local IDLE = table.freeze({ firing = false, charging = false, rolling = false, pushing = false })

function CombatService:Init(_ctx) end
function CombatService:Start() end

function CombatService.activity(player: Player)
	return activityByPlayer[player] or IDLE
end

function CombatService.onLifeStarted(player: Player, _life)
	activityByPlayer[player] = nil
end

function CombatService.onDamaged(_player: Player) end

function CombatService.onEliminated(player: Player)
	activityByPlayer[player] = nil
end

function CombatService.onGlideOrClimb(_player: Player) end

function CombatService.prepareMatch(_desc, _matchId: number) end

function CombatService.setPaused(value: boolean)
	paused = value
end

function CombatService.isPaused(): boolean
	return paused
end

function CombatService.endRound()
	table.clear(activityByPlayer)
end

function CombatService.reset()
	table.clear(activityByPlayer)
	paused = false
end

return CombatService
