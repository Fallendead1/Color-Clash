-- Engine combat tests (Sprayline vertical slice) in a live solo-practice match on the fixture.
-- Uses CombatService.handleAction with exact client-shaped payloads (the same validation path as the remote).
-- Victims: the fixture's stationary damage capsules (practice targets), with configurable team.
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local S = t.services
	local H = require(S.Dev.MatchHarness)
	local Weapons = require(game.ReplicatedStorage.Shared.Config.Weapons)
	local Workspace = game:GetService("Workspace")

	local SPRAY = Weapons.Defs.sprayline

	describe("Combat vertical slice (fixture, solo practice)", function()
		local p, team
		local seq = 1000

		local function life()
			return S.CharacterService.life(p)
		end

		local function payload(dir: Vector3, overrides)
			seq += 1
			local l = life()
			local msg = {
				m = S.RoundService.matchId(),
				l = l.lifeId,
				s = seq,
				a = "Fire",
				t = Workspace:GetServerTimeNow(),
				o = l.root.Position + Vector3.new(0, 1.1, 0),
				d = dir.Unit,
			}
			for k, v in overrides or {} do
				msg[k] = v
			end
			return msg
		end

		local function fireAt(target: Vector3, overrides)
			local l = life()
			local origin = l.root.Position + Vector3.new(0, 1.1, 0)
			local msg = payload(target - origin, overrides)
			S.CombatService.handleAction(p, msg)
			return msg
		end

		local function target(i)
			return S.CombatService.targets()[i]
		end

		local function moveTarget(i, feet: Vector3)
			local tg = target(i)
			tg.feet = feet
			tg.part.CFrame = CFrame.new(feet + Vector3.new(0, 2.75, 0)) * CFrame.Angles(0, 0, math.rad(90))
			tg.health = 100
			tg.alive = true
			tg.part.Transparency = 0
			tg.part:SetAttribute("Health", 100)
		end

		local function refillAndClearShield()
			S.LoadoutService.fillTank(p)
			S.CharacterService.onOffensiveAction(p)
		end

		it("starts a live solo match with the player outside the base", function()
			p, team = H.startSolo(S)
			-- the saved profile may hold any kit (real DataStore in Studio): this slice is Sprayline
			S.LoadoutService.devSetKit(p, "sprayline")
			H.place(S, p, Vector3.new(0, 100, -4), Vector3.new(1, 0, 0))
			task.wait(0.4)
			refillAndClearShield()
			expect(#S.CombatService.targets()):toBe(3)
		end)

		it("COMBAT-01 an enemy target takes 24; a friendly target takes nothing; cost is exactly 1.8", function()
			moveTarget(1, Vector3.new(10, 100, -4))
			S.CombatService.setTargetTeam(1, if team == 1 then "B" else "A")
			local before = S.LoadoutService.paint(p)
			fireAt(target(1).feet + Vector3.new(0, 3, 0))
			expect(S.LoadoutService.paint(p)):toNear(before - SPRAY.Cost, 1e-6)
			expect(H.waitFor(function()
				return target(1).health < 100
			end, 1)):toBe(true)
			expect(target(1).health):toBe(100 - SPRAY.Damage)
			-- friendly target
			moveTarget(2, Vector3.new(10, 100, 4))
			S.CombatService.setTargetTeam(2, if team == 1 then "A" else "B")
			task.wait(0.15)
			fireAt(target(2).feet + Vector3.new(0, 3, 0))
			task.wait(0.4)
			expect(target(2).health):toBe(100)
		end)

		it("WEAPON-01 five hits eliminate; first to fifth impact ~0.48 s at cadence", function()
			moveTarget(1, Vector3.new(10, 100, -4))
			S.CombatService.setTargetTeam(1, "Any")
			refillAndClearShield()
			local times = {}
			local healths = {}
			local lastHealth = 100
			local acceptedBefore = S.DiagnosticsService.getCount("ShotAccepted.sprayline")
			local counters0 = S.DiagnosticsService.counters()
			-- the Health attribute changes synchronously on every applied hit (no frame-ordering race)
			local conn = target(1).part:GetAttributeChangedSignal("Health"):Connect(function()
				local h = target(1).part:GetAttribute("Health")
				if h ~= lastHealth then
					lastHealth = h
					table.insert(times, os.clock())
					table.insert(healths, h)
				end
			end)
			for k = 1, 5 do
				fireAt(target(1).feet + Vector3.new(0, 3, 0))
				if k < 5 then
					task.wait(SPRAY.Cadence + 0.005)
				end
			end
			H.waitFor(function()
				return not target(1).alive
			end, 1.5)
			conn:Disconnect()
			local rejected = {}
			for k, v in S.DiagnosticsService.counters() do
				if string.find(k, "ShotRejected", 1, true) and v ~= (counters0[k] or 0) then
					table.insert(rejected, k .. "+" .. (v - (counters0[k] or 0)))
				end
			end
			workspace:SetAttribute("CCWeapon01Diag", string.format("healths=%s accepted=%d rejected=%s dup=%d", table.concat(healths, ","), S.DiagnosticsService.getCount("ShotAccepted.sprayline") - acceptedBefore, table.concat(rejected, ","), S.DiagnosticsService.getCount("Damage.duplicateSuppressed")))
			expect(target(1).alive):toBe(false)
			expect(#times):toBe(5)
			expect(times[5] - times[1]):toNear(0.48, 0.08)
		end)

		it("COMBAT-02 re-sending the same sequence is rejected: one cost, one hit", function()
			moveTarget(1, Vector3.new(10, 100, -4))
			refillAndClearShield()
			task.wait(0.2)
			local msg = payload((target(1).feet + Vector3.new(0, 3, 0)) - (life().root.Position + Vector3.new(0, 1.1, 0)))
			local before = S.LoadoutService.paint(p)
			S.CombatService.handleAction(p, msg)
			S.CombatService.handleAction(p, table.clone(msg))
			S.CombatService.handleAction(p, table.clone(msg))
			expect(S.LoadoutService.paint(p)):toNear(before - SPRAY.Cost, 1e-6)
			task.wait(0.3)
			expect(target(1).health):toBe(100 - SPRAY.Damage)
		end)

		it("COMBAT-03 thin cover blocks the shot (swept collision, no penetration)", function()
			-- thin_cover spans x 15.75..16.25, z -14..-6, 7 high
			H.place(S, p, Vector3.new(11, 100, -10), Vector3.new(1, 0, 0))
			task.wait(0.4)
			refillAndClearShield()
			moveTarget(1, Vector3.new(19, 100, -10))
			task.wait(0.15)
			local before = S.DiagnosticsService.getCount("ShotAccepted.sprayline")
			fireAt(target(1).feet + Vector3.new(0, 2.5, 0))
			task.wait(0.4)
			expect(S.DiagnosticsService.getCount("ShotAccepted.sprayline")):toBe(before + 1)
			expect(target(1).health):toBe(100)
		end)

		it("COMBAT-04 an empty tank fires nothing and costs nothing; the dry cue is rate limited", function()
			H.place(S, p, Vector3.new(0, 100, -4), Vector3.new(1, 0, 0))
			task.wait(0.4)
			moveTarget(1, Vector3.new(10, 100, -4))
			S.LoadoutService.drain(p, 200, S.RoundService.matchNow())
			local projectiles = S.CombatService.projectileCount()
			local dryBefore = S.DiagnosticsService.getCount("ShotRejected.dry")
			for _ = 1, 5 do
				fireAt(target(1).feet + Vector3.new(0, 3, 0))
				task.wait(0.13)
			end
			expect(S.CombatService.projectileCount()):toBe(projectiles)
			expect(S.LoadoutService.paint(p) < 2):toBe(true)
			expect(S.DiagnosticsService.getCount("ShotRejected.dry") - dryBefore):toBe(5)
			task.wait(0.3)
			expect(target(1).health):toBe(100)
		end)

		it("COMBAT-08 no firing from inside the protected base; shots stop at an enemy base boundary", function()
			local ownX = if team == 1 then -40 else 40
			H.place(S, p, Vector3.new(ownX, 100, 8), Vector3.new(0, 0, 1))
			task.wait(0.4)
			refillAndClearShield()
			local baseBefore = S.DiagnosticsService.getCount("ShotRejected.base")
			fireAt(Vector3.new(0, 101, 8))
			expect(S.DiagnosticsService.getCount("ShotRejected.base")):toBe(baseBefore + 1)
			-- from outside toward a target standing inside the enemy base
			local enemyX = if team == 1 then 40 else -40
			local standX = if team == 1 then 24 else -24
			H.place(S, p, Vector3.new(standX, 100, 8), Vector3.new(if team == 1 then 1 else -1, 0, 0))
			task.wait(0.4)
			refillAndClearShield()
			moveTarget(1, Vector3.new(enemyX, 100, 8))
			local blockedBefore = S.DiagnosticsService.getCount("Shot.blockedByBase")
			fireAt(target(1).feet + Vector3.new(0, 3, 0))
			task.wait(0.4)
			expect(S.DiagnosticsService.getCount("Shot.blockedByBase")):toBe(blockedBefore + 1)
			expect(target(1).health):toBe(100)
		end)

		it("COMBAT-09 the respawn shield is removed by the first legal attack", function()
			H.place(S, p, Vector3.new(0, 100, -4), Vector3.new(1, 0, 0))
			task.wait(0.4)
			S.LoadoutService.fillTank(p)
			life().shieldUntil = S.RoundService.matchNow() + 2
			expect(S.CharacterService.isShielded(p)):toBe(true)
			task.wait(0.15)
			fireAt(Vector3.new(10, 101, -4))
			expect(S.CharacterService.isShielded(p)):toBe(false)
		end)

		it("a floor shot paints the impact footprint and trail drips for the shooter's team", function()
			refillAndClearShield()
			local grid = S.PaintService.grid()
			local before = grid.totals[team]
			task.wait(0.15)
			fireAt(Vector3.new(12, 100, -12)) -- aim at the floor ahead
			task.wait(0.4)
			expect(grid.totals[team] - before):toBeGreaterThan(8)
		end)

		it("SEC-02..07 malformed, forged, stale and replayed payloads are rejected without cost or effect", function()
			refillAndClearShield()
			task.wait(0.15)
			local base = S.LoadoutService.paint(p)
			local count = S.CombatService.projectileCount()
			local l = life()
			local bad = {
				payload(Vector3.new(1, 0, 0), { o = Vector3.new(0 / 0, 0, 0) }), -- NaN
				payload(Vector3.new(1, 0, 0), { o = Vector3.new(1e9, 0, 0) }), -- far out of bounds
				payload(Vector3.new(1, 0, 0), { o = l.root.Position + Vector3.new(30, 0, 0) }), -- impossible muzzle
				payload(Vector3.new(1, 0, 0), { d = Vector3.new(3, 0, 0) }), -- not a unit vector
				payload(Vector3.new(1, 0, 0), { t = Workspace:GetServerTimeNow() + 5 }), -- future time
				payload(Vector3.new(1, 0, 0), { t = Workspace:GetServerTimeNow() - 10 }), -- ancient time
				payload(Vector3.new(1, 0, 0), { l = l.lifeId - 1 }), -- old life
				payload(Vector3.new(1, 0, 0), { m = S.RoundService.matchId() + 7 }), -- wrong match
				payload(Vector3.new(1, 0, 0), { damage = 999 }), -- extra key (forged stats)
				payload(Vector3.new(1, 0, 0), { s = "12" }), -- wrong type
				"Fire", -- not a table
			}
			for _, msg in bad do
				S.CombatService.handleAction(p, msg)
			end
			expect(S.LoadoutService.paint(p)):toBe(base)
			expect(S.CombatService.projectileCount()):toBe(count)
		end)

		it("SEC-07/08 impossible cadence: a burst of 40 shots in one frame is bounded", function()
			refillAndClearShield()
			task.wait(0.2)
			local before = S.DiagnosticsService.getCount("ShotAccepted.sprayline")
			for _ = 1, 40 do
				fireAt(Vector3.new(10, 101, -4))
			end
			local accepted = S.DiagnosticsService.getCount("ShotAccepted.sprayline") - before
			expect(accepted):toBeAtMost(2)
			expect(accepted):toBeAtLeast(1)
		end)

		it("FLOW-07 a shot fired before the deadline that lands after it has no effect", function()
			refillAndClearShield()
			moveTarget(1, Vector3.new(25, 100, -4)) -- ~25 studs: flight ~0.14 s
			task.wait(0.2)
			local grid = S.PaintService.grid()
			local hash = grid:hash()
			S.RoundService.machine().roundEndTime = Workspace:GetServerTimeNow() + 0.03
			fireAt(target(1).feet + Vector3.new(0, 3, 0))
			task.wait(0.5)
			expect(target(1).health):toBe(100)
			expect(grid.frozen or grid:hash() == hash):toBe(true)
			H.waitFor(function()
				return S.RoundService.state() ~= "Live"
			end, 2)
			expect(S.RoundService.state() ~= "Live"):toBe(true)
			expect(S.CombatService.projectileCount()):toBe(0) -- nothing left in flight after the round ends
		end)

		it("ends the dev match", function()
			H.stop(S)
			expect(S.RoundService.state()):toBe("Waiting")
		end)
	end)
end
