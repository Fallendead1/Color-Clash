-- FLOW-14 (and the Phase 08 soak basis): 20 consecutive rounds alternating the two manifest-slot CONTRACT FIXTURES,
-- reselecting a different kit between rounds, with real attacks, a gadget and an ultimate each round. After every
-- round: map alternated, kit changed and locked, no combat entity survives, arena holds only the new map, per-round
-- stats reset. Solo practice (dev override). Run: CCTestRequest = "perf:RoundSoak" (about 5 minutes; poll).
-- Output: Workspace attribute CCSoak (JSON summary).
return function(t)
	local it, expect = t.it, t.expect
	local S = t.services
	local Weapons = require(game.ReplicatedStorage.Shared.Config.Weapons)
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")
	local Stats = game:GetService("Stats")

	local function waitFor(pred, timeout)
		local t0 = os.clock()
		while not pred() do
			if os.clock() - t0 > timeout then
				return false
			end
			task.wait(0.05)
		end
		return true
	end

	it("runs 20 clean rounds", function()
		local p = Players:GetPlayers()[1]
		local rounds = tonumber(Workspace:GetAttribute("CCSoakRounds")) or 20
		S.DevGate.set("ContractFixtures", true)
		S.DevGate.set("MinimumReady", 1)
		S.DevGate.set("AllowEmptyTeam", true)
		S.DevGate.set("CountdownSeconds", 1)
		S.DevGate.set("IntroSeconds", 1)
		S.DevGate.set("LiveSeconds", 6)
		S.DevGate.set("ResultsSeconds", 2)
		S.DevGate.set("IntermissionSeconds", 1)
		S.RoundService.applyDevSettings()
		S.DiagnosticsService.resetForTests()
		local mem0 = Stats:GetTotalMemoryUsageMb()
		local summary = { rounds = {}, problems = {} }
		local lastMap = nil
		local seq = 700000
		local function problem(text)
			table.insert(summary.problems, text)
		end
		for r = 1, rounds do
			-- between rounds: free kit choice
			assert(waitFor(function()
				local st = S.RoundService.state()
				return st == "Waiting" or st == "Intermission" or st == "Countdown"
			end, 30), "round " .. r .. ": never returned to staging")
			local kitId = Weapons.Order[(r - 1) % #Weapons.Order + 1]
			local ok, reason = S.LoadoutService.select(p, kitId)
			if not ok then
				problem(string.format("round %d: select %s refused (%s)", r, kitId, tostring(reason)))
			end
			S.TeamService.touch(p)
			S.TeamService.setReadyServer(p, true)
			assert(waitFor(function()
				return S.RoundService.state() == "Live" and S.CharacterService.isAlive(p) and S.PaintService.isSynced(p)
			end, 40), "round " .. r .. ": did not go live")
			local desc = S.RoundService.currentMap()
			local rec = { round = r, map = desc.mapId, kit = S.LoadoutService.kit(p).Id, fixture = desc.isFixture }
			if lastMap and desc.mapId == lastMap then
				problem(string.format("round %d: map did not alternate (%s)", r, desc.mapId))
			end
			if rec.kit ~= kitId then
				problem(string.format("round %d: locked kit %s, chose %s", r, rec.kit, kitId))
			end
			if S.CharacterService.stats(p).eliminations ~= 0 or S.PaintService.contributionOf(p) ~= 0 then
				problem(string.format("round %d: stats not reset", r))
			end
			lastMap = desc.mapId
			-- leave the base and act: shots, a gadget, an ultimate
			local life = S.CharacterService.life(p)
			local side = if S.TeamService.teamOf(p) == 1 then -1 else 1
			S.CharacterService.teleport(p, CFrame.new(side * 30, 103, 20))
			task.wait(0.4)
			S.CharacterService.onOffensiveAction(p)
			local function act(a, dir)
				seq += 1
				life = S.CharacterService.life(p)
				S.CombatService.handleAction(p, { m = S.RoundService.matchId(), l = life.lifeId, s = seq, a = a, t = Workspace:GetServerTimeNow(), o = life.root.Position + Vector3.new(0, 1.1, 0), d = dir.Unit })
			end
			for k = 1, 4 do
				S.LoadoutService.fillTank(p)
				act(if Weapons.Defs[kitId].Family == "charger" then "ChargeStart" else "Fire", Vector3.new(-side, -0.3, math.sin(k)))
				task.wait(0.3)
				if Weapons.Defs[kitId].Family == "charger" then
					act("ChargeRelease", Vector3.new(-side, -0.2, 0))
				end
			end
			S.LoadoutService.fillTank(p)
			act("Gadget", Vector3.new(-side, 0.2, 0))
			S.LoadoutService.setUltimateForTests(p, 100)
			task.wait(1.1)
			act("Ultimate", Vector3.new(-side, 0.3, 0.2))
			-- the round ends with things in flight
			assert(waitFor(function()
				return S.RoundService.state() == "Results"
			end, 20), "round " .. r .. ": no results")
			local res = S.RoundService.lastResults()
			rec.outcome = res and res.outcome
			rec.painted = res and res.total and (res.a + res.b) or 0
			assert(waitFor(function()
				local st = S.RoundService.state()
				return st == "Intermission" or st == "Waiting" or st == "Countdown"
			end, 20), "round " .. r .. ": no reset")
			task.wait(0.3)
			local c = S.AbilityService.counts()
			if c.throwables + c.storms + c.screens ~= 0 or S.CombatService.projectileCount() ~= 0 then
				problem(string.format("round %d: entities survived reset (thr %d storm %d scr %d proj %d)", r, c.throwables, c.storms, c.screens, S.CombatService.projectileCount()))
			end
			local arena = Workspace:FindFirstChild("ColorClashArena")
			if arena and #arena:GetChildren() > 0 then
				local names = {}
				for _, ch in arena:GetChildren() do
					table.insert(names, ch.Name)
				end
				problem(string.format("round %d: arena not empty after reset: %s", r, table.concat(names, ",")))
			end
			table.insert(summary.rounds, rec)
		end
		S.TeamService.setReadyServer(p, false)
		summary.memDeltaMb = math.floor((Stats:GetTotalMemoryUsageMb() - mem0) * 10) / 10
		summary.handlerErrors = 0
		for name, n in S.DiagnosticsService.counters() do
			if string.find(name, "RemoteHandlerError", 1, true) then
				summary.handlerErrors += n
			end
		end
		summary.hashMismatch = S.DiagnosticsService.getCount("PaintHashMismatch")
		Workspace:SetAttribute("CCSoak", HttpService:JSONEncode(summary))
		S.DevGate.clear()
		S.RoundService.applyDevSettings()
		expect(#summary.rounds):toBe(rounds)
		expect(#summary.problems):toBe(0)
		expect(summary.handlerErrors):toBe(0)
	end)
end
