-- FLOW-02..05, FLOW-08, FLOW-10..12 (pure, simulated time). Engine-level versions run in Studio.
return function(t)
	local RoundMachine = t.require("Round/RoundMachine")
	local Teams = t.require("Round/Teams")
	local GameConfig = t.require("Config/GameConfig")
	local describe, it, expect = t.describe, t.it, t.expect

	local M = GameConfig.Match
	local settings = {
		MinimumReady = M.PublicMinimumReady,
		Capacity = M.ServerCapacity,
		CountdownSeconds = M.CountdownSeconds,
		FullLobbyCountdownSeconds = M.FullLobbyCountdownSeconds,
		LoadingTimeoutSeconds = M.LoadingTimeoutSeconds,
		IntroSeconds = M.IntroSeconds,
		LiveSeconds = M.LiveSeconds,
		ResultsSeconds = M.ResultsSeconds,
		IntermissionSeconds = M.IntermissionSeconds,
		VacancyGraceSeconds = M.VacancyGraceSeconds,
		FinalCueSeconds = M.FinalCueSeconds,
	}

	local function kinds(events)
		local out = {}
		for _, e in events do
			table.insert(out, if e.kind == "Transition" then e.to else e.kind)
		end
		return out
	end

	local function facts(ready, a, b, extra)
		local f = { readyCount = ready, teamA = a or 2, teamB = b or 2 }
		for k, v in extra or {} do
			f[k] = v
		end
		return f
	end

	describe("RoundMachine", function()
		it("one player waits without a fake match (FLOW-01)", function()
			local m = RoundMachine.new(settings, 0)
			for now = 0, 120, 5 do
				m:step(now, facts(1, 1, 0))
			end
			expect(m.state):toBe("Waiting")
			expect(m.matchId):toBe(0)
		end)

		it("four ready players start a 20 s countdown (FLOW-02)", function()
			local m = RoundMachine.new(settings, 0)
			local ev = m:step(1, facts(4))
			expect(kinds(ev)):toEqual({ "Countdown" })
			expect(m.deadline):toBe(21)
			m:step(20.9, facts(4))
			expect(m.state):toBe("Countdown")
			m:step(21, facts(4))
			expect(m.state):toBe("Loading")
			expect(m.matchId):toBe(1)
		end)

		it("eight ready shortens the remaining countdown to at most 5 s, once (FLOW-03)", function()
			local m = RoundMachine.new(settings, 0)
			m:step(0, facts(4))
			local ev = m:step(3, facts(8))
			expect(kinds(ev)):toEqual({ "CountdownShortened" })
			expect(m.deadline):toBe(8)
			-- a later tick with 8 ready does not push the deadline again
			m:step(4, facts(8))
			expect(m.deadline):toBe(8)
			-- when fewer than 5 s remain, it is not extended
			local m2 = RoundMachine.new(settings, 0)
			m2:step(0, facts(4))
			m2:step(17, facts(8))
			expect(m2.deadline):toBe(20)
		end)

		it("dropping below four ready cancels the countdown once (FLOW-04)", function()
			local m = RoundMachine.new(settings, 0)
			m:step(0, facts(4))
			local ev = m:step(5, facts(3))
			expect(kinds(ev)):toEqual({ "CountdownCanceled", "Waiting" })
			local ev2 = m:step(6, facts(3))
			expect(#ev2):toBe(0)
			expect(m.deadline):toBe(nil)
		end)

		it("completes a whole round and loops through intermission (FLOW-05 lifecycle)", function()
			local m = RoundMachine.new(settings, 0)
			m:step(0, facts(4))
			m:step(20, facts(4))
			expect(m.state):toBe("Loading")
			m:step(21, facts(4, 2, 2, { loadDone = true }))
			expect(m.state):toBe("Intro")
			m:step(24, facts(4))
			expect(m.state):toBe("Live")
			expect(m.roundEndTime):toBe(264)
			local ev = m:step(234.5, facts(4))
			expect(kinds(ev)):toEqual({ "FinalCue" })
			m:step(263.99, facts(4))
			expect(m.state):toBe("Live")
			m:step(264, facts(4))
			expect(m.state):toBe("Results")
			expect(m.outcome):toBe("Completed")
			m:step(274, facts(4))
			expect(m.state):toBe("Reset")
			m:step(274, facts(4, 2, 2, { resetDone = true }))
			expect(m.state):toBe("Intermission")
			m:step(289, facts(4))
			expect(m.state):toBe("Countdown")
			m:step(309, facts(4))
			expect(m.matchId):toBe(2)
		end)

		it("loading failure and timeout return to Waiting recoverably", function()
			local m = RoundMachine.new(settings, 0)
			m:step(0, facts(4))
			m:step(20, facts(4))
			m:step(21, facts(4, 2, 2, { loadFailed = true }))
			expect(m.state):toBe("Countdown") -- Waiting then immediately Countdown again since 4 still ready
			local m2 = RoundMachine.new(settings, 0)
			m2:step(0, facts(4))
			m2:step(20, facts(4))
			expect(m2.state):toBe("Loading")
			local ev = m2:step(20 + settings.LoadingTimeoutSeconds, facts(4))
			expect(ev[1].to):toBe("Waiting")
			expect(ev[1].reason):toBe("loading timed out")
			expect(m2.matchId):toBe(1) -- the failed match id is never reused
		end)

		it("vacancy pause freezes the clock and shifts RoundEndTime (FLOW-11)", function()
			local m = RoundMachine.new(settings, 0)
			m:step(0, facts(4))
			m:step(20, facts(4))
			m:step(20, facts(4, 2, 2, { loadDone = true }))
			m:step(23, facts(4))
			expect(m.roundEndTime):toBe(263)
			m:step(100, facts(4, 2, 0))
			expect(m.state):toBe("VacancyPause")
			expect(m:remainingLive(105)):toBe(163)
			expect(m:allowsBackfill(105, 60)):toBe(true)
			local ev = m:step(110, facts(4, 2, 1))
			expect(kinds(ev)):toEqual({ "Live", "DeadlineShifted" })
			expect(m.roundEndTime):toBe(273)
		end)

		it("vacancy grace expiry is NoContest, never a win (FLOW-12)", function()
			local m = RoundMachine.new(settings, 0)
			m:step(0, facts(4))
			m:step(20, facts(4))
			m:step(20, facts(4, 2, 2, { loadDone = true }))
			m:step(23, facts(4))
			m:step(50, facts(2, 2, 0))
			local ev = m:step(65, facts(2, 2, 0))
			expect(kinds(ev)):toEqual({ "NoContest", "Results" })
			expect(m.outcome):toBe("NoContest")
		end)

		it("backfill only with more than 60 s remaining (FLOW-09/10)", function()
			local m = RoundMachine.new(settings, 0)
			m:step(0, facts(4))
			m:step(20, facts(4))
			m:step(20, facts(4, 2, 2, { loadDone = true }))
			m:step(23, facts(4))
			expect(m:allowsBackfill(23 + 179, 60)):toBe(true) -- 61 s left
			expect(m:allowsBackfill(23 + 180, 60)):toBe(false) -- exactly 60 left
			expect(m:allowsBackfill(23 + 200, 60)):toBe(false)
		end)
	end)

	describe("Teams", function()
		it("splits 4/5/7/8 with size difference <= 1 and cap 4 (FLOW-05)", function()
			for _, n in { 2, 4, 5, 6, 7, 8 } do
				for seed = 1, 20 do
					local ids = {}
					for k = 1, n do
						ids[k] = 1000 + k
					end
					local assignment, overflow = Teams.form(ids, seed, 4)
					local a, b = 0, 0
					for _, side in assignment do
						if side == 1 then
							a += 1
						else
							b += 1
						end
					end
					expect(#overflow):toBe(0)
					expect(a + b):toBe(n)
					expect(math.abs(a - b)):toBeAtMost(1)
					expect(a):toBeAtMost(4)
					expect(b):toBeAtMost(4)
				end
			end
		end)

		it("is reproducible for a seed and varies across seeds", function()
			local ids = { 11, 22, 33, 44, 55, 66, 77, 88 }
			local a1 = Teams.form(ids, 42, 4)
			local a2 = Teams.form(ids, 42, 4)
			expect(a1):toEqual(a2)
			local differs = false
			for seed = 43, 60 do
				local other = Teams.form(ids, seed, 4)
				if other[11] ~= a1[11] then
					differs = true
				end
			end
			expect(differs):toBe(true)
		end)

		it("never exceeds capacity with more than eight", function()
			local ids = {}
			for k = 1, 10 do
				ids[k] = k
			end
			local assignment, overflow = Teams.form(ids, 7, 4)
			local n = 0
			for _ in assignment do
				n += 1
			end
			expect(n):toBe(8)
			expect(#overflow):toBe(2)
		end)

		it("backfills the smaller team and alternates ties", function()
			expect(Teams.backfillSide(3, 2, 4, 1)):toBe(2)
			expect(Teams.backfillSide(1, 2, 4, 2)):toBe(1)
			expect(Teams.backfillSide(2, 2, 4, 2)):toBe(2)
			expect(Teams.backfillSide(4, 4, 4, 1)):toBe(nil)
		end)

		it("decides the winner from raw counts; exact ties draw (FLOW-06/08)", function()
			local s = Teams.score(473, 473, 1000)
			expect(s.outcome):toBe("Draw")
			expect(s.winner):toBe(nil)
			local near = Teams.score(4731, 4730, 10000)
			expect(near.outcome):toBe("A")
			local aText, bText = Teams.formatPercents(near)
			expect(aText ~= bText):toBe(true) -- a second decimal distinguishes the near-tie
			expect(aText):toBe("47.31%")
			local s2 = Teams.score(300, 500, 1000)
			expect(s2.outcome):toBe("B")
			expect(s2.neutralPercent):toNear(20)
			local aP, bP, nP = Teams.formatPercents(s2)
			expect(aP):toBe("30.0%")
			expect(bP):toBe("50.0%")
			expect(nP):toBe("20.0%")
		end)
	end)
end
