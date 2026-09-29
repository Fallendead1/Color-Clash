--!strict
-- Remote protocol registry (GDD 11.4). The server creates every remote once under ReplicatedStorage.ColorClashNet;
-- clients look them up with a bounded wait. No remote accepts an Instance path, module name or asset id.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- name -> "reliable" | "unreliable"
Net.Remotes = table.freeze({
	-- client -> server
	Ready = "reliable", -- { ready: boolean }
	SelectLoadout = "reliable", -- weaponId: string
	Action = "reliable", -- ActionRequest table
	HeldAim = "unreliable", -- { l: lifeId, d: aim dir, o: origin }
	PaintResync = "reliable", -- { m: matchId, v: mapVersion }
	Launch = "reliable", -- { target: userId | "Base" }
	SettingsPatch = "reliable", -- { [whitelistedKey]: value }
	ClientEvent = "reliable", -- whitelisted onboarding/telemetry milestones
	-- server -> client
	ActionResult = "reliable",
	RoundState = "reliable",
	Paint = "reliable", -- (kind, matchId, mapVersion, buffer)
	Resource = "reliable",
	DamageResult = "reliable",
	Notice = "reliable",
	Effect = "unreliable",
	Roster = "reliable",
	SettingsState = "reliable",
})

local FOLDER = "ColorClashNet"

function Net.createServerRemotes(): { [string]: Instance }
	assert(RunService:IsServer(), "server only")
	local existing = ReplicatedStorage:FindFirstChild(FOLDER)
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	local out = {}
	for name, kind in Net.Remotes do
		local r = if kind == "unreliable" then Instance.new("UnreliableRemoteEvent") else Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
		out[name] = r
	end
	folder.Parent = ReplicatedStorage
	return out
end

-- Client lookup with a bounded wait; returns nil (and the caller shows an error state) instead of hanging forever.
function Net.getClientRemotes(timeout: number): { [string]: Instance }?
	local folder = ReplicatedStorage:WaitForChild(FOLDER, timeout)
	if not folder then
		return nil
	end
	local out = {}
	for name in Net.Remotes do
		local r = folder:WaitForChild(name, timeout)
		if not r then
			return nil
		end
		out[name] = r
	end
	return out
end

return Net
