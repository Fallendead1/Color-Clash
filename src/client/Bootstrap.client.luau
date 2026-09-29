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

PaintClient.start(remotes)
ScreensController.start({ ui = UIController, input = InputController, paint = PaintClient, remotes = remotes })

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

remotes.ClientEvent:FireServer({ k = "Milestone", name = "ClientReady" })
player:SetAttribute("ColorClashClientReady", true)
print("[ColorClash] client ready (UI " .. (if UIController.isWireframe() then "wireframe" else "production") .. ")")
