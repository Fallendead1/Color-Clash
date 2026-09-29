-- Engine (server) Phase 03 tests in a live solo-practice match on the fixture.
-- MOVE-05 refill conditions against the authoritative tank, MOVE-09 regeneration, climb validation, spawn shield,
-- out-of-bounds elimination (environmental).
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local S = t.services
	local H = require(S.Dev.MatchHarness)
	local GameConfig = require(game.ReplicatedStorage.Shared.Config.GameConfig)

	describe("Phase 03 server rules (solo practice, fixture)", function()
		local p, team

		it("starts a live solo match", function()
			p, team = H.startSolo(S)
			expect(team == 1 or team == 2):toBe(true)
		end)

		it("spawn shield blocks damage, then the first offensive action removes it", function()
			local l = S.CharacterService.life(p)
			l.shieldUntil = S.RoundService.matchNow() + 2
			expect(S.CharacterService.applyDamage(p, 10, nil, "test")):toBe("shielded")
			expect(l.health):toBe(100)
			S.CharacterService.onOffensiveAction(p)
			expect(S.CharacterService.isShielded(p)):toBe(false)
		end)

		-- Measures refill over `seconds` from an empty tank at `pos` with the given glide flag.
		local function refillOver(pos: Vector3, glide: boolean, seconds: number): (number, string)
			H.place(S, p, pos, Vector3.new(0, 0, 1))
			local l = S.CharacterService.life(p)
			task.wait(0.6) -- ground classification + hysteresis settle
			l.glideHeld = glide
			S.LoadoutService.drain(p, 200, S.RoundService.matchNow())
			local start = S.LoadoutService.paint(p)
			task.wait(seconds)
			return S.LoadoutService.paint(p) - start, l.ground
		end

		it("MOVE-05 own paint standing: 12/s after 0.65 s", function()
			H.paintFloor(S, -10, -4, -30, -24, team)
			local gained, ground = refillOver(Vector3.new(-7, 100, -27), false, 2)
			expect(ground):toBe("Own")
			expect(gained):toNear(12 * (2 - 0.65), 2.5)
		end)

		it("MOVE-05 own paint gliding: 30/s after 0.35 s", function()
			local gained, ground = refillOver(Vector3.new(-7, 100, -27), true, 2)
			expect(ground):toBe("Own")
			expect(gained):toNear(30 * (2 - 0.35), 5)
		end)

		it("MOVE-05 neutral floor standing: 6/s after 1.25 s", function()
			H.paintFloor(S, 4, 10, -30, -24, 0)
			local gained, ground = refillOver(Vector3.new(7, 100, -27), false, 2)
			expect(ground):toBe("Neutral")
			expect(gained):toNear(6 * (2 - 1.25), 1.5)
		end)

		it("MOVE-05 enemy paint: no refill, even gliding", function()
			H.paintFloor(S, 20, 26, -30, -24, 3 - team)
			local gained, ground = refillOver(Vector3.new(23, 100, -27), true, 1.5)
			expect(ground):toBe("Enemy")
			expect(gained):toBe(0)
		end)

		it("MOVE-05 protected base, not firing: 50/s immediately (capped at 100)", function()
			local x = if team == 1 then -40 else 40
			local gained = refillOver(Vector3.new(x, 100, 6), false, 1)
			expect(gained):toNear(50, 7)
			task.wait(1.5)
			expect(S.LoadoutService.paint(p)):toBe(GameConfig.Tank.Capacity)
		end)

		it("MOVE-09 regeneration waits 3 s, then 20/s; new damage restarts the delay", function()
			H.place(S, p, Vector3.new(-7, 100, -27), Vector3.new(0, 0, 1))
			local l = S.CharacterService.life(p)
			S.CharacterService.onOffensiveAction(p)
			expect(S.CharacterService.applyDamage(p, 40, nil, "test")):toBe("applied")
			expect(l.health):toBe(60)
			task.wait(2.6)
			expect(l.health):toBe(60)
			task.wait(1.4) -- ~0.9-1.0 s of regen at 20/s
			expect(l.health):toBeGreaterThan(70)
			expect(l.health):toBeLessThan(85)
			S.CharacterService.applyDamage(p, 10, nil, "test")
			local after = l.health
			task.wait(2.5)
			expect(l.health):toNear(after, 0.01)
			task.wait(1.5)
			expect(l.health):toBeGreaterThan(after)
		end)

		it("climb is legal only on an own-colour climbable wall", function()
			H.paintSurface(S, "platform_climb_south", team)
			H.place(S, p, Vector3.new(0, 100, 12.4), Vector3.new(0, 0, 1))
			task.wait(0.3)
			local l = S.CharacterService.life(p)
			expect(S.CharacterService.validClimb(l)):toBe(true)
			H.paintSurface(S, "platform_climb_south", 3 - team)
			expect(S.CharacterService.validClimb(l)):toBe(false)
			-- a non-climbable wall is never climbable
			H.place(S, p, Vector3.new(-18, 100, -10), Vector3.new(1, 0, 0)) -- facing the neutral wall
			task.wait(0.3)
			expect(S.CharacterService.validClimb(l)):toBe(false)
		end)

		it("falling into the out-of-bounds volume eliminates once and respawns", function()
			local before = S.CharacterService.stats(p).deaths
			local life = S.CharacterService.life(p).lifeId
			local l = S.CharacterService.life(p)
			S.CharacterService.teleport(p, CFrame.new(60, 60, 60)) -- inside the OOB volume (y 40..80)
			expect(H.waitFor(function()
				return not S.CharacterService.isAlive(p)
			end, 2)):toBe(true)
			expect(S.CharacterService.stats(p).deaths):toBe(before + 1)
			expect(H.waitFor(function()
				local nl = S.CharacterService.life(p)
				return nl ~= nil and nl.lifeId ~= life and nl.alive
			end, 7)):toBe(true)
			local _ = l
		end)

		it("ends the dev match", function()
			H.stop(S)
			expect(S.RoundService.state()):toBe("Waiting")
		end)
	end)
end
