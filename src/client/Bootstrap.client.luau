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

local remotes = Net.getClientRemotes(30)
if not remotes then
	warn("[ColorClash] could not reach the server remotes (timeout)")
	player:SetAttribute("ColorClashClientError", "remotes_timeout")
	return
end

local PaintClient = require(Controllers.PaintClient)
PaintClient.start(remotes)

local roundState = nil
remotes.RoundState.OnClientEvent:Connect(function(payload)
	if type(payload) == "table" and payload.k == nil then
		roundState = payload
		player:SetAttribute("CCRoundState", payload.state)
		player:SetAttribute("CCMatchId", payload.m)
	end
end)

remotes.ClientEvent:FireServer({ k = "Milestone", name = "ClientReady" })
player:SetAttribute("ColorClashClientReady", true)
print("[ColorClash] client ready")

local _ = roundState
