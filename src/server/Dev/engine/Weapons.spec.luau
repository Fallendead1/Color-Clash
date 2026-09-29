-- Engine tests for all seven weapons (Phase 05) in a live solo-practice match on the fixture, using the real
-- validation path (CombatService.handleAction) and fixture damage capsules as victims.
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local S = t.services
	local H = require(S.Dev.MatchHarness)
	local Weapons = require(game.ReplicatedStorage.Shared.Config.Weapons)
	local Workspace = game:GetService("Workspace")
	local RunService = game:GetService("RunService")
	local W = Weapons.Defs

	describe("Seven weapons (fixture, solo practice)", function()
		local p, team
		local seq = 200000

		local function life()
			return S.CharacterService.life(p)
		end
		local function muzzle()
			return life().root.Position + Vector3.new(0, 1.1, 0)
		end
		local function act(a: string, dir: Vector3?, extra)
			seq += 1
			local msg = { m = S.RoundService.matchId(), l = life().lifeId, s = seq, a = a, t = Workspace:GetServerTimeNow(), o = muzzle(), d = (dir or Vector3.new(1, 0, 0)).Unit }
			for k, v in extra or {} do
				msg[k] = v
			end
			S.CombatService.handleAction(p, msg)
		end
		local function aimAt(pos: Vector3)
			return pos - muzzle()
		end
		local function target(i)
			return S.CombatService.targets()[i]
		end
		local function setTarget(i, feet: Vector3, teamKey: string?)
			local tg = target(i)
			tg.feet = feet
			tg.part.CFrame = CFrame.new(feet + Vector3.new(0, 2.75, 0)) * CFrame.Angles(0, 0, math.rad(90))
			tg.health = 100
			tg.alive = true
			tg.part.Transparency = 0
			tg.part:SetAttribute("Health", 100)
			S.CombatService.setTargetTeam(i, teamKey or "Any")
		end
		local function parkTargets()
			setTarget(1, Vector3.new(-40, 100, -28))
			setTarget(2, Vector3.new(-44, 100, -28))
			setTarget(3, Vector3.new(-48 + 2, 100, 28))
		end
		local function equip(id: string)
			expect(S.LoadoutService.devSetKit(p, id)):toBe(true)
			local s = S.CombatService.state(p)
			s.nextReady = 0
			s.charging, s.rolling, s.pushing = false, false, false
			S.LoadoutService.fillTank(p)
			S.CharacterService.onOffensiveAction(p)
		end
		local function standAt(pos: Vector3, look: Vector3)
			H.place(S, p, pos, look)
			task.wait(0.35)
		end
		local function healthLog(i)
			local list = {}
			local conn = target(i).part:GetAttributeChangedSignal("Health"):Connect(function()
				table.insert(list, target(i).part:GetAttribute("Health"))
			end)
			return list, conn
		end
		-- moves the character along a straight line at `speed` studs/s (server-driven, validator-aware)
		local function moveAlong(from: Vector3, to: Vector3, speed: number)
			local dir = (to - from)
			local total = dir.Magnitude
			local travelled = 0
			local look = Vector3.new(dir.X, 0, dir.Z).Unit
			while travelled < total do
				local dt = RunService.Heartbeat:Wait()
				travelled = math.min(total, travelled + speed * dt)
				S.CharacterService.teleport(p, CFrame.lookAt(from + dir.Unit * travelled + Vector3.new(0, 3, 0), from + dir.Unit * travelled + Vector3.new(0, 3, 0) + look))
			end
		end

		it("starts the match", function()
			p, team = H.startSolo(S)
			parkTargets()
		end)

		it("WEAPON-02 Twin Jets: six hits eliminate, one damage event per paid shot", function()
			equip("twin_jets")
			standAt(Vector3.new(0, 100, -4), Vector3.new(1, 0, 0))
			setTarget(1, Vector3.new(8, 100, -4))
			local list, conn = healthLog(1)
			for _ = 1, 6 do
				act("Fire", aimAt(target(1).feet + Vector3.new(0, 3, 0)))
				task.wait(W.twin_jets.Cadence + 0.005)
			end
			task.wait(0.3)
			conn:Disconnect()
			expect(table.concat(list, ",")):toBe("82,64,46,28,10,0")
		end)

		it("WEAPON-02 Twin Jets dash: cost 8, 2.5 s cooldown, not while gliding", function()
			equip("twin_jets")
			local paint0 = S.LoadoutService.paint(p)
			local ok0 = S.DiagnosticsService.getCount("Dash.accepted")
			act("Dash", Vector3.new(0, 0, 1))
			expect(S.DiagnosticsService.getCount("Dash.accepted")):toBe(ok0 + 1)
			expect(S.LoadoutService.paint(p)):toNear(paint0 - 8, 1e-6)
			act("Dash", Vector3.new(0, 0, 1))
			expect(S.DiagnosticsService.getCount("Dash.accepted")):toBe(ok0 + 1) -- cooldown
			task.wait(2.6)
			life().glideHeld = true
			act("Dash", Vector3.new(0, 0, 1))
			expect(S.DiagnosticsService.getCount("Dash.accepted")):toBe(ok0 + 1) -- not while gliding
			life().glideHeld = false
			act("Dash", Vector3.new(0, 0, -1))
			expect(S.DiagnosticsService.getCount("Dash.accepted")):toBe(ok0 + 2)
		end)

		it("WEAPON-03 Lane Roller flick: 65 close, 40 far, 0 outside the fan, cost 14, one hit per victim", function()
			equip("lane_roller")
			standAt(Vector3.new(0, 100, -4), Vector3.new(1, 0, 0))
			setTarget(1, Vector3.new(7, 100, -4)) -- close
			setTarget(2, Vector3.new(16, 100, -2)) -- far, inside the fan
			setTarget(3, Vector3.new(-8, 100, -4)) -- behind
			local paint0 = S.LoadoutService.paint(p)
			act("Fire", Vector3.new(1, 0, 0))
			expect(S.LoadoutService.paint(p)):toNear(paint0 - 14, 1e-6)
			task.wait(W.lane_roller.Windup + 0.2)
			expect(target(1).health):toBe(100 - 65)
			expect(target(2).health):toBe(100 - 40)
			expect(target(3).health):toBe(100)
			parkTargets()
		end)

		it("WEAPON-03 Lane Roller roll: contact 60 while moving, once per 0.65 s, strip paint, 12 paint/s", function()
			equip("lane_roller")
			local start = Vector3.new(-26, 100, -26)
			standAt(start, Vector3.new(1, 0, 0))
			setTarget(1, Vector3.new(-14, 100, -26))
			local grid = S.PaintService.grid()
			local owned0 = grid.totals[team]
			local paint0 = S.LoadoutService.paint(p)
			act("SecStart")
			expect(S.CombatService.state(p).rolling):toBe(true)
			moveAlong(start, Vector3.new(-2, 100, -26), 12)
			act("SecStop")
			expect(target(1).health):toBe(100 - 60)
			-- an 8-wide strip along ~24 studs of travel
			expect(grid.totals[team] - owned0):toBeGreaterThan(150)
			local drained = paint0 - S.LoadoutService.paint(p)
			expect(drained):toNear(24, 6) -- 12/s for ~2 s of movement
			parkTargets()
		end)

		it("MOVE-06 rolling in place never refills and never drains; MOVE-08 no paint across a teleport gap", function()
			equip("lane_roller")
			standAt(Vector3.new(-20, 100, 20), Vector3.new(1, 0, 0))
			S.LoadoutService.drain(p, 50, S.RoundService.matchNow())
			act("SecStart")
			local before = S.LoadoutService.paint(p)
			task.wait(1.5)
			expect(S.LoadoutService.paint(p)):toNear(before, 0.01) -- no refill, no drain while stationary
			local grid = S.PaintService.grid()
			local owned = grid.totals[team]
			local skipped = S.DiagnosticsService.getCount("event.TrailTeleportSkipped")
			S.CharacterService.teleport(p, CFrame.new(20, 103, 20)) -- 40-stud jump in one step
			task.wait(0.2)
			act("SecStop")
			expect(S.DiagnosticsService.getCount("event.TrailTeleportSkipped")):toBeGreaterThan(skipped)
			expect(grid.totals[team] - owned):toBeLessThan(20) -- no 40-stud streak across the arena
		end)

		it("WEAPON-04 Linecaster: early release is free, full charge 110, glide cancels, no forged duration", function()
			equip("linecaster")
			standAt(Vector3.new(-20, 100, -4), Vector3.new(1, 0, 0))
			setTarget(1, Vector3.new(10, 100, -4))
			local paint0 = S.LoadoutService.paint(p)
			act("ChargeStart")
			task.wait(0.08)
			act("ChargeRelease", aimAt(target(1).feet + Vector3.new(0, 3, 0)))
			task.wait(0.1)
			expect(S.LoadoutService.paint(p)):toBe(paint0)
			expect(target(1).health):toBe(100)
			-- forged duration: an extra key is rejected outright
			act("ChargeStart")
			task.wait(0.2)
			act("ChargeRelease", aimAt(target(1).feet + Vector3.new(0, 3, 0)), { chargeSeconds = 5 })
			expect(target(1).health):toBe(100)
			expect(S.CombatService.state(p).charging):toBe(true)
			-- glide cancels the stored charge
			S.CharacterService.onClientEvent(p, { k = "Move", l = life().lifeId, glide = true, climb = false })
			expect(S.CombatService.state(p).charging):toBe(false)
			S.CharacterService.onClientEvent(p, { k = "Move", l = life().lifeId, glide = false, climb = false })
			-- full charge
			task.wait(0.4)
			act("ChargeStart")
			task.wait(1.2)
			act("ChargeRelease", aimAt(target(1).feet + Vector3.new(0, 3, 0)))
			task.wait(0.1)
			expect(target(1).alive):toBe(false) -- 110 >= 100
			expect(S.LoadoutService.paint(p)):toNear(paint0 - 20, 0.5)
			parkTargets()
		end)

		it("WEAPON-04 Linecaster partial charge damage matches 35 + 75 * factor", function()
			equip("linecaster")
			standAt(Vector3.new(-20, 100, -4), Vector3.new(1, 0, 0))
			setTarget(1, Vector3.new(10, 100, -4))
			act("ChargeStart")
			task.wait(0.5)
			act("ChargeRelease", aimAt(target(1).feet + Vector3.new(0, 3, 0)))
			task.wait(0.1)
			local dealt = 100 - target(1).health
			local expected = 35 + 75 * (0.5 - 0.15) / (1.10 - 0.15)
			expect(dealt):toNear(expected, 6) -- server-measured, includes one frame of scheduling slack
			parkTargets()
		end)

		it("WEAPON-05 Splash Pot: all three lobes on one victim deal at most 55", function()
			equip("splash_pot")
			standAt(Vector3.new(0, 100, -4), Vector3.new(1, 0, 0))
			setTarget(1, Vector3.new(9, 100, -4))
			local list, conn = healthLog(1)
			act("Fire", aimAt(target(1).feet + Vector3.new(0, 2, 0)))
			task.wait(1.2)
			conn:Disconnect()
			expect(target(1).health):toBe(100 - 55)
			expect(#list):toBe(1)
			parkTargets()
		end)

		it("WEAPON-06 Street Sweeper: 32 per sweep, spam bounded, push and sweep exclusive", function()
			equip("street_sweeper")
			standAt(Vector3.new(0, 100, -4), Vector3.new(1, 0, 0))
			setTarget(1, Vector3.new(8, 100, -4))
			act("Fire", Vector3.new(1, 0, 0))
			task.wait(0.2)
			expect(target(1).health):toBe(100 - 32)
			local before = S.DiagnosticsService.getCount("ShotAccepted.street_sweeper")
			task.wait(0.25)
			for _ = 1, 20 do
				act("Fire", Vector3.new(1, 0, 0))
			end
			expect(S.DiagnosticsService.getCount("ShotAccepted.street_sweeper") - before):toBeAtMost(2)
			task.wait(0.3)
			act("SecStart")
			expect(S.CombatService.state(p).pushing):toBe(true)
			task.wait(0.3)
			act("Fire", Vector3.new(1, 0, 0))
			expect(S.CombatService.state(p).pushing):toBe(false) -- a sweep ends the push
			parkTargets()
		end)

		it("WEAPON-07 Popshot: direct victim takes exactly 70, a neighbour takes splash only", function()
			equip("popshot")
			standAt(Vector3.new(0, 100, -4), Vector3.new(1, 0, 0))
			setTarget(1, Vector3.new(12, 100, -4))
			setTarget(2, Vector3.new(12, 100, -0.5)) -- 3.5 studs from the first, beside it
			local list, conn = healthLog(1)
			act("Fire", aimAt(target(1).feet + Vector3.new(0, 2.75, 0)))
			task.wait(0.6)
			conn:Disconnect()
			expect(target(1).health):toBe(100 - 70)
			expect(#list):toBe(1)
			expect(target(2).health < 100 and target(2).health >= 100 - 40):toBe(true)
			parkTargets()
		end)

		it("WEAPON-08 cover blocks every class (thin cover between attacker and target)", function()
			standAt(Vector3.new(12, 100, -10), Vector3.new(1, 0, 0))
			setTarget(1, Vector3.new(19, 100, -10))
			for _, id in { "sprayline", "twin_jets", "lane_roller", "splash_pot", "street_sweeper", "popshot" } do
				equip(id)
				local before = S.DiagnosticsService.getCount("ShotAccepted." .. id)
				act("Fire", aimAt(target(1).feet + Vector3.new(0, 2.5, 0)))
				-- the attack must really be accepted: a blocked result is only meaningful for an accepted attack
				expect(S.DiagnosticsService.getCount("ShotAccepted." .. id)):toBe(before + 1)
				task.wait(0.8)
			end
			equip("linecaster")
			local chargeBefore = S.DiagnosticsService.getCount("event.ChargeFired")
			act("ChargeStart")
			task.wait(1.2)
			act("ChargeRelease", aimAt(target(1).feet + Vector3.new(0, 2.5, 0)))
			expect(S.DiagnosticsService.getCount("event.ChargeFired")):toBe(chargeBefore + 1)
			task.wait(0.2)
			-- the lobber's arc may clear low cover by design, but thin_cover is 7 high (tall cover blocks it)
			expect(target(1).health):toBe(100)
			parkTargets()
		end)

		it("COMBAT-11 / UI-03 kits are locked during the match and free to change afterwards", function()
			local ok, reason = S.LoadoutService.select(p, "popshot")
			expect(ok):toBe(false)
			expect(reason):toBe("locked_in_match")
			local ok2, reason2 = S.LoadoutService.select(p, "not_a_kit")
			expect(ok2):toBe(false)
			expect(reason2):toBe("unknown_kit")
		end)

		it("ends the match; kit selection works again", function()
			S.LoadoutService.devSetKit(p, "sprayline")
			H.stop(S)
			local ok = S.LoadoutService.select(p, "lane_roller")
			expect(ok):toBe(true)
			expect(p:GetAttribute("CCWeapon")):toBe("lane_roller")
			S.LoadoutService.select(p, "sprayline")
		end)
	end)
end
