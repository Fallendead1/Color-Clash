-- (engine:Tactical) Engine tests for gadgets, ultimates, Team Launch and the tactical map (Phase 06) in a live solo-practice match on
-- the paint_lab FIXTURE, through the real validation path (CombatService.handleAction / AbilityService.requestLaunch).
-- ABIL-01..10, MAP-01, SEC-02..04. Teammate launch / target death need a second same-team client: multi-client spec.
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local S = t.services
	local H = require(S.Dev.MatchHarness)
	local Weapons = require(game.ReplicatedStorage.Shared.Config.Weapons)
	local Abilities = require(game.ReplicatedStorage.Shared.Config.Abilities)
	local GameConfig = require(game.ReplicatedStorage.Shared.Config.GameConfig)
	local TacticalMap = require(game.ReplicatedStorage.Shared.Paint.TacticalMap)
	local Workspace = game:GetService("Workspace")
	local A = S.AbilityService
	local D = S.DiagnosticsService

	describe("Gadgets, ultimates and Team Launch (fixture, solo practice)", function()
		local p, team
		local seq = 400000

		local function life()
			return S.CharacterService.life(p)
		end
		local function muzzle()
			return life().root.Position + Vector3.new(0, 1.1, 0)
		end
		local function act(a: string, dir: Vector3?, extra, lifeId: number?)
			seq += 1
			local msg = { m = S.RoundService.matchId(), l = lifeId or life().lifeId, s = seq, a = a, t = Workspace:GetServerTimeNow(), o = muzzle(), d = (dir or Vector3.new(1, 0, 0)).Unit }
			for k, v in extra or {} do
				msg[k] = v
			end
			S.CombatService.handleAction(p, msg)
		end
		local function count(name)
			return D.getCount(name)
		end
		local function target(i)
			return S.CombatService.targets()[i]
		end
		local function setTarget(i, feet: Vector3)
			local tg = target(i)
			tg.feet = feet
			tg.part.CFrame = CFrame.new(feet + Vector3.new(0, 2.75, 0)) * CFrame.Angles(0, 0, math.rad(90))
			tg.health, tg.alive, tg.respawnAt = 100, true, nil
			tg.part.Transparency = 0
			tg.part:SetAttribute("Health", 100)
			S.CombatService.setTargetTeam(i, "Any")
		end
		local function parkTargets()
			setTarget(1, Vector3.new(-40, 100, -28))
			setTarget(2, Vector3.new(-44, 100, -28))
			setTarget(3, Vector3.new(-46, 100, 28))
		end
		local function healthLog(i)
			local list = {}
			local conn = target(i).part:GetAttributeChangedSignal("Health"):Connect(function()
				table.insert(list, target(i).part:GetAttribute("Health"))
			end)
			return list, conn
		end
		local function equip(id: string)
			expect(S.LoadoutService.devSetKit(p, id)):toBe(true)
			local s = S.CombatService.state(p)
			s.nextReady, s.charging, s.rolling, s.pushing, s.firingUntil = 0, false, false, false, 0
			S.LoadoutService.fillTank(p)
			S.CharacterService.onOffensiveAction(p)
		end
		local function standAt(pos: Vector3, look: Vector3?)
			A.cancelLaunch(p, "test") -- isolation: a failed launch test never leaks a channel/transit into the next
			H.place(S, p, pos, look or Vector3.new(1, 0, 0))
			task.wait(0.35)
		end
		local function launch(targetKey)
			A.requestLaunch(p, { target = targetKey })
		end
		local function respawn()
			assert(H.waitFor(function()
				return S.CharacterService.isAlive(p)
			end, GameConfig.Match.RespawnSeconds + 4), "no respawn")
			task.wait(0.3)
			S.CharacterService.onOffensiveAction(p)
		end
		local DOWN = Vector3.new(0, -1, 0)

		it("starts the match", function()
			-- the fixture geometry used below (bases, canopy, cover) is laid out for team A; re-form until team A
			for _ = 1, 6 do
				p, team = H.startSolo(S)
				if team == 1 then
					break
				end
				H.stop(S)
			end
			expect(team):toBe(1)
			parkTargets()
			H.paintFloor(S, -30, 30, -31, 31, 0)
		end)

		it("ABIL-01 Splash Can: paid at release, 1.2 s fuse, falloff, one result per victim, duplicate refused", function()
			equip("sprayline")
			standAt(Vector3.new(0, 100, -4))
			setTarget(1, Vector3.new(3, 100, -4)) -- inner radius
			setTarget(2, Vector3.new(8, 100, -4)) -- falloff band
			setTarget(3, Vector3.new(0, 100, 12)) -- beyond 10 studs
			local log1, c1 = healthLog(1)
			local log2, c2 = healthLog(2)
			local log3, c3 = healthLog(3)
			local paint0 = S.LoadoutService.paint(p)
			local thrown0 = count("Gadget.canThrown")
			act("Gadget", DOWN)
			expect(S.LoadoutService.paint(p)):toNear(paint0, 1e-6) -- nothing charged during the 0.15 s preparation
			act("Gadget", DOWN) -- duplicate request during preparation
			expect(count("ShotRejected.preparing")):toBeAtLeast(1)
			task.wait(Abilities.Gadgets.splash_can.Prep + 0.08)
			local releasedAt = os.clock()
			expect(count("Gadget.canThrown")):toBe(thrown0 + 1)
			expect(S.LoadoutService.paint(p)):toNear(paint0 - 55, 0.5)
			act("Gadget", DOWN) -- a second can while one is active
			expect(count("ShotRejected.canActive")):toBeAtLeast(1)
			expect(S.LoadoutService.paint(p)):toNear(paint0 - 55, 0.5)
			local boomAt = nil
			local conn = target(1).part:GetAttributeChangedSignal("Health"):Connect(function()
				boomAt = boomAt or os.clock()
			end)
			task.wait(1.6)
			conn:Disconnect()
			c1:Disconnect()
			c2:Disconnect()
			c3:Disconnect()
			expect(boomAt ~= nil):toBe(true)
			expect(boomAt - releasedAt):toNear(1.2, 0.12)
			expect(table.concat(log1, ",")):toBe("30") -- 70 inside 4 studs, exactly one application
			expect(#log2):toBe(1)
			expect(log2[1] > 30 and log2[1] < 75):toBe(true) -- 25..70 falloff band
			expect(#log3):toBe(0)
			expect(life().health):toBe(100) -- no self damage
			expect(A.counts().throwables):toBe(0)
		end)

		it("ABIL-01 Splash Can: no damage through cover", function()
			equip("sprayline")
			standAt(Vector3.new(14, 100, -10))
			setTarget(1, Vector3.new(18.5, 100, -10)) -- behind thin_cover (x 15.75..16.25)
			local log, c = healthLog(1)
			act("Gadget", DOWN)
			task.wait(Abilities.Gadgets.splash_can.Prep + 1.2 + 0.3)
			c:Disconnect()
			expect(#log):toBe(0)
			parkTargets()
		end)

		it("ABIL-02 Paint Screen: invalid placements are free; legal placement atomic; replacement removes the old one", function()
			equip("lane_roller")
			expect(Weapons.Defs.lane_roller.Gadget):toBe("paint_screen")
			local paint0 = S.LoadoutService.paint(p)
			standAt(Vector3.new(-27, 100, 8), Vector3.new(-1, 0, 0)) -- 6 studs ahead is inside base A
			act("Gadget", Vector3.new(-1, 0, 0))
			expect(count("ShotRejected.screenInBase")):toBeAtLeast(1)
			standAt(Vector3.new(-24, 100, 0), Vector3.new(-1, 0, 0)) -- 6 studs ahead is the spawn screen block
			act("Gadget", Vector3.new(-1, 0, 0))
			expect(count("ShotRejected.screenBlocked")):toBeAtLeast(1)
			expect(S.LoadoutService.paint(p)):toNear(paint0, 1e-6)
			expect(A.counts().screens):toBe(0)
			-- legal
			standAt(Vector3.new(0, 100, -4))
			act("Gadget", Vector3.new(1, 0, 0))
			expect(A.counts().screens):toBe(1)
			expect(S.LoadoutService.paint(p)):toNear(paint0 - 55, 0.5)
			local folder = Workspace.ColorClashArena:FindFirstChild("ScreensA")
			expect(folder ~= nil and #folder:GetChildren() == 1):toBe(true)
			local first = folder:GetChildren()[1]
			expect(first.CanCollide):toBe(false)
			expect(math.abs(first.Position.X - 6) < 0.6):toBe(true)
			-- interval
			S.LoadoutService.fillTank(p)
			act("Gadget", Vector3.new(1, 0, 0))
			expect(count("ShotRejected.gadgetInterval")):toBeAtLeast(1)
			expect(S.LoadoutService.paint(p)):toNear(100, 0.5)
			-- replacement after 1 s
			task.wait(1.05)
			standAt(Vector3.new(0, 100, 4))
			act("Gadget", Vector3.new(1, 0, 0))
			expect(A.counts().screens):toBe(1)
			expect(first.Parent):toBe(nil)
			expect(#folder:GetChildren()):toBe(1)
			-- lifetime 5 s
			task.wait(Abilities.Gadgets.paint_screen.Lifetime + 0.3)
			expect(A.counts().screens):toBe(0)
			expect(#folder:GetChildren()):toBe(0)
		end)

		it("ABIL-03 destroying shot is consumed by the screen; no invisible blocker remains", function()
			equip("popshot")
			standAt(Vector3.new(0, 100, -4))
			setTarget(1, Vector3.new(12, 100, -4))
			local sc = A.devPlaceScreen(p, 2, CFrame.lookAt(Vector3.new(6, 104.05, -4), Vector3.new(7, 104.05, -4)))
			expect(sc ~= nil):toBe(true)
			sc.expires = math.huge
			local log, c = healthLog(1)
			local k = Weapons.Defs.popshot
			local shots = 0
			while not sc.dead and shots < 6 do
				S.LoadoutService.fillTank(p)
				act("Fire", target(1).feet + Vector3.new(0, 2.75, 0) - muzzle())
				shots += 1
				task.wait(k.Cadence + 0.02)
			end
			task.wait(0.3)
			if not sc.dead then
				local names = {}
				for _, inst in S.CombatService.worldParamsFor(1).FilterDescendantsInstances do
					table.insert(names, inst:GetFullName())
				end
				local hit = Workspace:Raycast(muzzle(), target(1).feet + Vector3.new(0, 2.75, 0) - muzzle(), S.CombatService.worldParamsFor(1))
				error(string.format("screen alive hp=%s shots=%d log=%s parent=%s filter=%s hit=%s accepted=%d", tostring(sc.health), shots, table.concat(log, ","), tostring(sc.part.Parent and sc.part.Parent:GetFullName()), table.concat(names, ","), tostring(hit and hit.Instance:GetFullName()), count("ShotAccepted.popshot")))
			end
			expect(sc.dead):toBe(true)
			expect(shots):toBe(4) -- 70 x 4 >= 250
			expect(#log):toBe(0) -- the destroying shot did not pass through
			expect(sc.part.Parent):toBe(nil)
			local params = S.CombatService.worldParamsFor(1)
			expect(Workspace:Raycast(muzzle(), target(1).feet + Vector3.new(0, 2.75, 0) - muzzle(), params)):toBe(nil)
			S.LoadoutService.fillTank(p)
			act("Fire", target(1).feet + Vector3.new(0, 2.75, 0) - muzzle())
			task.wait(0.5)
			c:Disconnect()
			expect(table.concat(log, ",")):toBe("30") -- the next shot reaches the target: no blocker left
			parkTargets()
		end)

		it("ABIL-03 screen blocks enemy blasts and charger beams, not friendly shots", function()
			equip("linecaster")
			standAt(Vector3.new(0, 100, -4))
			setTarget(1, Vector3.new(12, 100, -4))
			local own = A.devPlaceScreen(p, 1, CFrame.lookAt(Vector3.new(6, 104.05, -4), Vector3.new(7, 104.05, -4)))
			own.expires = math.huge
			local log, c = healthLog(1)
			local k = Weapons.Defs.linecaster
			act("ChargeStart")
			task.wait(k.FullCharge + 0.03)
			act("ChargeRelease", target(1).feet + Vector3.new(0, 2.75, 0) - muzzle())
			task.wait(0.2)
			expect(#log):toBe(1) -- own screen ignored by own beam
			c:Disconnect()
			setTarget(1, Vector3.new(12, 100, -4))
			log, c = healthLog(1)
			local enemy = A.devPlaceScreen(p, 2, CFrame.lookAt(Vector3.new(6, 104.05, -4), Vector3.new(7, 104.05, -4)))
			enemy.expires = math.huge
			expect(own.dead):toBe(true) -- same owner: replaced
			task.wait(k.Recovery + 0.05)
			S.LoadoutService.fillTank(p)
			act("ChargeStart")
			task.wait(k.FullCharge + 0.03)
			act("ChargeRelease", target(1).feet + Vector3.new(0, 2.75, 0) - muzzle())
			task.wait(0.2)
			c:Disconnect()
			expect(#log):toBe(0) -- blocked by the enemy screen
			expect(enemy.health):toBe(250 - (k.BaseDamage + k.ChargeDamage)) -- the beam hit the screen
			-- a splash can bursting on the far side: the screen blocks blast line of sight
			equip("sprayline")
			standAt(Vector3.new(8, 100, -4))
			setTarget(1, Vector3.new(3.5, 100, -4)) -- 4.5 studs away, behind the screen
			local log2, c2 = healthLog(1)
			act("Gadget", DOWN)
			task.wait(Abilities.Gadgets.splash_can.Prep + 1.2 + 0.3)
			c2:Disconnect()
			expect(#log2):toBe(0)
			expect(enemy.health < 250 - (k.BaseDamage + k.ChargeDamage)):toBe(true) -- the blast damaged the screen
			enemy.expires = 0
			task.wait(0.1)
			parkTargets()
		end)

		it("ABIL-04 ultimate credit: zero from own floor, walls and ultimate paint; rate limited from neutral", function()
			equip("sprayline")
			H.paintFloor(S, -30, 30, -31, 31, 0)
			H.paintFloor(S, -8, 8, -20, 4, team) -- includes the floor under the wall shots (their drips land there)
			standAt(Vector3.new(0, 100, -4))
			S.LoadoutService.setUltimateForTests(p, 0)
			local k = Weapons.Defs.sprayline
			for n = 1, 8 do
				S.LoadoutService.fillTank(p)
				act("Fire", Vector3.new(math.sin(n), -3, math.cos(n)))
				task.wait(k.Cadence + 0.01)
			end
			task.wait(0.4)
			expect(S.LoadoutService.ultimate(p)):toBe(0) -- own floor
			-- walls
			standAt(Vector3.new(0, 100, -14), Vector3.new(0, 0, -1))
			local wall = S.PaintService.grid():getPatch("paint_wall_north")
			local before = wall.counts[team]
			for n = 1, 6 do
				S.LoadoutService.fillTank(p)
				act("Fire", Vector3.new(0.2 * math.sin(n), 0.05, -1))
				task.wait(k.Cadence + 0.01)
			end
			task.wait(0.4)
			expect(wall.counts[team] > before):toBe(true)
			expect(S.LoadoutService.ultimate(p)):toBe(0)
			-- ultimate paint on neutral floor
			H.paintFloor(S, -30, 30, -31, 31, 0)
			standAt(Vector3.new(0, 100, -4))
			S.LoadoutService.setUltimateForTests(p, 100)
			local area0 = S.PaintService.grid().totals[team]
			act("Ultimate", DOWN)
			task.wait(Abilities.Ultimates.color_burst.Prep + Abilities.Ultimates.color_burst.Fuse + 0.4)
			expect(S.PaintService.grid().totals[team] - area0 > 200):toBe(true)
			expect(S.LoadoutService.ultimate(p)):toBe(0)
			-- positive control and the 6/s cap
			H.paintFloor(S, -30, 30, -31, 31, 0)
			local t0 = os.clock()
			for n = 1, 12 do
				S.LoadoutService.fillTank(p)
				act("Fire", Vector3.new(math.sin(n * 0.7), -0.35, math.cos(n * 0.7)))
				task.wait(k.Cadence + 0.01)
			end
			task.wait(0.2)
			local gained = S.LoadoutService.ultimate(p)
			expect(gained > 0):toBe(true)
			expect(gained <= GameConfig.Ultimate.MaxGainPerSecond * (os.clock() - t0) + 1e-6):toBe(true)
		end)

		it("ABIL-05 elimination during preparation cancels without refund; after release it continues", function()
			equip("sprayline")
			standAt(Vector3.new(0, 100, -4))
			S.LoadoutService.setUltimateForTests(p, 100)
			local cancelled0 = count("Prep.cancelled")
			local burst0 = count("Ultimate.burstExploded")
			act("Ultimate", DOWN)
			expect(S.LoadoutService.ultimate(p)):toBe(0) -- spent atomically at activation
			S.CharacterService.eliminate(p, nil, nil)
			task.wait(Abilities.Ultimates.color_burst.Prep + 0.2)
			expect(count("Prep.cancelled")):toBe(cancelled0 + 1)
			expect(A.counts().throwables):toBe(0)
			respawn()
			expect(S.LoadoutService.ultimate(p)):toBe(0) -- no refund
			task.wait(Abilities.Ultimates.color_burst.Fuse + 0.2)
			expect(count("Ultimate.burstExploded")):toBe(burst0)
			-- after release
			equip("sprayline")
			standAt(Vector3.new(0, 100, -4))
			S.LoadoutService.setUltimateForTests(p, 100)
			act("Ultimate", Vector3.new(1, 0.2, 0))
			task.wait(Abilities.Ultimates.color_burst.Prep + 0.08)
			expect(A.counts().throwables):toBe(1)
			S.CharacterService.eliminate(p, nil, nil)
			task.wait(Abilities.Ultimates.color_burst.Fuse + 0.3)
			expect(count("Ultimate.burstExploded")):toBe(burst0 + 1)
			respawn()
		end)

		it("ABIL-06 Paintstorm: canopy blocks rain and damage; overlapping storms never exceed one tick", function()
			equip("linecaster")
			expect(Weapons.Defs.linecaster.Ultimate):toBe("paintstorm")
			H.paintFloor(S, -30, 30, -31, 31, 0)
			standAt(Vector3.new(-16, 100, 18))
			setTarget(1, Vector3.new(-19, 100, 21)) -- under the canopy roof (x -22..-10, z 12..24)
			setTarget(2, Vector3.new(-16, 100, 4)) -- in the open, inside the radius
			local log1, c1 = healthLog(1)
			local log2, c2 = healthLog(2)
			local st = Abilities.Ultimates.paintstorm
			S.LoadoutService.setUltimateForTests(p, 100)
			act("Ultimate", DOWN)
			task.wait(st.Prep + st.Fuse + 0.1)
			expect(A.counts().storms):toBe(1)
			standAt(Vector3.new(-30, 100, -24)) -- leave the storm (not a victim anyway)
			S.LoadoutService.setUltimateForTests(p, 100)
			standAt(Vector3.new(-16, 100, 18))
			act("Ultimate", DOWN)
			task.wait(st.Prep + st.Fuse + 0.1)
			expect(A.counts().storms):toBe(2)
			local w0 = os.clock()
			local n0 = #log2
			task.wait(2.1)
			local elapsed = os.clock() - w0
			c1:Disconnect()
			c2:Disconnect()
			expect(#log1):toBe(0) -- covered
			local ticks = #log2 - n0
			expect(ticks <= math.floor(elapsed / st.TickInterval) + 1):toBe(true)
			expect(ticks >= 3):toBe(true)
			for n = 2, #log2 do
				expect(log2[n - 1] - log2[n]):toBe(st.TickDamage)
			end
			-- no paint under the roof, paint in the open
			local grid = S.PaintService.grid()
			local under, open = 0, 0
			for x = -20.5, -11.5 do
				for z = 13.5, 22.5 do
					local patch, i, j = grid:locate(vector.create(x, 100, z), 0.6, 0.3)
					if patch and grid:getOwner(patch, j * patch.def.SizeU + i) == team then
						under += 1
					end
				end
			end
			for x = -24.5, -8.5 do
				for z = 2.5, 8.5 do
					local patch, i, j = grid:locate(vector.create(x, 100, z), 0.6, 0.3)
					if patch and grid:getOwner(patch, j * patch.def.SizeU + i) == team then
						open += 1
					end
				end
			end
			expect(under):toBe(0)
			expect(open > 20):toBe(true)
			expect(S.LoadoutService.ultimate(p)):toBe(0) -- storm paint grants no meter
			parkTargets()
		end)

		it("ABIL-06 Paintstorm beacon on a wall fizzles with a cue", function()
			equip("linecaster")
			standAt(Vector3.new(-12, 100, -10), Vector3.new(-1, 0, 0)) -- neutral wall face at x = -15
			local fizz0 = count("Ultimate.stormFizzled")
			local storms0 = A.counts().storms
			S.LoadoutService.setUltimateForTests(p, 100)
			act("Ultimate", Vector3.new(-1, 0, 0))
			local st = Abilities.Ultimates.paintstorm
			task.wait(st.Prep + st.Fuse + 0.2)
			expect(count("Ultimate.stormFizzled")):toBe(fizz0 + 1)
			expect(A.counts().storms):toBe(storms0)
		end)

		it("SEC-02 launch accepts only a teammate id or Base; never a CFrame, enemy, self or missing player", function()
			task.wait(6.5) -- storms from ABIL-06 end
			equip("sprayline")
			H.paintFloor(S, -8, 8, -12, 4, team)
			standAt(Vector3.new(0, 100, -4))
			task.wait(0.4)
			local pos0 = life().root.Position
			local inv0 = count("Launch.rejected.invalid")
			launch(CFrame.new(40, 103, 0))
			A.requestLaunch(p, { target = "Base", cf = CFrame.new(40, 103, 0) })
			A.requestLaunch(p, "Base")
			A.requestLaunch(p, { target = 1.5 })
			expect(count("Launch.rejected.invalid")):toBe(inv0 + 4)
			local bad0 = count("Launch.rejected.badTarget")
			launch(p.UserId) -- self
			launch(987654321) -- nobody
			expect(count("Launch.rejected.badTarget")):toBe(bad0 + 2)
			expect(A.launchState(p)):toBe(nil)
			expect((life().root.Position - pos0).Magnitude < 0.5):toBe(true)
			-- a teammate launch needs friendly paint underfoot
			H.paintFloor(S, -8, 8, -12, 4, 2)
			task.wait(0.5)
			local own0 = count("Launch.rejected.notOnOwnPaint")
			local ill0 = count("Launch.rejected.illegalFloor")
			launch(p.UserId)
			launch("Base") -- base launch: any legal NON-enemy floor
			expect(count("Launch.rejected.notOnOwnPaint")):toBe(own0 + 1)
			expect(count("Launch.rejected.illegalFloor")):toBe(ill0 + 1)
			H.paintFloor(S, -8, 8, -12, 4, 0)
			task.wait(0.5)
			launch("Base") -- neutral floor is legal for Base
			expect(A.launchState(p) ~= nil):toBe(true)
			A.cancelLaunch(p, "test")
		end)

		it("ABIL-08 damage, movement and attacks cancel the channel without cooldown", function()
			H.paintFloor(S, -8, 8, -12, 4, team)
			standAt(Vector3.new(0, 100, -4))
			task.wait(0.4)
			local pos0 = life().root.Position
			local dep0 = count("Launch.departed")
			local dmg0 = count("Launch.cancel.damaged")
			launch("Base")
			task.wait(0.3)
			expect(S.CharacterService.applyDamage(p, 10, nil, "test")):toBe("applied")
			expect(count("Launch.cancel.damaged")):toBe(dmg0 + 1)
			expect(A.launchState(p)):toBe(nil)
			task.wait(1.0)
			expect((life().root.Position - pos0).Magnitude < 0.5):toBe(true) -- no teleport
			local rd0 = count("Launch.rejected.recentlyDamaged")
			launch("Base")
			expect(count("Launch.rejected.recentlyDamaged")):toBe(rd0 + 1)
			task.wait(0.6) -- 1.5 s since the hit
			-- movement over 1 stud
			local mv0 = count("Launch.cancel.moved")
			launch("Base")
			task.wait(0.2)
			H.place(S, p, Vector3.new(2, 100, -4))
			task.wait(0.15)
			expect(count("Launch.cancel.moved")):toBe(mv0 + 1)
			-- another attack
			task.wait(0.3)
			local at0 = count("Launch.cancel.attacked")
			launch("Base")
			task.wait(0.2)
			act("Fire", Vector3.new(1, -0.3, 0))
			expect(count("Launch.cancel.attacked")):toBe(at0 + 1)
			expect(A.launchState(p)):toBe(nil)
			expect(count("Launch.departed")):toBe(dep0) -- no cancelled channel ever departed
		end)

		it("ABIL-07 Base launch: 1 s channel, invulnerable 1 s transit, server-chosen spawn, 8 s cooldown", function()
			standAt(Vector3.new(0, 100, -4))
			task.wait(0.4)
			local t0 = os.clock()
			launch("Base")
			expect(A.launchState(p).phase):toBe("channel")
			assert(H.waitFor(function()
				local L = A.launchState(p)
				return L ~= nil and L.phase == "transit"
			end, 2), "no departure")
			expect(os.clock() - t0):toNear(1.0, 0.12)
			expect(life().root.Anchored):toBe(true)
			expect(S.CharacterService.applyDamage(p, 50, nil, "test")):toBe("shielded")
			local cd0 = count("Launch.rejected.cooldown")
			assert(H.waitFor(function()
				return A.launchState(p) == nil
			end, 2), "no arrival")
			expect(os.clock() - t0):toNear(2.0, 0.15)
			expect(life().root.Anchored):toBe(false)
			local near = false
			for _, cf in S.RoundService.currentMap().spawns[team] do
				if (life().root.Position - (cf.Position + Vector3.new(0, 3.1, 0))).Magnitude < 1.5 then
					near = true
				end
			end
			expect(near):toBe(true)
			expect(S.CharacterService.isShielded(p)):toBe(true) -- 0.25 s landing protection (or spawn-base rules)
			H.paintFloor(S, -8, 8, -12, 4, team)
			standAt(Vector3.new(0, 100, -4))
			task.wait(0.3)
			launch("Base")
			expect(count("Launch.rejected.cooldown")):toBe(cd0 + 1)
			-- teammate landing search never lands inside the enemy base or in geometry
			expect(A.findLanding(Vector3.new(-40, 100, 0), 2)):toBe(nil)
			local spot = A.findLanding(Vector3.new(0, 100, -4), 1)
			expect(spot ~= nil and math.abs(spot.Y - 100) < 0.2):toBe(true)
			local onPlatform = A.findLanding(Vector3.new(0, 105, 20), 1)
			expect(onPlatform ~= nil and math.abs(onPlatform.Y - 105) < 0.2):toBe(true)
		end)

		it("ABIL-09 frozen destination invalid in transit: validated friendly spawn, cooldown retained", function()
			expect(A.devResetCooldown(p)):toBe(true)
			standAt(Vector3.new(0, 100, -4))
			task.wait(0.4)
			launch("Base")
			assert(H.waitFor(function()
				local L = A.launchState(p)
				return L ~= nil and L.phase == "transit"
			end, 2), "no departure")
			local landing = A.launchState(p).landing
			local blocker = Instance.new("Part")
			blocker.Name = "TestBlocker"
			blocker.Anchored = true
			blocker.Size = Vector3.new(4, 6, 4)
			blocker.CFrame = CFrame.new(landing + Vector3.new(0, 3, 0))
			blocker.Parent = S.RoundService.currentMap().model:FindFirstChild("Geometry")
			local fb0 = count("Launch.fallbackToSpawn")
			assert(H.waitFor(function()
				return A.launchState(p) == nil
			end, 2), "no arrival")
			blocker:Destroy()
			expect(count("Launch.fallbackToSpawn")):toBe(fb0 + 1)
			local flat = Vector3.new(life().root.Position.X - landing.X, 0, life().root.Position.Z - landing.Z)
			expect(flat.Magnitude > 1):toBe(true) -- not inside the blocked spot
			expect(S.CharacterService.inVolume(life().root.Position, "ProtectedBase", team)):toBe(true)
			local cd0 = count("Launch.rejected.cooldown")
			launch("Base")
			expect(count("Launch.rejected.cooldown")):toBe(cd0 + 1)
		end)

		it("SEC-03 client cannot fake costs, meter or stats", function()
			equip("sprayline")
			standAt(Vector3.new(0, 100, -4))
			local shape0 = count("ShotRejected.shape")
			local paint0 = S.LoadoutService.paint(p)
			act("Gadget", DOWN, { cost = 0 })
			act("Fire", DOWN, { damage = 999 })
			expect(count("ShotRejected.shape")):toBe(shape0 + 2)
			S.LoadoutService.setUltimateForTests(p, 50)
			act("Ultimate", DOWN, nil)
			expect(count("ShotRejected.ultimateNotReady")):toBeAtLeast(1)
			expect(S.LoadoutService.ultimate(p)):toBe(50)
			S.LoadoutService.drain(p, S.LoadoutService.paint(p) - 20, S.RoundService.matchNow())
			local dry0 = count("ShotRejected.dry")
			act("Gadget", DOWN)
			expect(count("ShotRejected.dry")):toBe(dry0 + 1)
			expect(S.LoadoutService.paint(p)):toNear(20, 0.5)
			task.wait(0.3)
			expect(A.counts().throwables):toBe(0)
			expect(paint0 > 20):toBe(true)
		end)

		it("SEC-04 dead or old lives cannot cast", function()
			equip("sprayline")
			standAt(Vector3.new(0, 100, -4))
			local oldLife = life().lifeId
			S.CharacterService.eliminate(p, nil, nil)
			local life0 = count("ShotRejected.life")
			local na0 = count("Launch.rejected.notAlive")
			act("Gadget", DOWN, nil, oldLife) -- while dead
			launch("Base")
			expect(count("ShotRejected.life")):toBe(life0 + 1)
			expect(count("Launch.rejected.notAlive")):toBe(na0 + 1)
			respawn()
			equip("sprayline")
			standAt(Vector3.new(0, 100, -4))
			local hash0 = S.PaintService.grid():hash()
			act("Gadget", DOWN, nil, oldLife) -- old life after respawn
			act("Ultimate", DOWN, nil, oldLife)
			expect(count("ShotRejected.life")):toBe(life0 + 3)
			task.wait(0.3)
			expect(A.counts().throwables):toBe(0)
			expect(S.PaintService.grid():hash()):toBe(hash0)
		end)

		it("MAP-01 tactical projection matches the scoring grid; no hidden second layer", function()
			H.paintFloor(S, -10, 0, -10, 0, 1)
			H.paintFloor(S, 0, 10, 0, 10, 2)
			local grid = S.PaintService.grid()
			local proj = TacticalMap.project(grid, 1)
			expect(proj.scoringCells):toBe(grid.totalScoringArea)
			expect(proj.totals[1]):toBe(grid.totals[1])
			expect(proj.totals[2]):toBe(grid.totals[2])
			expect(proj.totals[0]):toBe(grid.totals[0])
			expect(proj.stackedPixels):toBe(0)
			expect(TacticalMap.pixelOwner(proj, math.floor(-5 - proj.minX), math.floor(-5 - proj.minZ))):toBe(1)
			expect(TacticalMap.pixelOwner(proj, math.floor(5 - proj.minX), math.floor(5 - proj.minZ))):toBe(2)
			-- base floors are not scoring and never appear
			expect(TacticalMap.pixelOwner(proj, math.floor(40 - proj.minX), math.floor(0 - proj.minZ))):toBe(nil)
		end)

		it("ABIL-10 round end with every ability active: all entities cleaned, nothing resolves later", function()
			expect(A.devResetCooldown(p)):toBe(true)
			equip("linecaster")
			H.paintFloor(S, -8, 8, -12, 4, team)
			standAt(Vector3.new(0, 100, -4))
			S.LoadoutService.setUltimateForTests(p, 100)
			act("Ultimate", DOWN)
			local st = Abilities.Ultimates.paintstorm
			task.wait(st.Prep + st.Fuse + 0.1)
			expect(A.counts().storms):toBe(1)
			equip("lane_roller")
			act("Gadget", Vector3.new(1, 0, 0))
			expect(A.counts().screens):toBe(1)
			task.wait(Abilities.Gadgets.splash_can.MinInterval + 0.05) -- the gadget interval spans kit swaps
			equip("sprayline")
			act("Gadget", Vector3.new(0, 0.6, 1))
			task.wait(Abilities.Gadgets.splash_can.Prep + 0.05)
			expect(A.counts().throwables):toBe(1)
			S.CombatService.state(p).firingUntil = 0 -- keep the can in flight (1.2 s fuse) while the launch channels
			launch("Base")
			expect(A.launchState(p) ~= nil):toBe(true)
			local can0 = count("Gadget.canExploded")
			local rc0 = count("Launch.cancel.roundEnd")
			H.stop(S)
			local c = A.counts()
			expect(c.throwables):toBe(0)
			expect(c.storms):toBe(0)
			expect(c.screens):toBe(0)
			expect(A.launchState(p)):toBe(nil)
			expect(count("Launch.cancel.roundEnd")):toBe(rc0 + 1)
			task.wait(1.5)
			expect(count("Gadget.canExploded")):toBe(can0)
			local arena = Workspace:FindFirstChild("ColorClashArena")
			local leftover = 0
			if arena then
				for _, name in { "ScreensA", "ScreensB" } do
					local f = arena:FindFirstChild(name)
					leftover += if f then #f:GetChildren() else 0
				end
			end
			expect(leftover):toBe(0)
			local l = life()
			expect(l == nil or l.root == nil or l.root.Anchored == false):toBe(true)
		end)
	end)
end
