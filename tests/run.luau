-- Lune runner for pure unit specs: `lune run tests/run [filter]` from the repo root.
-- Loads every src/server/Dev/unit/**/*.spec.luau, resolves shared modules from src/shared, and exits non-zero on failure.

local fs = require("@lune/fs")
local process = require("@lune/process")
local TestKit = require("../src/shared/Dev/TestKit")

local filter = process.args[1]

local function requireShared(path: string)
	return require("../src/shared/" .. path)
end

local specs = {}
local function collect(dir: string, rel: string)
	for _, name in fs.readDir(dir) do
		local full = dir .. "/" .. name
		if fs.isDir(full) then
			collect(full, rel .. name .. "/")
		elseif string.sub(name, -10) == ".spec.luau" then
			table.insert(specs, { path = rel .. string.sub(name, 1, -6), name = rel .. string.sub(name, 1, -11) })
		end
	end
end
collect("src/server/Dev/unit", "")
table.sort(specs, function(a, b)
	return a.path < b.path
end)

local all = {}
local t0 = os.clock()
for _, s in specs do
	if filter == nil or string.find(s.name, filter, 1, true) then
		local spec = require("../src/server/Dev/unit/" .. s.path)
		local results = TestKit.runSpec(s.name, spec, requireShared, "lune", os.clock)
		for _, r in results do
			table.insert(all, r)
		end
	end
end
local passed, failed, report = TestKit.summarize(all)
print(report)
print(string.format("lune unit run: %d specs, %.1f ms", #specs, (os.clock() - t0) * 1000))
if failed > 0 or passed == 0 then
	process.exit(1)
end
