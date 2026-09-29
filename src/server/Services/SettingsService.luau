-- Validated preferences and graceful persistence (GDD 11.6, 11.3 SettingsService).
-- Phase 01: in-memory store with the final API. Phase 07 adds the DataStore path, read-failure safety and debounced
-- writes behind this same interface.

local Players = game:GetService("Players")

local SettingsService = {}

local profiles: { [Player]: { loadout: string? } } = {}

function SettingsService:Init(_ctx) end

function SettingsService:Start()
	Players.PlayerRemoving:Connect(function(p)
		profiles[p] = nil
	end)
end

function SettingsService.savedLoadout(player: Player): string?
	local p = profiles[player]
	return p and p.loadout
end

function SettingsService.setLoadout(player: Player, id: string)
	local p = profiles[player]
	if not p then
		p = {}
		profiles[player] = p
	end
	p.loadout = id
end

return SettingsService
