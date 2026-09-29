-- WEAPON-09 / GDD 07.5 balance scenario matrix on the open stress_lab FIXTURE (solo practice, server-driven inputs).
-- Measures per weapon: (1) floor coverage in a 10 s trial with unlimited paint (footprint rate), (2) seconds to empty a
-- full tank with continuous use, (3) time to eliminate a stationary 100-HP target at 5 / 15 / 30 studs (4 s cap).
-- Numerical results only: they validate configured mechanics and expose outliers, not fun or human balance.
-- Output: Workspace attribute CCWeaponMatrix (JSON). Run: CCTestRequest = "perf:WeaponMatrix".
return function(t)
	local it, expect = t.it, t.expect
	local S = t.services
	local H = require(S.Dev.MatchHarness)
	local Weapons = require(game.ReplicatedStorage.Shared.Config.Weapons)
	local HttpService = game:GetService("HttpService")
	local RunService = game:GetService("RunService")
	local Workspace = game:GetService("Workspace")
	local W = Weapons.Defs
	local Y = 300

	it("measures the seven kits", function()
		S.DevGate.set("FixtureMap", "stress_lab")
		local p, team = H.startSolo(S, 1800)
		local grid = S.PaintService.grid()
		expect(grid.totalScoringArea > 40000):toBe(true)
		local seq = 900000
		local function life()
			return S.CharacterService.life(p)
		end
		local function muzzle()
			return life().root.Position + Vector3.new(0, 1.1, 0)
		end
		local function act(a, dir)
			seq += 1
			S.CombatService.handleAction(p, { m = S.RoundService.matchId(), l = life().lifeId, s = seq, a = a, t = Workspace:GetServerTimeNow(), o = muzzle(), d = (dir or Vector3.new(1, 0, 0)).Unit })
		end
		local function equip(id)
			S.LoadoutService.devSetKit(p, id)
			local s = S.CombatService.state(p)
			s.nextReady, s.charging, s.rolling, s.pushing = 0, false, false, false
			S.LoadoutService.fillTank(p)
			S.CharacterService.onOffensiveAction(p)
		end
		local function place(pos, look)
			H.place(S, p, pos, look)
			task.wait(0.3)
		end
		local function moveAlong(from, to, speed)
			local dir = to - from
			local total, travelled = dir.Magnitude, 0
			local look = Vector3.new(dir.X, 0, dir.Z).Unit
			while travelled < total do
				local dt = RunService.Heartbeat:Wait()
				travelled = math.min(total, travelled + speed * dt)
				local at = from + dir.Unit * travelled + Vector3.new(0, 3, 0)
				S.CharacterService.teleport(p, CFrame.lookAt(at, at + look))
				S.LoadoutService.fillTank(p)
			end
		end
		local tg = S.CombatService.targets() -- stress_lab has no practice targets; create one capsule record
		local targetPart = Instance.new("Part")
		targetPart.Anchored, targetPart.CanCollide, targetPart.CanQuery = true, false, false
		targetPart.Size = Vector3.new(5.5, 2.8, 2.8)
		targetPart.Parent = Workspace.ColorClashArena
		local target = { part = targetPart, feet = Vector3.zero, team = 0, health = 100, alive = true, key = targetPart }
		table.insert(tg, target)

		-- Aim solver for arcing weapons: search the pitch whose trajectory passes closest to the target (players aim
		-- lobs below the target; aiming straight at it makes the arc overshoot).
		local function solveAim(k, from: Vector3, to: Vector3): Vector3
			local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
			local dist = flat.Magnitude
			local fwd = flat.Unit
			local speed = k.LobeSpeed or k.ProjectileSpeed
			local up = k.LobeUpSpeed or 0
			local best, bestErr = (to - from).Unit, math.huge
			for deg = -70, 60 do
				local pitch = math.rad(deg)
				local dir = fwd * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)
				local vh = speed * math.cos(pitch)
				if vh > 1 then
					local tt = dist / vh
					local y = from.Y + (speed * math.sin(pitch) + up) * tt - 0.5 * k.Gravity * tt * tt
					local err = math.abs(y - to.Y)
					if err < bestErr then
						best, bestErr = dir, err
					end
				end
			end
			return best
		end

		local only = Workspace:GetAttribute("CCMatrixOnly")
		local results = {}
		local xSlot = -220
		for _, id in Weapons.Order do
			if only and only ~= id then
				xSlot += 70
				continue
			end
			local k = W[id]
			local r = { weapon = id }
			-- (1) 10-second coverage trial on a fresh floor slot, unlimited paint
			equip(id)
			local base = Vector3.new(xSlot, Y, -40)
			place(base, Vector3.new(0, 0, 1))
			local before = grid.totals[team]
			local t0 = os.clock()
			if k.Family == "roller" or k.Family == "brush" then
				act("SecStart")
				local speed = if k.Family == "roller" then k.Roll.MaxSpeed else k.Push.MaxSpeed
				local a, b = base, base + Vector3.new(0, 0, 80)
				while os.clock() - t0 < 10 do
					moveAlong(a, b, speed)
					a, b = b + Vector3.new(k.Family == "roller" and 8 or 3, 0, 0), a + Vector3.new(k.Family == "roller" and 8 or 3, 0, 0)
				end
				act("SecStop")
			elseif k.Family == "charger" then
				while os.clock() - t0 < 10 do
					S.LoadoutService.fillTank(p)
					act("ChargeStart")
					task.wait(k.FullCharge + 0.02)
					local ang = math.sin(os.clock()) * 0.6
					act("ChargeRelease", Vector3.new(math.sin(ang), -0.08, math.cos(ang)))
					task.wait(k.Recovery + 0.02)
				end
			else
				local shots = 0
				while os.clock() - t0 < 10 do
					S.LoadoutService.fillTank(p)
					local ang = math.sin(shots * 0.35) * 0.7
					local dist = 10 + (shots % 5) * math.max(2, (k.Range * 0.6 - 10) / 5)
					local aimPoint = life().root.Position + Vector3.new(math.sin(ang) * dist, -3, math.cos(ang) * dist)
					act("Fire", aimPoint - muzzle())
					shots += 1
					task.wait(k.Cadence + 0.003)
				end
			end
			task.wait(1.5)
			r.coverage10s = grid.totals[team] - before
			-- (2) time to empty a full tank with continuous use (standing on neutral floor, no refill during use)
			equip(id)
			place(Vector3.new(xSlot + 40, Y, 30), Vector3.new(0, 0, 1))
			local tStart = os.clock()
			if k.Family == "roller" or k.Family == "brush" then
				act("SecStart")
				local a, b = Vector3.new(xSlot + 40, Y, 30), Vector3.new(xSlot + 40, Y, -30)
				local speed = if k.Family == "roller" then k.Roll.MaxSpeed else k.Push.MaxSpeed
				while S.LoadoutService.paint(p) > 0.5 and os.clock() - tStart < 20 do
					local dir = b - a
					local total, travelled = dir.Magnitude, 0
					while travelled < total and S.LoadoutService.paint(p) > 0.5 do
						local dt = RunService.Heartbeat:Wait()
						travelled = math.min(total, travelled + speed * dt)
						local at = a + dir.Unit * travelled + Vector3.new(0, 3, 0)
						S.CharacterService.teleport(p, CFrame.new(at))
					end
					a, b = b, a
				end
				act("SecStop")
			elseif k.Family == "charger" then
				while S.LoadoutService.paint(p) >= k.Cost and os.clock() - tStart < 20 do
					act("ChargeStart")
					task.wait(k.FullCharge + 0.02)
					act("ChargeRelease", Vector3.new(0, -0.1, 1))
					task.wait(k.Recovery + 0.02)
				end
			else
				while S.LoadoutService.paint(p) >= k.Cost and os.clock() - tStart < 20 do
					act("Fire", Vector3.new(0, -0.2, 1))
					task.wait(k.Cadence + 0.003)
				end
			end
			r.secondsToEmpty = math.floor((os.clock() - tStart) * 100) / 100
			-- (3) time to eliminate at 5 / 15 / 30 studs
			r.ttk = {}
			for _, dist in { 5, 15, 30 } do
				equip(id)
				local stand = Vector3.new(xSlot + 20, Y, 0)
				place(stand, Vector3.new(0, 0, 1))
				target.feet = stand + Vector3.new(0, 0, dist)
				target.part.CFrame = CFrame.new(target.feet + Vector3.new(0, 2.75, 0)) * CFrame.Angles(0, 0, math.rad(90))
				target.health, target.alive = 100, true
				target.part:SetAttribute("Health", 100)
				local tA = os.clock()
				local killedAt = nil
				while os.clock() - tA < 4 and target.alive do
					S.LoadoutService.fillTank(p)
					local aim = target.feet + Vector3.new(0, 2.75, 0) - muzzle()
					if k.Family == "lobber" or k.Family == "blaster" then
						aim = solveAim(k, muzzle(), target.feet + Vector3.new(0, 2.75, 0))
					end
					if k.Family == "charger" then
						act("ChargeStart")
						task.wait(k.FullCharge + 0.02)
						act("ChargeRelease", aim)
						task.wait(k.Recovery + 0.02)
					else
						act("Fire", aim)
						task.wait(k.Cadence + 0.003)
					end
				end
				if not target.alive then
					killedAt = os.clock() - tA
				end
				table.insert(r.ttk, if killedAt then math.floor(killedAt * 100) / 100 else "none")
				task.wait(0.3)
			end
			table.insert(results, r)
			xSlot += 70
		end
		targetPart:Destroy()
		Workspace:SetAttribute("CCWeaponMatrix", HttpService:JSONEncode(results))
		H.stop(S)
		S.DevGate.clear()
		expect(#results):toBe(if only then 1 else 7)
	end)
end
