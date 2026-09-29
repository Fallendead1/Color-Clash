--!strict
-- Pure ballistic and hit-geometry math shared by server simulation and client prediction (GDD 06, 07, 08).

local Ballistics = {}

-- Deterministic spread: the server and the predicting client derive the same direction from (seed, index).
local function hash32(a: number, b: number): number
	local h = bit32.bxor(a % 4294967296, 0x9E3779B9)
	h = bit32.bxor(h, b % 4294967296)
	h = (h * 0x85EBCA6B) % 4294967296
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = (h * 0xC2B2AE35) % 4294967296
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h
end
Ballistics.hash32 = hash32

-- Rotates `dir` by a random angle within `degrees` (uniform disc), using a deterministic seed.
function Ballistics.spread(dir: vector, degrees: number, seed: number, index: number): vector
	if degrees <= 0 then
		return dir
	end
	local h1 = hash32(seed, index * 2 + 1) / 4294967296
	local h2 = hash32(seed, index * 2 + 2) / 4294967296
	local angle = math.rad(degrees) * math.sqrt(h1)
	local roll = h2 * 2 * math.pi
	-- orthonormal basis around dir
	local up = if math.abs(dir.Y) < 0.99 then vector.create(0, 1, 0) else vector.create(1, 0, 0)
	local right = vector.normalize(vector.cross(dir, up))
	local up2 = vector.cross(right, dir)
	local offset = right * math.cos(roll) + up2 * math.sin(roll)
	return vector.normalize(dir * math.cos(angle) + offset * math.sin(angle))
end

-- Position/velocity after `dt` under constant downward acceleration.
function Ballistics.step(pos: vector, vel: vector, gravity: number, dt: number): (vector, vector)
	local g = vector.create(0, -gravity, 0)
	local newPos = pos + vel * dt + g * (0.5 * dt * dt)
	return newPos, vel + g * dt
end

-- Rotates a horizontal-ish direction about the world Y axis by `degrees` (Splash Pot lobes).
function Ballistics.yaw(dir: vector, degrees: number): vector
	local a = math.rad(degrees)
	local c, s = math.cos(a), math.sin(a)
	return vector.create(dir.X * c - dir.Z * s, dir.Y, dir.X * s + dir.Z * c)
end

-- Closest distance between segment [a,b] and segment [c,d], plus the parameter t along [a,b].
function Ballistics.segmentSegment(a: vector, b: vector, c: vector, d: vector): (number, number)
	local d1 = b - a
	local d2 = d - c
	local r = a - c
	local aa = vector.dot(d1, d1)
	local ee = vector.dot(d2, d2)
	local f = vector.dot(d2, r)
	local s, t
	if aa <= 1e-9 and ee <= 1e-9 then
		return vector.magnitude(r), 0
	end
	if aa <= 1e-9 then
		s = 0
		t = math.clamp(f / ee, 0, 1)
	else
		local cc = vector.dot(d1, r)
		if ee <= 1e-9 then
			t = 0
			s = math.clamp(-cc / aa, 0, 1)
		else
			local bb = vector.dot(d1, d2)
			local denom = aa * ee - bb * bb
			s = if denom > 1e-9 then math.clamp((bb * f - cc * ee) / denom, 0, 1) else 0
			t = (bb * s + f) / ee
			if t < 0 then
				t = 0
				s = math.clamp(-cc / aa, 0, 1)
			elseif t > 1 then
				t = 1
				s = math.clamp((bb - cc) / aa, 0, 1)
			end
		end
	end
	local p1 = a + d1 * s
	local p2 = c + d2 * t
	return vector.magnitude(p1 - p2), s
end

-- Swept test of segment [a,b] (with projectile radius) against an upright capsule standing on `feet`.
-- Returns the fraction along the segment of first contact, or nil.
function Ballistics.sweepCapsule(a: vector, b: vector, projectileRadius: number, feet: vector, height: number, radius: number): number?
	local bottom = feet + vector.create(0, radius, 0)
	local top = feet + vector.create(0, math.max(radius, height - radius), 0)
	local dist, s = Ballistics.segmentSegment(a, b, bottom, top)
	if dist > radius + projectileRadius then
		return nil
	end
	-- Refine: walk back to approximate first contact (cheap bisection on the segment).
	local lo, hi = 0, s
	for _ = 1, 8 do
		local mid = (lo + hi) / 2
		local p = a + (b - a) * mid
		local dd = Ballistics.segmentSegment(p, p, bottom, top)
		if dd <= radius + projectileRadius then
			hi = mid
		else
			lo = mid
		end
	end
	return hi
end

-- Distance from a point to an upright capsule's surface (<= 0 means inside).
function Ballistics.pointCapsuleDistance(p: vector, feet: vector, height: number, radius: number): number
	local bottom = feet + vector.create(0, radius, 0)
	local top = feet + vector.create(0, math.max(radius, height - radius), 0)
	local d = Ballistics.segmentSegment(p, p, bottom, top)
	return d - radius
end

-- Linear falloff between (innerR, innerDamage) and (outerR, outerDamage); 0 beyond outerR.
function Ballistics.falloff(distance: number, innerR: number, innerDamage: number, outerR: number, outerDamage: number): number
	if distance <= innerR then
		return innerDamage
	elseif distance > outerR then
		return 0
	end
	local t = (distance - innerR) / (outerR - innerR)
	return innerDamage + (outerDamage - innerDamage) * t
end

-- Linecaster damage from server-measured charge seconds (GDD 07.3). Returns nil when the release is too early.
function Ballistics.chargeDamage(chargeSeconds: number, minCharge: number, fullCharge: number, base: number, extra: number): (number?, number)
	if chargeSeconds < minCharge then
		return nil, 0
	end
	local factor = math.clamp((chargeSeconds - minCharge) / (fullCharge - minCharge), 0, 1)
	return base + extra * factor, factor
end

-- Is `point` inside a horizontal fan (roller flick / brush sweep) from `origin` facing `forward`?
function Ballistics.inFan(origin: vector, forward: vector, point: vector, range: number, degrees: number): boolean
	local rel = point - origin
	local flat = vector.create(rel.X, 0, rel.Z)
	local dist = vector.magnitude(flat)
	if dist > range then
		return false
	end
	if dist < 1e-3 then
		return true
	end
	local f = vector.create(forward.X, 0, forward.Z)
	if vector.magnitude(f) < 1e-4 then
		return false
	end
	local cosA = vector.dot(vector.normalize(f), flat / dist)
	return cosA >= math.cos(math.rad(degrees / 2))
end

return Ballistics
