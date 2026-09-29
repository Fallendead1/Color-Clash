-- DEV ONLY: in-game test runner (excluded from production builds; also refuses to run outside Studio).
-- Runs specs inside the live server VM so engine tests use the real running services.
--
-- Trigger from the Studio MCP (server datamodel during Play):
--   game.ServerScriptService:SetAttribute("CCTestRequest", "unit")            -- pure specs in Dev/unit
--   game.ServerScriptService:SetAttribute("CCTestRequest", "engine")          -- all engine specs in Dev/engine
--   game.ServerScriptService:SetAttribute("CCTestRequest", "engine:Round")    -- engine specs whose name contains "Round"
-- Results: attribute CCTestResult (summary text), CCTestSeq increments per completed run.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = script.Parent.Parent
local DevGate = require(Server.DevGate)
if not DevGate.enabled() then
	return
end

local TestKit = require(script.Parent.lib.TestKit)
local Shared = ReplicatedStorage:WaitForChild("Shared")

local function requireShared(path: string)
	local node: Instance = Shared
	for part in string.gmatch(path, "[^/]+") do
		node = node:WaitForChild(part, 5) :: Instance
		assert(node, "shared module not found: " .. path)
	end
	return require(node :: ModuleScript)
end

local function services()
	local out = {}
	for _, m in Server.Services:GetChildren() do
		if m:IsA("ModuleScript") then
			out[m.Name] = require(m)
		end
	end
	out.DevGate = DevGate
	out.Dev = script.Parent
	return out
end

local function collect(folder: Instance?, prefix: string, filter: string?, into: { any })
	if not folder then
		return
	end
	for _, d in folder:GetDescendants() do
		if d:IsA("ModuleScript") and string.sub(d.Name, -5) == ".spec" then
			local name = prefix .. string.sub(d.Name, 1, -6)
			if filter == nil or string.find(name, filter, 1, true) then
				table.insert(into, { name = name, module = d })
			end
		end
	end
	table.sort(into, function(a, b)
		return a.name < b.name
	end)
end

local running = false
local function run(request: string)
	if running then
		return
	end
	running = true
	local kind, filter = string.match(request, "^(%a+):?(.*)$")
	if filter == "" then
		filter = nil
	end
	local specs = {}
	if kind == "unit" then
		collect(script.Parent:FindFirstChild("unit"), "unit/", filter, specs)
	elseif kind == "engine" then
		collect(script.Parent:FindFirstChild("engine"), "engine/", filter, specs)
	end
	local all = {}
	local t0 = os.clock()
	local svc = services()
	for _, s in specs do
		local ok, spec = pcall(require, s.module)
		if not ok then
			table.insert(all, { name = s.name .. " (require)", ok = false, err = tostring(spec), ms = 0 })
		else
			for _, r in TestKit.runSpec(s.name, spec, requireShared, "studio-server", os.clock, svc) do
				table.insert(all, r)
			end
		end
	end
	local _, _, report = TestKit.summarize(all)
	local summary = string.format("[%s] %d specs, %.0f ms\n%s", request, #specs, (os.clock() - t0) * 1000, report)
	print("[ColorClash tests] " .. summary)
	ServerScriptService:SetAttribute("CCTestResult", summary)
	ServerScriptService:SetAttribute("CCTestSeq", (ServerScriptService:GetAttribute("CCTestSeq") or 0) + 1)
	running = false
end

ServerScriptService:GetAttributeChangedSignal("CCTestRequest"):Connect(function()
	local req = ServerScriptService:GetAttribute("CCTestRequest")
	if type(req) == "string" and req ~= "" then
		ServerScriptService:SetAttribute("CCTestRequest", "")
		task.spawn(run, req)
	end
end)
