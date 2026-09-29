-- Combat HUD bindings (GDD 12.1 Combat HUD, Elimination; 12.2 placement intent). Displays authoritative values from
-- the server's Resource/DamageResult messages; any local prediction is labelled as such. Updates only changed fields
-- (no full rebuild per tick).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Strings = require(Shared.UI.Strings)
local Weapons = require(Shared.Config.Weapons)
local Abilities = require(Shared.Config.Abilities)

local HudController = {}

local player = Players.LocalPlayer
local ui, cameraController, remotes, screens
local resource = { hp = 100, paint = 100, ult = 0, shield = false, alive = true, life = 0 }
local respawnDeadline: number? = nil
local lastLow = false

local function kit()
	local id = player:GetAttribute("CCWeapon") or Weapons.Default
	return Weapons.Defs[id] or Weapons.Defs[Weapons.Default]
end

local function refresh()
	local k = kit()
	local T = GameConfig.Tank
	ui.setMeter("HUD.Paint", "HUD.PaintFill", resource.paint / T.Capacity)
	ui.setText("HUD.PaintText", string.format("Paint %d", math.floor(resource.paint)))
	ui.setMeter("HUD.Health", "HUD.HealthFill", resource.hp / GameConfig.Health.Max)
	ui.setText("HUD.HealthText", string.format("Health %d", math.floor(resource.hp)))
	local ultFull = resource.ult >= GameConfig.Ultimate.Max - 1e-6
	ui.setMeter("HUD.Ultimate", "HUD.UltimateFill", resource.ult / GameConfig.Ultimate.Max)
	local ult = Abilities.Ultimates[k.Ultimate]
	ui.setText("HUD.UltimateText", if ultFull then ult.DisplayName .. " READY" else string.format("%s %d%%", ult.DisplayName, math.floor(resource.ult)))
	local gadget = Abilities.Gadgets[k.Gadget]
	local gadgetReady = resource.paint >= gadget.Cost
	ui.setText("HUD.GadgetText", string.format("%s\n%d paint%s", gadget.DisplayName, gadget.Cost, if gadgetReady then "" else " (need more)"))
	local gadgetFrame = ui.get("HUD.Gadget")
	if gadgetFrame then
		gadgetFrame:SetAttribute("Ready", gadgetReady)
		gadgetFrame.BackgroundTransparency = if gadgetReady then 0.2 else 0.6
	end
	ui.setText("HUD.Kit", k.DisplayName)
	ui.setText("HUD.Shield", if resource.shield then Strings.ShieldHit else "")
	local low = resource.paint < GameConfig.Tank.LowWarning
	if low ~= lastLow then
		lastLow = low
		ui.setText("HUD.Callout", if low then Strings.LowPaint else "")
	end
end

function HudController.resource()
	return resource
end

function HudController.start(deps)
	ui, cameraController, remotes, screens = deps.ui, deps.camera, deps.remotes, deps.screens
	remotes.Resource.OnClientEvent:Connect(function(msg)
		if type(msg) ~= "table" then
			return
		end
		for k, v in msg do
			resource[k] = v
		end
		if msg.alive == true then
			respawnDeadline = nil
			ui.setVisible("Elimination.Root", false)
		end
		refresh()
	end)
	remotes.DamageResult.OnClientEvent:Connect(function(msg)
		if type(msg) ~= "table" or msg.k ~= "Eliminated" then
			return
		end
		if msg.victim == player.UserId then
			local attacker = msg.attacker and Players:GetPlayerByUserId(msg.attacker)
			local weapon = msg.weapon and Weapons.Defs[msg.weapon]
			if attacker then
				ui.setText("Elimination.Attacker", string.format(Strings.EliminatedBy, attacker.DisplayName, weapon and weapon.DisplayName or "?"))
			else
				ui.setText("Elimination.Attacker", Strings.EliminatedEnv)
			end
			respawnDeadline = os.clock() + (msg.respawnIn or GameConfig.Match.RespawnSeconds)
			ui.setVisible("Elimination.Root", true)
		elseif msg.attacker == player.UserId and screens then
			local victim = Players:GetPlayerByUserId(msg.victim)
			screens.notice("Eliminated " .. (victim and victim.DisplayName or "an opponent"), 3)
		end
	end)
	RunService.RenderStepped:Connect(function()
		if respawnDeadline then
			local left = math.max(0, respawnDeadline - os.clock())
			ui.setText("Elimination.Countdown", string.format(Strings.Respawn, math.ceil(left)))
		end
		local aim = cameraController.aim()
		ui.setText("HUD.ReticleState", if aim.blocked then Strings.BlockedShot else "")
		local reticle = ui.get("HUD.Reticle")
		if reticle then
			reticle:SetAttribute("Blocked", aim.blocked)
			reticle.BackgroundColor3 = if aim.blocked then Color3.fromRGB(255, 80, 80) else Color3.fromRGB(240, 240, 245)
		end
	end)
	player:GetAttributeChangedSignal("CCWeapon"):Connect(refresh)
	refresh()
end

return HudController
