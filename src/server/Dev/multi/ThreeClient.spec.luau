-- THREE REAL CLIENTS (Studio local server, 3 players) on the PRODUCTION MAPS (Codex content, fixture = false).
-- Covers COMBAT-05/06/07, ABIL-07/09 teammate launch, NET-04 at 3 clients, FLOW-11 vacancy replacement.
-- Steps (Workspace attribute CCMulti3Step), run with CCTestRequest = "multi:ThreeClient":
--   "setup"    : 2v1 live match on the rotation map; roles A1/A2 (same team) and E (other team)
--   "combat05" : one Splash Can eliminates A1 and A2 in the same step; independent attribution to E
--   "combat06" : assist >= 20 within 5 s credited, outside the window not credited; final hitter credited once
--   "combat07" : a pending Splash Can outlives E's old life; the old death stays credited to its killer and the
--                can's later hit is logged only against E's new life
--   "launch07" : A1 launches to teammate A2: server landing near A2, frozen in transit, cooldown
--   "launch09" : target dies before departure -> cancel without cooldown; enemy target rejected
--   "finish"   : end the round: all three clients' frozen paint hashes equal the server's
--   "flow11"   : 1v1 (A1 vs E) with A2 in staging; E's client is KICKED (whole team leaves) -> VacancyPause with the
--                clock frozen; A2 readies -> backfilled to the empty team -> Live resumes with the same remaining time
-- Results: Workspace attribute CCMulti3 (last step summary). Positions come from an open-floor scan of the loaded
-- map, never from fixed coordinates.
return function(t)
	local it, expect = t.it, t.expect
	local S = t.services
	local H = require(S.Dev.MatchHarness)
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")
	local D = S.DiagnosticsService
	local A = S.AbilityService
	local UP = Vector3.new(0, 3, 0)
	local DOWN = Vector3.new(0, -1, 0)

	local function byName(): { Player }
		local list = Players:GetPlayers()
		table.sort(list, function(a, b)
			return a.Name < b.Name
		end)
		return list
	end
	local function roles(): (Player, Player, Player)
		local list = byName()
		for _, p in list do
			local mates = {}
			for _, q in list do
				if S.TeamService.teamOf(q) == S.TeamService.teamOf(p) and S.TeamService.teamOf(p) ~= 0 then
					table.insert(mates, q)
				end
			end
			if #mates == 2 then
				local e
				for _, q in list do
					if not table.find(mates, q) then
						e = q
					end
				end
				return mates[1], mates[2], e
			end
		end
		error("no 2v1 teams formed")
	end
	local function life(p)
		return S.CharacterService.life(p)
	end
	local seqs = {}
	local function act(p: Player, a: string, dir: Vector3)
		seqs[p] = (seqs[p] or 900000 + math.floor(os.clock() * 10) % 50000) + 1
		local l = life(p)
		S.CombatService.handleAction(p, { m = S.RoundService.matchId(), l = l.lifeId, s = seqs[p], a = a, t = Workspace:GetServerTimeNow(), o = l.root.Position + Vector3.new(0, 1.1, 0), d = dir.Unit })
	end
	local function aimAt(p: Player, q: Player): Vector3
		return (life(q).root.Position - (life(p).root.Position + Vector3.new(0, 1.1, 0)))
	end
	local function report(text: string)
		Workspace:SetAttribute("CCMulti3", text)
	end
	local function ready(p: Player)
		S.TeamService.touch(p)
		S.CharacterService.onOffensiveAction(p)
		S.LoadoutService.fillTank(p)
		local s = S.CombatService.state(p)
		s.nextReady, s.charging, s.rolling, s.pushing = 0, false, false, false
	end
	local function waitAlive(list: { Player }, timeout: number): boolean
		return H.waitFor(function()
			for _, p in list do
				local l = life(p)
				if not (l and l.alive and l.root) then
					return false
				end
			end
			return true
		end, timeout)
	end

	-- An open 16 x 16 floor area outside both bases: centre and the four points 8 studs away are clear floors at the
	-- same height with line of sight between them. Scans the loaded map; nearest to `near` first.
	local plain = S.CombatService.plainParams()
	local function exactFloor(p: Vector3): Vector3?
		local spot = A.findLanding(p, 1)
		if spot and Vector3.new(spot.X - p.X, 0, spot.Z - p.Z).Magnitude < 0.5 and S.CombatService.inAnyBase(spot + Vector3.new(0, 1, 0)) == nil then
			return spot
		end
		return nil
	end
	local function openArea(near: Vector3, minDistFrom: Vector3?): Vector3
		local candidates = {}
		for x = -96, 96, 8 do
			for z = -80, 80, 8 do
				table.insert(candidates, Vector3.new(x, near.Y, z))
			end
		end
		table.sort(candidates, function(a, b)
			return (a - near).Magnitude < (b - near).Magnitude
		end)
		for _, c in candidates do
			if not minDistFrom or (c - minDistFrom).Magnitude >= 30 then
				local centre = exactFloor(c)
				if centre then
					local ok = true
					for _, off in { Vector3.new(8, 0, 0), Vector3.new(-8, 0, 0), Vector3.new(0, 0, 8), Vector3.new(0, 0, -8) } do
						local s = exactFloor(centre + off)
						if not s or math.abs(s.Y - centre.Y) > 0.4 then
							ok = false
							break
						end
						if Workspace:Raycast(centre + UP, off, plain) then
							ok = false
							break
						end
					end
					if ok then
						return centre
					end
				end
			end
		end
		error("no open 16x16 floor area found on " .. tostring(S.RoundService.currentMap().mapId))
	end
	local function place(p: Player, pos: Vector3, lookAt: Vector3?)
		H.place(S, p, pos, if lookAt then (lookAt - pos) * Vector3.new(1, 0, 1) else Vector3.new(1, 0, 0))
	end
	local function lastEliminated(victim: Player)
		local list = D.recent("Eliminated", 40)
		for k = #list, 1, -1 do
			if list[k].data.victim == victim.UserId then
				return list[k]
			end
		end
		return nil
	end

	local step = Workspace:GetAttribute("CCMulti3Step")

	if step == "setup" then
		it("starts a 2v1 live match on a production map with three synced real clients", function()
			local list = byName()
			expect(#list):toBe(3)
			S.DevGate.set("MinimumReady", 3)
			S.DevGate.set("CountdownSeconds", 1)
			S.DevGate.set("IntroSeconds", 1)
			S.DevGate.set("LiveSeconds", 900)
			S.DevGate.set("ResultsSeconds", 4)
			S.DevGate.set("IntermissionSeconds", 2)
			S.RoundService.applyDevSettings()
			for _, p in list do
				S.TeamService.touch(p)
				S.TeamService.setReadyServer(p, true)
			end
			expect(H.waitFor(function()
				return S.RoundService.state() == "Live"
			end, 40)):toBe(true)
			local desc = S.RoundService.currentMap()
			expect(desc.isFixture):toBe(false)
			expect(desc.mapId == "switchyard" or desc.mapId == "canopy_courts"):toBe(true)
			expect(H.waitFor(function()
				for _, p in list do
					if not S.PaintService.isSynced(p) then
						return false
					end
				end
				return true
			end, 20)):toBe(true)
			local a1, a2, e = roles()
			report(string.format("map=%s v%d A1=%s A2=%s (team %d) E=%s (team %d)", desc.mapId, desc.mapVersion, a1.Name, a2.Name, S.TeamService.teamOf(a1), e.Name, S.TeamService.teamOf(e)))
		end)
	elseif step == "combat05" then
		it("COMBAT-05 one blast eliminates two players in the same step with independent attribution", function()
			local a1, a2, e = roles()
			expect(waitAlive({ a1, a2, e }, 10)):toBe(true)
			local c = openArea(Vector3.new(0, 100, 0))
			place(a1, c)
			place(a2, c + Vector3.new(2, 0, 0))
			place(e, c + Vector3.new(-3, 0, 0), c)
			task.wait(0.5)
			for _, p in { a1, a2, e } do
				ready(p)
			end
			S.LoadoutService.devSetKit(e, "sprayline") -- Splash Can
			for _, p in { a1, a2 } do
				local l = life(p)
				l.health = 10 -- both one blast from elimination
			end
			local d1, d2 = S.CharacterService.stats(a1).deaths, S.CharacterService.stats(a2).deaths
			local el0 = S.CharacterService.stats(e).eliminations
			local lives = { life(a1).lifeId, life(a2).lifeId }
			act(e, "Gadget", DOWN)
			expect(H.waitFor(function()
				return not life(a1).alive and not life(a2).alive
			end, 3)):toBe(true)
			local e1, e2 = lastEliminated(a1), lastEliminated(a2)
			expect(e1 ~= nil and e2 ~= nil):toBe(true)
			expect(e1.data.attacker):toBe(e.UserId)
			expect(e2.data.attacker):toBe(e.UserId)
			expect(e1.data.life):toBe(lives[1])
			expect(e2.data.life):toBe(lives[2])
			expect(S.CharacterService.stats(a1).deaths):toBe(d1 + 1)
			expect(S.CharacterService.stats(a2).deaths):toBe(d2 + 1)
			expect(S.CharacterService.stats(e).eliminations):toBe(el0 + 2)
			expect(life(e).alive):toBe(true) -- no self damage
			report(string.format("COMBAT-05 both eliminated by %s (weapon %s / %s), dt=%.3f s", e.Name, tostring(e1.data.weapon), tostring(e2.data.weapon), math.abs(e1.t - e2.t)))
			expect(waitAlive({ a1, a2 }, 8)):toBe(true)
		end)
	elseif step == "combat06" then
		it("COMBAT-06 final hitter credited once; assist >= 20 inside 5 s only", function()
			local a1, a2, e = roles()
			expect(waitAlive({ a1, a2, e }, 10)):toBe(true)
			local c = openArea(Vector3.new(0, 100, 0))
			local lines = {}
			for _, case in { { wait = 0, assist = true }, { wait = 5.6, assist = false } } do
				expect(waitAlive({ a1, a2, e }, 10)):toBe(true)
				place(e, c, c + Vector3.new(8, 0, 0))
				place(a1, c + Vector3.new(8, 0, 0), c)
				place(a2, c + Vector3.new(-8, 0, 0), c)
				task.wait(0.5)
				for _, p in { a1, a2, e } do
					ready(p)
					S.LoadoutService.devSetKit(p, "sprayline")
				end
				local le = life(e)
				local el1, as2, de = S.CharacterService.stats(a1).eliminations, S.CharacterService.stats(a2).assists, S.CharacterService.stats(e).deaths
				local as1 = S.CharacterService.stats(a1).assists
				-- A2: one hit of 24 (retry on a spread miss)
				for _ = 1, 4 do
					if le.health < 100 then
						break
					end
					act(a2, "Fire", aimAt(a2, e))
					task.wait(0.35)
				end
				expect(le.health <= 76):toBe(true)
				task.wait(case.wait)
				S.TeamService.touch(a1)
				S.TeamService.touch(a2)
				S.TeamService.touch(e)
				-- A1 finishes
				for _ = 1, 12 do
					if not le.alive then
						break
					end
					S.LoadoutService.fillTank(a1)
					act(a1, "Fire", aimAt(a1, e))
					task.wait(0.2)
				end
				expect(le.alive):toBe(false)
				local ev = lastEliminated(e)
				expect(ev.data.attacker):toBe(a1.UserId)
				expect(S.CharacterService.stats(a1).eliminations):toBe(el1 + 1)
				expect(S.CharacterService.stats(e).deaths):toBe(de + 1)
				expect(S.CharacterService.stats(a1).assists):toBe(as1) -- the final hitter never also gets an assist
				expect(S.CharacterService.stats(a2).assists):toBe(as2 + (if case.assist then 1 else 0))
				table.insert(lines, string.format("wait %.1f s: assist %s", case.wait, tostring(S.CharacterService.stats(a2).assists - as2)))
			end
			report("COMBAT-06 " .. table.concat(lines, "; "))
			expect(waitAlive({ e }, 8)):toBe(true)
		end)
	elseif step == "combat07" then
		it("COMBAT-07 an attack pending across a respawn: old death credit unchanged, new life logged separately", function()
			local a1, a2, e = roles()
			S.DevGate.set("RespawnSeconds", 0.5)
			expect(waitAlive({ a1, a2, e }, 10)):toBe(true)
			local c = openArea(Vector3.new(0, 100, 0))
			place(e, c)
			place(a1, c + Vector3.new(8, 0, 0), c)
			place(a2, c + Vector3.new(0, 0, 8), c)
			task.wait(0.5)
			for _, p in { a1, a2, e } do
				ready(p)
			end
			S.LoadoutService.devSetKit(a1, "sprayline")
			local oldLife = life(e).lifeId
			local canSpot = life(a1).root.Position - Vector3.new(0, 3, 0)
			act(a1, "Gadget", DOWN) -- can sticks at A1's feet: 1.2 s fuse after a 0.15 s preparation
			task.wait(0.2)
			place(a1, c + Vector3.new(-8, 0, 0), c) -- the thrower walks away
			S.CharacterService.eliminate(e, a2, "sprayline") -- old life ends, credited to A2
			local ev = lastEliminated(e)
			expect(ev.data.life):toBe(oldLife)
			expect(ev.data.attacker):toBe(a2.UserId)
			expect(H.waitFor(function()
				local l = life(e)
				return l ~= nil and l.alive and l.lifeId ~= oldLife and l.root ~= nil
			end, 3)):toBe(true)
			local newLife = life(e).lifeId
			place(e, canSpot + Vector3.new(0, 0, 1.5), c)
			S.CharacterService.onOffensiveAction(e) -- drop the spawn shield so the blast result is observable
			expect(H.waitFor(function()
				return life(e).health < 100
			end, 2)):toBe(true)
			local le = life(e)
			local entry = le.damageLog[#le.damageLog]
			expect(le.lifeId):toBe(newLife)
			expect(entry.attacker):toBe(a1)
			expect(lastEliminated(e).data.life):toBe(oldLife) -- the old life's elimination record is unchanged
			expect(lastEliminated(e).data.attacker):toBe(a2.UserId)
			report(string.format("COMBAT-07 old life %d credited to %s; can hit new life %d for %d (by %s)", oldLife, a2.Name, newLife, 100 - le.health, a1.Name))
			S.DevGate.set("RespawnSeconds", nil)
		end)
	elseif step == "launch07" then
		it("ABIL-07 teammate launch: server landing near the teammate, frozen in transit, cooldown", function()
			local a1, a2, _ = roles()
			expect(waitAlive({ a1, a2 }, 10)):toBe(true)
			local target = openArea(Vector3.new(0, 100, 0))
			local from = openArea(Vector3.new(0, 100, 0), target)
			place(a2, target)
			place(a1, from)
			task.wait(0.4)
			for _, p in { a1, a2 } do
				ready(p)
			end
			S.PaintService.paintSphere(from, 5, S.TeamService.teamOf(a1), { origin = from + Vector3.new(0, 1, 0) })
			S.PaintService.flush()
			task.wait(1.7) -- own-paint ground sample and the 1.5 s recent-damage rule
			S.CombatService.state(a1).firingUntil = 0
			local dep0, cd0 = D.getCount("Launch.departed"), D.getCount("Launch.rejected.cooldown")
			local t0 = os.clock()
			A.requestLaunch(a1, { target = a2.UserId })
			local L = A.launchState(a1)
			if not L then
				local rej = {}
				for name, n in D.counters() do
					if string.find(name, "^Launch%.rejected") then
						table.insert(rej, name .. "=" .. n)
					end
				end
				error("launch refused: " .. table.concat(rej, ", ") .. " ground=" .. tostring(life(a1).ground))
			end
			expect(H.waitFor(function()
				local s = A.launchState(a1)
				return s ~= nil and s.phase == "transit"
			end, 2)):toBe(true)
			local landing = A.launchState(a1).landing
			local tDepart = os.clock() - t0
			local nearTeammate = (Vector3.new(landing.X, 0, landing.Z) - Vector3.new(target.X, 0, target.Z)).Magnitude
			place(a2, target + Vector3.new(0, 0, 8)) -- the teammate moves during transit: no chasing
			expect(H.waitFor(function()
				return A.launchState(a1) == nil
			end, 2)):toBe(true)
			local arrived = life(a1).root.Position
			local tArrive = os.clock() - t0
			expect(D.getCount("Launch.departed")):toBe(dep0 + 1)
			expect(nearTeammate <= 6.1):toBe(true)
			expect(nearTeammate >= 2.9):toBe(true) -- next to the teammate, never on top of them
			expect((Vector3.new(arrived.X, 0, arrived.Z) - Vector3.new(landing.X, 0, landing.Z)).Magnitude < 1.5):toBe(true)
			expect(tDepart):toNear(1.0, 0.15)
			expect(tArrive):toNear(2.0, 0.2)
			expect(S.CombatService.inAnyBase(arrived) == nil or S.CombatService.inAnyBase(arrived) == S.TeamService.teamOf(a1)):toBe(true)
			A.requestLaunch(a1, { target = a2.UserId })
			expect(D.getCount("Launch.rejected.cooldown")):toBe(cd0 + 1)
			report(string.format("ABIL-07 depart %.2f s, arrive %.2f s, landing %.1f studs from teammate, frozen (teammate moved 8)", tDepart, tArrive, nearTeammate))
		end)
	elseif step == "launch09" then
		it("ABIL-09 target dies before departure: cancel without cooldown; SEC-02 enemy target rejected", function()
			local a1, a2, e = roles()
			expect(waitAlive({ a1, a2, e }, 10)):toBe(true)
			A.devResetCooldown(a1)
			local target = openArea(Vector3.new(0, 100, 0))
			local from = openArea(Vector3.new(0, 100, 0), target)
			place(a2, target)
			place(a1, from)
			task.wait(0.4)
			ready(a1)
			S.PaintService.paintSphere(from, 5, S.TeamService.teamOf(a1), { origin = from + Vector3.new(0, 1, 0) })
			S.PaintService.flush()
			task.wait(1.7)
			S.CombatService.state(a1).firingUntil = 0
			local bad0 = D.getCount("Launch.rejected.badTarget")
			A.requestLaunch(a1, { target = e.UserId }) -- a real enemy player
			expect(D.getCount("Launch.rejected.badTarget")):toBe(bad0 + 1)
			local gone0, dep0 = D.getCount("Launch.cancel.targetGone"), D.getCount("Launch.departed")
			local pos0 = life(a1).root.Position
			A.requestLaunch(a1, { target = a2.UserId })
			expect(A.launchState(a1) ~= nil):toBe(true)
			task.wait(0.4)
			S.CharacterService.eliminate(a2, nil, nil)
			task.wait(0.9)
			expect(D.getCount("Launch.cancel.targetGone")):toBe(gone0 + 1)
			expect(D.getCount("Launch.departed")):toBe(dep0)
			expect((life(a1).root.Position - pos0).Magnitude < 1):toBe(true)
			-- no cooldown: a new request channels immediately
			A.requestLaunch(a1, { target = "Base" })
			local ok = A.launchState(a1) ~= nil
			A.cancelLaunch(a1, "test")
			expect(ok):toBe(true)
			report("ABIL-09 targetGone cancel, no departure, no position change, no cooldown; enemy target rejected")
			expect(waitAlive({ a2 }, 8)):toBe(true)
		end)
	elseif step == "finish" then
		it("NET-04 (3 clients): frozen paint hashes of all real clients equal the server's", function()
			local list = byName()
			for _, p in list do
				S.TeamService.touch(p)
			end
			expect(S.RoundService.devEndLiveNow()):toBe(true)
			expect(H.waitFor(function()
				return S.RoundService.state() == "Results"
			end, 10)):toBe(true)
			local grid = S.PaintService.grid()
			local serverHash = grid:hash()
			expect(H.waitFor(function()
				for _, p in list do
					if S.PaintService.frozenAck(p) ~= serverHash then
						return false
					end
				end
				return true
			end, 8)):toBe(true)
			local res = S.RoundService.lastResults()
			report(string.format("NET-04 3 clients: frozen hash %d on all; outcome %s A=%d B=%d total=%d", serverHash, tostring(res.outcome), res.a, res.b, res.total))
			for _, p in list do
				S.TeamService.setReadyServer(p, false)
			end
		end)
	elseif step == "flow11" then
		it("FLOW-11 whole team leaves, replacement joins within 15 s: clock pauses then resumes", function()
			local list = byName()
			expect(H.waitFor(function()
				local s = S.RoundService.state()
				return s == "Waiting" or s == "Intermission"
			end, 20)):toBe(true)
			-- 1v1 between the first and last player by name; the middle player waits in staging as the replacement
			local p1, reserve, p3 = list[1], list[2], list[3]
			S.DevGate.set("MinimumReady", 2)
			S.RoundService.applyDevSettings()
			S.TeamService.setReadyServer(reserve, false)
			for _, p in { p1, p3 } do
				S.TeamService.touch(p)
				S.TeamService.setReadyServer(p, true)
			end
			expect(H.waitFor(function()
				return S.RoundService.state() == "Live"
			end, 40)):toBe(true)
			expect(S.TeamService.isParticipating(reserve)):toBe(false)
			local leavingTeam = S.TeamService.teamOf(p3)
			task.wait(2)
			p3:Kick("Color Clash FLOW-11 test: the whole team leaves")
			expect(H.waitFor(function()
				return S.RoundService.state() == "VacancyPause"
			end, 5)):toBe(true)
			local m = S.RoundService.machine()
			local r0 = m:remainingLive(Workspace:GetServerTimeNow())
			task.wait(3)
			local r1 = m:remainingLive(Workspace:GetServerTimeNow())
			expect(math.abs(r1 - r0) < 0.2):toBe(true) -- the clock is frozen during the pause
			S.TeamService.touch(reserve)
			S.TeamService.setReadyServer(reserve, true)
			S.RoundService.onPlayerReady(reserve) -- what the Ready remote handler does after setting the flag
			expect(H.waitFor(function()
				return S.RoundService.state() == "Live"
			end, 5)):toBe(true)
			expect(S.TeamService.teamOf(reserve)):toBe(leavingTeam)
			expect(waitAlive({ reserve }, 8)):toBe(true)
			local r2 = m:remainingLive(Workspace:GetServerTimeNow())
			task.wait(2)
			local r3 = m:remainingLive(Workspace:GetServerTimeNow())
			expect(r2 <= r0 + 0.2 and r2 >= r0 - 2.5):toBe(true) -- resumed with the remaining time kept
			expect(r3 < r2 - 1.5):toBe(true) -- and the clock runs again
			report(string.format("FLOW-11 paused with %.1f s left (%.1f after 3 s); %s backfilled to team %d; resumed at %.1f s, running", r0, r1, reserve.Name, leavingTeam, r2))
			S.RoundService.devEndLiveNow()
			H.waitFor(function()
				return S.RoundService.state() ~= "Live"
			end, 10)
			S.DevGate.clear()
			S.RoundService.applyDevSettings()
		end)
	else
		it("needs Workspace attribute CCMulti3Step", function()
			expect(step ~= nil):toBe(true)
		end)
	end
end
