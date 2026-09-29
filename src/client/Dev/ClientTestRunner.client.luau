-- DEV ONLY: client-side test runner (excluded from production builds; refuses to run outside Studio).
-- Trigger from the Studio MCP (Client datamodel):  game.Players.LocalPlayer:SetAttribute("CCClientTestRequest", "ui")
-- Result: LocalPlayer attribute CCClientTestResult; CCClientTestSeq increments per run.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local player = Players.LocalPlayer
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local TestKit = require(Shared:WaitForChild("Dev"):WaitForChild("TestKit"))
local Controllers = script.Parent.Parent:WaitForChild("Controllers")

local function requireShared(path: string)
	local node: Instance = Shared
	for part in string.gmatch(path, "[^/]+") do
		node = node:WaitForChild(part, 5) :: Instance
	end
	return require(node :: ModuleScript)
end

local function controllers()
	local out = {}
	for _, m in Controllers:GetChildren() do
		if m:IsA("ModuleScript") then
			out[m.Name] = require(m)
		end
	end
	return out
end

local running = false
player:GetAttributeChangedSignal("CCClientTestRequest"):Connect(function()
	local req = player:GetAttribute("CCClientTestRequest")
	if type(req) ~= "string" or req == "" or running then
		return
	end
	player:SetAttribute("CCClientTestRequest", "")
	running = true
	local all = {}
	local count = 0
	local t0 = os.clock()
	for _, m in script.Parent.specs:GetChildren() do
		local isPerf = string.sub(m.Name, 1, 4) == "Perf" -- heavy benchmarks run only when named explicitly
		if m:IsA("ModuleScript") and ((req == "all" and not isPerf) or string.find(string.lower(m.Name), string.lower(req), 1, true)) then
			count += 1
			local ok, spec = pcall(require, m)
			if ok then
				for _, r in TestKit.runSpec(m.Name, spec, requireShared, "studio-client", os.clock, controllers()) do
					table.insert(all, r)
				end
			else
				table.insert(all, { name = m.Name .. " (require)", ok = false, err = tostring(spec), ms = 0 })
			end
		end
	end
	local _, _, report = TestKit.summarize(all)
	local summary = string.format("[client:%s] %d specs, %.0f ms\n%s", req, count, (os.clock() - t0) * 1000, report)
	print("[ColorClash client tests] " .. summary)
	player:SetAttribute("CCClientTestResult", summary)
	player:SetAttribute("CCClientTestSeq", (player:GetAttribute("CCClientTestSeq") or 0) + 1)
	running = false
end)
