-- TWO REAL CLIENTS (Studio local server, 2 players), paint_lab FIXTURE, 1v1 development override (GDD 03.2).
-- Steps are selected by Workspace attribute CCMultiStep so real input can be injected between them:
--   "setup"  : 1v1 match goes Live; both clients synced; players placed 12 studs apart facing each other
--   "duel"   : server-validated shots P1 -> P2 eliminate P2 (credit, death, burst, respawn with shield in base)
--   "check"  : after a real-mouse client duel, verify the victim took damage from the real client's shots
--   "finish" : end the round; both clients' frozen hashes equal the server's; results raw-count correct; the next
--              round starts automatically (ready persists) and is then ended
return function(t)
	local it, expect = t.it, t.expect
	local S = t.services
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")
	local H = require(S.Dev.MatchHarness)

	local function two()
		local list = Players:GetPlayers()
		table.sort(list, function(a, b)
			return a.Name < b.Name
		end)
		return list[1], list[2]
	end

	local step = Workspace:GetAttribute("CCMultiStep")

	if step == "setup" then
		it("starts a 1v1 live match with both real clients synced", function()
			local p1, p2 = two()
			expect(p2 ~= nil):toBe(true)
			S.DevGate.set("MinimumReady", 2)
			S.DevGate.set("CountdownSeconds", 1)
			S.DevGate.set("IntroSeconds", 1)
			S.DevGate.set("LiveSeconds", 300)
			S.DevGate.set("ResultsSeconds", 3)
			S.DevGate.set("IntermissionSeconds", 2)
			S.RoundService.applyDevSettings()
			S.TeamService.setReadyServer(p1, true)
			S.TeamService.setReadyServer(p2, true)
			expect(H.waitFor(function()
				return S.RoundService.state() == "Live"
			end, 20)):toBe(true)
			expect(S.TeamService.teamOf(p1) ~= S.TeamService.teamOf(p2)):toBe(true)
			expect(H.waitFor(function()
				return S.PaintService.isSynced(p1) and S.PaintService.isSynced(p2)
			end, 10)):toBe(true)
			H.place(S, p1, Vector3.new(-6, 100, -26), Vector3.new(1, 0, 0))
			H.place(S, p2, Vector3.new(6, 100, -26), Vector3.new(-1, 0, 0))
			task.wait(0.5)
			S.CharacterService.onOffensiveAction(p1)
			S.CharacterService.onOffensiveAction(p2)
			S.LoadoutService.fillTank(p1)
			Workspace:SetAttribute("CCDuelTarget", S.CharacterService.life(p2).root.Position)
			Workspace:SetAttribute("CCMultiTeams", string.format("%s=%d %s=%d", p1.Name, S.TeamService.teamOf(p1), p2.Name, S.TeamService.teamOf(p2)))
		end)
	elseif step == "duel" then
		it("server-validated shots from P1 eliminate the real P2; credit, respawn and shield are correct", function()
			local p1, p2 = two()
			local l1, l2 = S.CharacterService.life(p1), S.CharacterService.life(p2)
			S.CharacterService.onOffensiveAction(p2)
			S.LoadoutService.fillTank(p1)
			local deaths0 = S.CharacterService.stats(p2).deaths
			local elims0 = S.CharacterService.stats(p1).eliminations
			local life2 = l2.lifeId
			local seq = 50000
			for _ = 1, 5 do
				seq += 1
				local origin = l1.root.Position + Vector3.new(0, 1.1, 0)
				local aim = S.CharacterService.life(p2).root.Position
				S.CombatService.handleAction(p1, { m = S.RoundService.matchId(), l = l1.lifeId, s = seq, a = "Fire", t = Workspace:GetServerTimeNow(), o = origin, d = (aim - origin).Unit })
				task.wait(0.125)
			end
			expect(H.waitFor(function()
				return not S.CharacterService.isAlive(p2)
			end, 1.5)):toBe(true)
			expect(S.CharacterService.stats(p2).deaths):toBe(deaths0 + 1)
			expect(S.CharacterService.stats(p1).eliminations):toBe(elims0 + 1)
			-- respawn after 4 s, a new life, inside the own protected base, shielded
			expect(H.waitFor(function()
				local nl = S.CharacterService.life(p2)
				return nl ~= nil and nl.alive and nl.lifeId ~= life2
			end, 6)):toBe(true)
			local nl = S.CharacterService.life(p2)
			expect(S.CharacterService.inVolume(nl.root.Position, "ProtectedBase", nl.team)):toBe(true)
			expect(S.CharacterService.isShielded(p2)):toBe(true)
			expect(nl.health):toBe(100)
		end)
	elseif step == "prepduel" then
		it("re-places both players for the real-input duel", function()
			local p1, p2 = two()
			S.TeamService.touch(p1)
			S.TeamService.touch(p2)
			H.place(S, p1, Vector3.new(-6, 100, -26), Vector3.new(1, 0, 0))
			H.place(S, p2, Vector3.new(6, 100, -26), Vector3.new(-1, 0, 0))
			task.wait(0.6)
			S.CharacterService.onOffensiveAction(p2)
			S.LoadoutService.fillTank(p1)
			local l2 = S.CharacterService.life(p2)
			l2.health = 100
			Workspace:SetAttribute("CCDuelTarget", l2.root.Position)
			Workspace:SetAttribute("CCDuelVictimLife", l2.lifeId)
			Workspace:SetAttribute("CCDuelAccepted0", S.DiagnosticsService.getCount("ShotAccepted.sprayline"))
			expect(l2.alive):toBe(true)
		end)
	elseif step == "check" then
		it("the real client's held fire damaged the real opponent", function()
			local _, p2 = two()
			local accepted = S.DiagnosticsService.getCount("ShotAccepted.sprayline") - (Workspace:GetAttribute("CCDuelAccepted0") or 0)
			local l2 = S.CharacterService.life(p2)
			local damaged = l2.lifeId ~= Workspace:GetAttribute("CCDuelVictimLife") or l2.health < 100 or not l2.alive
			Workspace:SetAttribute("CCDuelResult", string.format("accepted=%d victimHealth=%s alive=%s lifeChanged=%s", accepted, tostring(l2.health), tostring(l2.alive), tostring(l2.lifeId ~= Workspace:GetAttribute("CCDuelVictimLife"))))
			expect(accepted):toBeGreaterThan(3)
			expect(damaged):toBe(true)
		end)
	elseif step == "finish" then
		it("ends the round; both clients' frozen paint equals the server; next round starts", function()
			local p1, p2 = two()
			-- the 60 s idle rule un-readies inactive players (GDD 03.5); these test players count as active
			S.TeamService.touch(p1)
			S.TeamService.touch(p2)
			S.TeamService.setReadyServer(p1, true)
			S.TeamService.setReadyServer(p2, true)
			local checks = {}
			-- paint some contested floor from both sides first
			local grid = S.PaintService.grid()
			local t1, t2 = S.TeamService.teamOf(p1), S.TeamService.teamOf(p2)
			S.PaintService.paintSphere(Vector3.new(-10, 100, 0), 5, t1, nil)
			S.PaintService.paintSphere(Vector3.new(10, 100, 0), 4, t2, nil)
			S.PaintService.paintSphere(Vector3.new(-8, 100, 0), 3, t2, nil) -- repaint part of team 1's area
			S.PaintService.flush()
			task.wait(0.3)
			local match1 = S.RoundService.matchId()
			S.RoundService.devEndLiveNow()
			expect(H.waitFor(function()
				return S.RoundService.state() == "Results"
			end, 3)):toBe(true)
			local frozenHash = grid:hash()
			local frozenOk = H.waitFor(function()
				return S.PaintService.frozenAck(p1) == frozenHash and S.PaintService.frozenAck(p2) == frozenHash
			end, 5)
			table.insert(checks, "frozenBothClients=" .. tostring(frozenOk))
			Workspace:SetAttribute("CCMultiFinish", table.concat(checks, " "))
			expect(frozenOk):toBe(true)
			local res = S.RoundService.lastResults()
			table.insert(checks, string.format("result=%s a=%d b=%d n=%d total=%d players=%d", res.outcome, res.a, res.b, res.neutral, res.total, #res.players))
			Workspace:SetAttribute("CCMultiFinish", table.concat(checks, " "))
			expect(res.a + res.b + res.neutral):toBe(res.total)
			expect(res.a):toBe(grid.totals[1])
			expect(res.b):toBe(grid.totals[2])
			local want = if res.a > res.b then "A" elseif res.b > res.a then "B" else "Draw"
			expect(res.outcome):toBe(want)
			expect(#res.players):toBe(2)
			-- the loop continues without operator intervention (ready persists)
			local nextOk = H.waitFor(function()
				return S.RoundService.state() == "Live" and S.RoundService.matchId() == match1 + 1
			end, 25)
			table.insert(checks, "nextRoundLive=" .. tostring(nextOk))
			Workspace:SetAttribute("CCMultiFinish", table.concat(checks, " "))
			expect(nextOk):toBe(true)
			expect(S.TeamService.teamOf(p1) ~= S.TeamService.teamOf(p2)):toBe(true)
			-- round 2 keeps running for the late-join and vacancy steps
		end)
	elseif step == "latejoin" then
		it("FLOW-10 then FLOW-09 with a real third client", function()
			local list = Players:GetPlayers()
			table.sort(list, function(a, b)
				return a.Name < b.Name
			end)
			local p1, p2, p3 = list[1], list[2], list[3]
			expect(p3 ~= nil):toBe(true)
			for _, p in list do
				S.TeamService.touch(p)
			end
			expect(S.RoundService.state()):toBe("Live")
			expect(S.TeamService.isParticipating(p3)):toBe(false)
			local machine = S.RoundService.machine()
			-- FLOW-10: 50 s remaining -> the newcomer stays in staging
			machine.roundEndTime = Workspace:GetServerTimeNow() + 50
			S.TeamService.setReadyServer(p3, true)
			S.RoundService.onPlayerReady(p3)
			task.wait(0.3)
			expect(S.TeamService.isParticipating(p3)):toBe(false)
			-- FLOW-09: 200 s remaining -> backfill onto the smaller team, synced before combat-active
			machine.roundEndTime = Workspace:GetServerTimeNow() + 200
			S.RoundService.onPlayerReady(p3)
			expect(H.waitFor(function()
				return S.TeamService.isParticipating(p3) and S.CharacterService.isAlive(p3)
			end, 8)):toBe(true)
			local a, b = S.TeamService.teamCounts()
			expect(math.abs(a - b)):toBe(1)
			expect(H.waitFor(function()
				return S.PaintService.isSynced(p3)
			end, 8)):toBe(true)
			expect(S.PaintService.ackHash(p3) ~= nil):toBe(true)
			expect(S.LoadoutService.ultimate(p3)):toBe(0) -- a late join starts at zero ultimate
			Workspace:SetAttribute("CCMultiLate", string.format("teams %s=%d %s=%d %s=%d", p1.Name, S.TeamService.teamOf(p1), p2.Name, S.TeamService.teamOf(p2), p3.Name, S.TeamService.teamOf(p3)))
		end)
	elseif step == "vacancy" then
		it("FLOW-12 kicking the only member of a team pauses, then NoContest after 15 s", function()
			local list = Players:GetPlayers()
			for _, p in list do
				S.TeamService.touch(p)
			end
			local a, b = S.TeamService.teamCounts()
			local lonelyTeam = if a == 1 then 1 elseif b == 1 then 2 else nil
			expect(lonelyTeam ~= nil):toBe(true)
			local victim = S.TeamService.teamPlayers(lonelyTeam)[1]
			local deaths0 = 0
			local _ = deaths0
			victim:Kick("Color Clash test: vacancy pause")
			expect(H.waitFor(function()
				return S.RoundService.state() == "VacancyPause"
			end, 3)):toBe(true)
			local remaining = S.RoundService.machine():remainingLive(Workspace:GetServerTimeNow())
			task.wait(3)
			-- the match clock is frozen while paused
			expect(S.RoundService.machine():remainingLive(Workspace:GetServerTimeNow())):toNear(remaining, 0.05)
			expect(H.waitFor(function()
				return S.RoundService.state() == "Results"
			end, 16)):toBe(true)
			local res = S.RoundService.lastResults()
			expect(res.outcome):toBe("NoContest")
			Workspace:SetAttribute("CCMultiVacancy", "outcome=" .. res.outcome)
			-- stop the loop
			for _, p in Players:GetPlayers() do
				S.TeamService.setReadyServer(p, false)
			end
			H.waitFor(function()
				return S.RoundService.state() == "Waiting"
			end, 20)
			S.DevGate.clear()
			S.RoundService.applyDevSettings()
		end)
	else
		it("needs Workspace attribute CCMultiStep", function()
			expect(step ~= nil):toBe(true)
		end)
	end
end
