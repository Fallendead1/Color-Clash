-- Pure combat/movement math: WEAPON-01/04/05/07 formulas, MOVE-01/05/06 rules, ABIL-04 limits, SEC-05/06/07/08 validators.
return function(t)
	local Ballistics = t.require("Combat/Ballistics")
	local UltimateCredit = t.require("Combat/UltimateCredit")
	local Rules = t.require("Movement/Rules")
	local Validate = t.require("Protocol/Validate")
	local GameConfig = t.require("Config/GameConfig")
	local Weapons = t.require("Config/Weapons")
	local describe, it, expect = t.describe, t.it, t.expect

	local V = vector.create

	describe("Ballistics", function()
		it("spread is deterministic and bounded", function()
			local dir = V(0, 0, -1)
			for k = 1, 200 do
				local a = Ballistics.spread(dir, 2.5, 12345, k)
				local b = Ballistics.spread(dir, 2.5, 12345, k)
				expect(a == b):toBe(true)
				local ang = math.deg(math.acos(math.clamp(vector.dot(a, dir), -1, 1)))
				expect(ang):toBeAtMost(2.5 + 1e-6)
			end
			expect(Ballistics.spread(dir, 2.5, 1, 1) == Ballistics.spread(dir, 2.5, 2, 1)):toBe(false)
		end)

		it("capsule sweep detects hits and misses", function()
			local feet = V(0, 0, -20)
			local hit = Ballistics.sweepCapsule(V(0, 3, 0), V(0, 3, -40), 0.1, feet, 5.5, 1.4)
			expect(hit ~= nil):toBe(true)
			expect(hit):toNear((20 - 1.5) / 40, 0.02)
			expect(Ballistics.sweepCapsule(V(3, 3, 0), V(3, 3, -40), 0.1, feet, 5.5, 1.4)):toBe(nil)
			expect(Ballistics.sweepCapsule(V(0, 7, 0), V(0, 7, -40), 0.1, feet, 5.5, 1.4)):toBe(nil) -- above head
		end)

		it("Sprayline needs five hits; Twin Jets six (WEAPON-01/02)", function()
			local s = Weapons.Defs.sprayline
			expect(math.ceil(100 / s.Damage)):toBe(5)
			expect(4 * s.Cadence):toNear(0.48)
			expect(math.ceil(100 / Weapons.Defs.twin_jets.Damage)):toBe(6)
		end)

		it("Linecaster charge damage and early release (WEAPON-04)", function()
			local l = Weapons.Defs.linecaster
			local d0 = Ballistics.chargeDamage(0.1, l.MinCharge, l.FullCharge, l.BaseDamage, l.ChargeDamage)
			expect(d0):toBe(nil)
			local dMin = Ballistics.chargeDamage(0.15, l.MinCharge, l.FullCharge, l.BaseDamage, l.ChargeDamage)
			expect(dMin):toNear(35)
			local dFull = Ballistics.chargeDamage(1.10, l.MinCharge, l.FullCharge, l.BaseDamage, l.ChargeDamage)
			expect(dFull):toNear(110)
			local dOver = Ballistics.chargeDamage(9, l.MinCharge, l.FullCharge, l.BaseDamage, l.ChargeDamage)
			expect(dOver):toNear(110)
		end)

		it("Popshot and Splash Can falloff (WEAPON-07, ABIL-01)", function()
			local p = Weapons.Defs.popshot
			expect(Ballistics.falloff(2, p.SplashInnerRadius, p.SplashInnerDamage, p.SplashOuterRadius, p.SplashOuterDamage)):toNear(40)
			expect(Ballistics.falloff(8, 3, 40, 8, 20)):toNear(20)
			expect(Ballistics.falloff(5.5, 3, 40, 8, 20)):toNear(30)
			expect(Ballistics.falloff(8.01, 3, 40, 8, 20)):toBe(0)
			expect(Ballistics.falloff(10, 4, 70, 10, 25)):toNear(25)
		end)

		it("fan test honours range and angle", function()
			local o = V(0, 0, 0)
			local f = V(0, 0, -1)
			expect(Ballistics.inFan(o, f, V(0, 0, -21), 22, 70)):toBe(true)
			expect(Ballistics.inFan(o, f, V(0, 0, -23), 22, 70)):toBe(false)
			expect(Ballistics.inFan(o, f, V(10, 0, -10), 22, 70)):toBe(false) -- 45 deg > 35 deg half-angle
			expect(Ballistics.inFan(o, f, V(5, 0, -10), 22, 70)):toBe(true)
			expect(Ballistics.inFan(o, f, V(0, 0, 10), 22, 70)):toBe(false)
		end)

		it("step integrates gravity", function()
			local p, v = Ballistics.step(V(0, 0, 0), V(10, 0, 0), 98.1, 1)
			-- vector components are float32
			expect(p.Y):toNear(-49.05, 1e-4)
			expect(v.Y):toNear(-98.1, 1e-4)
			expect(p.X):toNear(10, 1e-4)
		end)
	end)

	describe("Movement rules", function()
		local M = GameConfig.Movement
		local T = GameConfig.Tank
		local idle = { firing = false, charging = false, rolling = false, pushing = false, glideHeld = false }
		local function act(over)
			local a = table.clone(idle)
			for k, v in over do
				a[k] = v
			end
			return a
		end

		it("speeds per ground and action (MOVE-01)", function()
			expect(Rules.speed(M, "Standing", "Own", idle)):toBe(16)
			expect(Rules.speed(M, "Gliding", "Own", act({ glideHeld = true }))):toBe(26)
			expect(Rules.speed(M, "Standing", "Neutral", act({ glideHeld = true }))):toBe(10)
			expect(Rules.speed(M, "Standing", "Enemy", act({ glideHeld = true }))):toBe(9)
			expect(Rules.speed(M, "Standing", "Enemy", act({ pushing = true }))):toBe(9) -- enemy overrides brush bonus
			expect(Rules.speed(M, "Standing", "Own", act({ pushing = true }))):toBe(22)
			expect(Rules.speed(M, "Standing", "Own", act({ charging = true }))):toBe(10)
			expect(Rules.speed(M, "Standing", "Own", act({ rolling = true }))):toBe(12)
			expect(Rules.speed(M, "Climbing", "Own", idle)):toBe(14)
			expect(Rules.speed(M, "Standing", "Own", act({ firing = true }))):toBe(14)
		end)

		it("refill rates and delays (MOVE-05)", function()
			local r, c = Rules.refill(T, "Gliding", "Own", act({ glideHeld = true }), 0.36, false)
			expect(r):toBe(30)
			expect(c):toBe("glide")
			expect((Rules.refill(T, "Gliding", "Own", act({ glideHeld = true }), 0.3, false))):toBe(0)
			expect((Rules.refill(T, "Standing", "Own", idle, 0.7, false))):toBe(12)
			expect((Rules.refill(T, "Standing", "Own", idle, 0.6, false))):toBe(0)
			expect((Rules.refill(T, "Climbing", "Own", idle, 0.4, false))):toBe(20)
			expect((Rules.refill(T, "Standing", "Neutral", idle, 1.3, false))):toBe(6)
			expect((Rules.refill(T, "Standing", "Neutral", idle, 1.2, false))):toBe(0)
			expect((Rules.refill(T, "Standing", "Enemy", idle, 10, false))):toBe(0)
			expect((Rules.refill(T, "Airborne", "Own", idle, 10, false))):toBe(0)
			expect((Rules.refill(T, "Standing", "Base", idle, 0, true))):toBe(50)
			expect((Rules.refill(T, "Standing", "Base", act({ firing = true }), 0, true))):toBe(0) -- firing in base: no base refill (0 delay not met for own)
		end)

		it("charge/roll/push never refill (MOVE-06)", function()
			for _, key in { "charging", "rolling", "pushing" } do
				expect((Rules.refill(T, "Standing", "Own", act({ [key] = true }), 10, false))):toBe(0)
				expect((Rules.refill(T, "Standing", "Base", act({ [key] = true }), 10, true))):toBe(0)
			end
		end)

		it("boundary hysteresis holds 0.08 s but enemy applies immediately", function()
			local h = Rules.newHysteresis("Own")
			expect(Rules.updateGround(h, "Neutral", 0, 0.08)):toBe("Own")
			expect(Rules.updateGround(h, "Neutral", 0.05, 0.08)):toBe("Own")
			expect(Rules.updateGround(h, "Neutral", 0.09, 0.08)):toBe("Neutral")
			expect(Rules.updateGround(h, "Enemy", 0.10, 0.08)):toBe("Enemy")
			expect(Rules.updateGround(h, "Own", 0.11, 0.08)):toBe("Enemy")
			expect(Rules.updateGround(h, "Own", 0.20, 0.08)):toBe("Own")
		end)
	end)

	describe("Ultimate credit", function()
		local U = GameConfig.Ultimate
		it("gains changedArea/16, capped at 6 per second (ABIL-04)", function()
			local c = UltimateCredit.new(U, 0)
			local cells = {}
			for k = 1, 32 do
				cells[k] = k
			end
			expect(c:credit(cells, 0)):toNear(2)
			local many = {}
			for k = 100, 1100 do
				table.insert(many, k)
			end
			expect(c:credit(many, 0)):toNear(4) -- remaining budget this second
			expect(c:credit({ 5000 }, 0)):toNear(0)
			expect(c:credit(many, 1)):toBe(0) -- same cells within 5 s: no credit
			local fresh = {}
			for k = 2000, 2200 do
				table.insert(fresh, k)
			end
			expect(c:credit(fresh, 1)):toNear(6)
		end)

		it("same cell credits again only after 5 s", function()
			local c = UltimateCredit.new(U, 0)
			local cells = {}
			for k = 1, 16 do
				cells[k] = k
			end
			expect(c:credit(cells, 0)):toNear(1)
			expect(c:credit(cells, 4.9)):toNear(0)
			expect(c:credit(cells, 5.0)):toNear(1)
		end)

		it("spends atomically only when full and retains half on death", function()
			local c = UltimateCredit.new(U, 0)
			c.meter = 99
			expect(c:spend()):toBe(false)
			expect(c.meter):toBe(99)
			c.meter = 100
			expect(c:spend()):toBe(true)
			expect(c.meter):toBe(0)
			c.meter = 57
			c:onEliminated(0.5)
			expect(c.meter):toBe(28)
		end)
	end)

	describe("Validate", function()
		it("rejects NaN, infinity and oversized vectors (SEC-06)", function()
			expect(Validate.vector(V(1, 2, 3), 1000)):toBe(true)
			expect(Validate.vector(V(0 / 0, 0, 0), 1000)):toBe(false)
			expect(Validate.vector(V(math.huge, 0, 0), 1000)):toBe(false)
			expect(Validate.vector(V(5000, 0, 0), 1000)):toBe(false)
			expect(Validate.vector("1,2,3", 1000)):toBe(false)
			expect(Validate.vector({ X = 1, Y = 2, Z = 3 }, 1000)):toBe(false)
			expect(Validate.unitVector(V(0, 0, -1))):toBe(true)
			expect(Validate.unitVector(V(0, 0, -2))):toBe(false)
		end)

		it("rejects bad shapes and oversized tables (SEC-05)", function()
			local allowed = { a = true, b = true }
			expect(Validate.shape({ a = 1 }, allowed, 4)):toBe(true)
			expect(Validate.shape({ a = 1, c = 2 }, allowed, 4)):toBe(false)
			expect(Validate.shape({ 1, 2, 3 }, allowed, 4)):toBe(false)
			expect(Validate.shape(setmetatable({}, {}), allowed, 4)):toBe(false)
			local big = {}
			for k = 1, 100 do
				big["a" .. k] = k
			end
			expect(Validate.shape(big, allowed, 16)):toBe(false)
			expect(Validate.integer(3.5, 0, 10)):toBe(false)
			expect(Validate.string(string.rep("x", 65), 64)):toBe(false)
		end)

		it("rate limiter bounds sustained spam (SEC-08)", function()
			local rl = Validate.rateLimiter(4, 4)
			local accepted = 0
			for k = 0, 99 do
				if rl:allow("p", k * 0.01) then
					accepted += 1
				end
			end
			expect(accepted):toBeAtMost(8)
			expect(rl.rejected):toBeGreaterThan(90)
		end)

		it("cadence gate bounds long-run rate even with bursty arrival (SEC-07)", function()
			local nextReady = 0
			local accepted = 0
			-- a client spamming every 10 ms for 10 s at a 0.12 s cadence
			for k = 0, 999 do
				local ok
				ok, nextReady = Validate.cadenceAccept(nextReady, k * 0.01, 0.12, 0.05)
				if ok then
					accepted += 1
				end
			end
			expect(accepted):toBeAtMost(math.ceil(10 / 0.12) + 1)
			expect(accepted):toBeAtLeast(80)
			-- jittered but legal arrivals are all accepted
			nextReady = 0
			local legal = 0
			local tNow = 0
			for k = 1, 50 do
				tNow += if k % 2 == 0 then 0.08 else 0.16 -- average 0.12
				local ok
				ok, nextReady = Validate.cadenceAccept(nextReady, tNow, 0.12, 0.05)
				if ok then
					legal += 1
				end
			end
			expect(legal):toBe(50)
		end)
	end)
end
