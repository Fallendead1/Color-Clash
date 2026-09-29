--!strict
-- Minimal test framework shared by the Lune runner (tests/run.luau) and the Studio runner
-- (tests/StudioRunner.luau). A spec module returns `function(t: TestKit.Context)`.

export type Expectation = {
	toBe: (self: Expectation, expected: any) -> (),
	toEqual: (self: Expectation, expected: any) -> (),
	toNear: (self: Expectation, expected: number, epsilon: number?) -> (),
	toBeTruthy: (self: Expectation) -> (),
	toBeFalsy: (self: Expectation) -> (),
	toThrow: (self: Expectation, pattern: string?) -> (),
	toBeGreaterThan: (self: Expectation, n: number) -> (),
	toBeLessThan: (self: Expectation, n: number) -> (),
	toBeAtLeast: (self: Expectation, n: number) -> (),
	toBeAtMost: (self: Expectation, n: number) -> (),
	never: Expectation,
}

export type Context = {
	describe: (name: string, fn: () -> ()) -> (),
	it: (name: string, fn: () -> ()) -> (),
	expect: (value: any) -> Expectation,
	require: (path: string) -> any,
	env: string,
	services: any?, -- engine specs: the running service registry (Studio runner only)
}

export type Result = {
	name: string,
	ok: boolean,
	err: string?,
	ms: number,
}

local TestKit = {}

local function deepEqual(a: any, b: any, seen: { [any]: any }?): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	local s = seen or {}
	if s[a] == b then
		return true
	end
	s[a] = b
	for k, v in a do
		if not deepEqual(v, b[k], s) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end
TestKit.deepEqual = deepEqual

local function show(v: any): string
	if type(v) == "string" then
		return string.format("%q", v)
	elseif type(v) == "table" then
		local parts = {}
		local n = 0
		for k, x in v do
			n += 1
			if n > 12 then
				table.insert(parts, "...")
				break
			end
			table.insert(parts, tostring(k) .. "=" .. show(x))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end

local function makeExpect(value: any, negate: boolean): Expectation
	local e = {} :: any
	local function check(pass: boolean, message: string)
		if negate then
			pass = not pass
			message = "NOT " .. message
		end
		if not pass then
			error(message, 3)
		end
	end
	function e:toBe(expected)
		check(value == expected, "expected " .. show(value) .. " to be " .. show(expected))
	end
	function e:toEqual(expected)
		check(deepEqual(value, expected), "expected " .. show(value) .. " to deep-equal " .. show(expected))
	end
	function e:toNear(expected, epsilon)
		local eps = epsilon or 1e-6
		check(
			type(value) == "number" and math.abs(value - expected) <= eps,
			"expected " .. show(value) .. " to be within " .. eps .. " of " .. show(expected)
		)
	end
	function e:toBeTruthy()
		check(value ~= nil and value ~= false, "expected " .. show(value) .. " to be truthy")
	end
	function e:toBeFalsy()
		check(value == nil or value == false, "expected " .. show(value) .. " to be falsy")
	end
	function e:toThrow(pattern)
		local ok, err = pcall(value)
		local pass = not ok and (pattern == nil or string.find(tostring(err), pattern, 1, true) ~= nil)
		check(pass, "expected function to throw" .. (pattern and (" matching " .. show(pattern)) or "") .. ", got " .. show(err))
	end
	function e:toBeGreaterThan(n)
		check(type(value) == "number" and value > n, "expected " .. show(value) .. " > " .. show(n))
	end
	function e:toBeLessThan(n)
		check(type(value) == "number" and value < n, "expected " .. show(value) .. " < " .. show(n))
	end
	function e:toBeAtLeast(n)
		check(type(value) == "number" and value >= n, "expected " .. show(value) .. " >= " .. show(n))
	end
	function e:toBeAtMost(n)
		check(type(value) == "number" and value <= n, "expected " .. show(value) .. " <= " .. show(n))
	end
	if not negate then
		e.never = makeExpect(value, true)
	end
	return e
end

-- Runs one spec function and returns per-test results. `requireShared` resolves "Paint/Surface" style paths.
function TestKit.runSpec(
	specName: string,
	spec: (Context) -> (),
	requireShared: (string) -> any,
	env: string,
	clock: () -> number,
	services: any?
): { Result }
	local results: { Result } = {}
	local prefix: { string } = { specName }
	local ctx: Context = {} :: any
	ctx.env = env
	ctx.services = services
	ctx.require = requireShared
	ctx.expect = function(v)
		return makeExpect(v, false)
	end
	ctx.describe = function(name, fn)
		table.insert(prefix, name)
		local ok, err = pcall(fn)
		if not ok then
			table.insert(results, { name = table.concat(prefix, " > ") .. " (describe body)", ok = false, err = tostring(err), ms = 0 })
		end
		table.remove(prefix)
	end
	ctx.it = function(name, fn)
		local t0 = clock()
		local ok, err = xpcall(fn, function(e)
			return tostring(e)
		end)
		table.insert(results, {
			name = table.concat(prefix, " > ") .. " > " .. name,
			ok = ok,
			err = if ok then nil else tostring(err),
			ms = (clock() - t0) * 1000,
		})
	end
	local ok, err = pcall(spec, ctx)
	if not ok then
		table.insert(results, { name = specName .. " (load)", ok = false, err = tostring(err), ms = 0 })
	end
	return results
end

function TestKit.summarize(all: { Result }): (number, number, string)
	local passed, failed = 0, 0
	local lines = {}
	for _, r in all do
		if r.ok then
			passed += 1
		else
			failed += 1
			table.insert(lines, "FAIL " .. r.name .. "\n     " .. (r.err or "?"))
		end
	end
	table.insert(lines, string.format("%d passed, %d failed, %d total", passed, failed, passed + failed))
	return passed, failed, table.concat(lines, "\n")
end

return TestKit
