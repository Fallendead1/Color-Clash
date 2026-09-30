-- Client entry point. Starts one controller stack for the whole session (a respawn never starts a second stack;
-- GDD 11.3). Controllers rebind to new characters themselves.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
if player:GetAttribute("ColorClashClientStarted") then
	warn("[ColorClash] duplicate client bootstrap ignored")
	return
end
player:SetAttribute("ColorClashClientStarted", true)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Protocol.Net)

local Controllers = script.Parent.Controllers
local InputController = require(Controllers.InputController)
local UIController = require(Controllers.UIController)
local PaintClient = require(Controllers.PaintClient)
local ScreensController = require(Controllers.ScreensController)
local CameraController = require(Controllers.CameraController)
local MovementController = require(Controllers.MovementController)
local HudController = require(Controllers.HudController)
local TouchController = require(Controllers.TouchController)
local EffectsController = require(Controllers.EffectsController)
local WeaponController = require(Controllers.WeaponController)
local TacticalMapController = require(Controllers.TacticalMapController)
local SettingsController = require(Controllers.SettingsController)
local ScoreboardController = require(Controllers.ScoreboardController)
local PresentationController = require(Controllers.PresentationController)

InputController.start()
UIController.start(InputController)

local remotes = Net.getClientRemotes(30)
if not remotes then
	warn("[ColorClash] could not reach the server remotes (timeout)")
	player:SetAttribute("ColorClashClientError", "remotes_timeout")
	UIController.setVisible("Loading.Root", true)
	UIController.setText("Loading.Stage", "Couldn't reach the server")
	UIController.setVisible("Loading.Back", false)
	UIController.setVisible("Loading.Retry", false)
	return
end

PaintClient.setRenderer(require(script.Parent.Paint.NativeRenderer).new())
PaintClient.start(remotes)
ScreensController.start({ ui = UIController, input = InputController, paint = PaintClient, remotes = remotes })
CameraController.start(InputController)
MovementController.start({ input = InputController, paint = PaintClient, camera = CameraController, remotes = remotes })
HudController.start({ ui = UIController, camera = CameraController, remotes = remotes, screens = ScreensController })
TouchController.start(UIController, InputController)
EffectsController.start({ ui = UIController, remotes = remotes })
WeaponController.start({
	input = InputController,
	camera = CameraController,
	movement = MovementController,
	paint = PaintClient,
	effects = EffectsController,
	remotes = remotes,
	ui = UIController,
	hud = HudController,
})
TacticalMapController.start({ ui = UIController, input = InputController, paint = PaintClient, remotes = remotes })
ScoreboardController.start({ ui = UIController, input = InputController, remotes = remotes })
PresentationController.start({
	remotes = remotes,
	weapon = WeaponController,
	movement = MovementController,
	effects = EffectsController,
	ui = UIController,
})
SettingsController.start({
	ui = UIController,
	input = InputController,
	camera = CameraController,
	paint = PaintClient,
	effects = EffectsController,
	remotes = remotes,
})

PaintClient.onChange(function(kind)
	if kind == "map" or kind == "clear" then
		CameraController.refreshGeometry()
		EffectsController.refreshGeometry()
	end
end)

-- The match id travels with every action; keep it current from authoritative round state.
remotes.RoundState.OnClientEvent:Connect(function(payload)
	if type(payload) == "table" and payload.k == nil and payload.m then
		player:SetAttribute("CCMatchId", payload.m)
		player:SetAttribute("CCRoundState", payload.state)
	end
end)

-- Gameplay input context: combat actions only while alive in a live match; panels push "Menu" on top.
local function refreshContext()
	local round = ScreensController.round()
	local live = round ~= nil and round.state == "Live"
	local alive = player:GetAttribute("CCAlive") == true
	local participating = player:GetAttribute("CCParticipating") == true
	UIController.setGameplayContext(if live and alive and participating then "Gameplay" else "Disabled")
end
remotes.RoundState.OnClientEvent:Connect(function()
	task.defer(refreshContext)
end)
for _, attr in { "CCAlive", "CCParticipating", "CCLifeId" } do
	player:GetAttributeChangedSignal(attr):Connect(function()
		InputController.releaseAll(attr)
		refreshContext()
	end)
end
refreshContext()

-- Shoulder camera for match participants (Intro/Live/Pause); the default camera in staging, where the player uses
-- menus with a free mouse.
local function refreshCamera()
	local round = ScreensController.round()
	local s = round and round.state
	local inMatch = player:GetAttribute("CCParticipating") == true and (s == "Intro" or s == "Live" or s == "VacancyPause")
	local alive = player:GetAttribute("CCAlive") == true and player.Character ~= nil
	local want = inMatch and alive
	if want ~= CameraController.isActive() then
		CameraController.setActive(want)
	end
end
remotes.RoundState.OnClientEvent:Connect(function()
	task.defer(refreshCamera)
end)
for _, attr in { "CCAlive", "CCParticipating" } do
	player:GetAttributeChangedSignal(attr):Connect(refreshCamera)
end
player.CharacterAdded:Connect(function(character)
	character:WaitForChild("HumanoidRootPart", 10)
	if CameraController.isActive() then
		CameraController.setActive(true) -- rebind to the new character
	end
	refreshCamera()
end)
refreshCamera()

remotes.ClientEvent:FireServer({ k = "Milestone", name = "ClientReady" })
player:SetAttribute("ColorClashClientReady", true)
print("[ColorClash] client ready (UI " .. (if UIController.isWireframe() then "wireframe" else "production") .. ")")
