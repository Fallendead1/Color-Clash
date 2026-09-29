--!strict
-- Cheap, allocation-light validators for remote payloads (GDD 11.4, 14.4). Every server handler checks shape,
-- types, finite numbers and bounds BEFORE doing any expensive work. Pure: runs in Roblox and Lune.

local Validate = {}

local function isFinite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end
Validate.isFinite = isFinite

function Validate.number(n: any, min: number, max: number): boolean
	return isFinite(n) and n >= min and n <= max
end

function Validate.integer(n: any, min: number, max: number): boolean
	return isFinite(n) and n >= min and n <= max and math.floor(n) == n
end

function Validate.string(s: any, maxLen: number): boolean
	return type(s) == "string" and #s > 0 and #s <= maxLen
end

function Validate.boolean(b: any): boolean
	return type(b) == "boolean"
end

-- Accepts Roblox Vector3 or Luau vector; rejects NaN/inf and components beyond `bound`.
function Validate.vector(v: any, bound: number): boolean
	local t = typeof(v)
	if t ~= "Vector3" and t ~= "vector" then
		return false
	end
	local x, y, z = v.X, v.Y, v.Z
	return isFinite(x) and isFinite(y) and isFinite(z) and math.abs(x) <= bound and math.abs(y) <= bound and math.abs(z) <= bound
end

function Validate.unitVector(v: any): boolean
	if not Validate.vector(v, 2) then
		return false
	end
	local m = vector.magnitude(v)
	return m > 0.98 and m < 1.02
end

-- Table with only string keys from `allowed`, at most `maxKeys` entries, no metatable.
function Validate.shape(t: any, allowed: { [string]: boolean }, maxKeys: number): boolean
	if type(t) ~= "table" or getmetatable(t) ~= nil then
		return false
	end
	local n = 0
	for k in t do
		n += 1
		if n > maxKeys or type(k) ~= "string" or not allowed[k] then
			return false
		end
	end
	return true
end

function Validate.oneOf(v: any, set: { [string]: any }): boolean
	return type(v) == "string" and set[v] ~= nil
end

-- Sliding-window rate limiter keyed by player/user id and channel.
export type RateLimiter = {
	allow: (self: RateLimiter, key: any, now: number) -> boolean,
	forget: (self: RateLimiter, key: any) -> (),
	rejected: number,
}

function Validate.rateLimiter(perSecond: number, burst: number?): RateLimiter
	local capacity = burst or math.max(1, perSecond)
	local buckets: { [any]: { tokens: number, at: number } } = {}
	local limiter = { rejected = 0 } :: any
	function limiter:allow(key: any, now: number): boolean
		local b = buckets[key]
		if not b then
			b = { tokens = capacity, at = now }
			buckets[key] = b
		end
		b.tokens = math.min(capacity, b.tokens + (now - b.at) * perSecond)
		b.at = now
		if b.tokens >= 1 then
			b.tokens -= 1
			return true
		end
		self.rejected += 1
		return false
	end
	function limiter:forget(key: any)
		buckets[key] = nil
	end
	return limiter
end

-- Cadence gate: accepts an action if `now` is not earlier than the next ready time minus a jitter tolerance.
-- Long-run rate never exceeds 1/cadence because nextReady advances by cadence per accepted action and cannot lag
-- more than `tolerance` behind real time.
function Validate.cadenceAccept(nextReady: number, now: number, cadence: number, tolerance: number): (boolean, number)
	if now + tolerance < nextReady then
		return false, nextReady
	end
	return true, math.max(nextReady, now - tolerance) + cadence
end

return Validate
