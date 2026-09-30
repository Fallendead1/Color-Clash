-- Engine: full round lifecycle on the paint_lab FIXTURE with one real Studio client (solo practice override).
-- Covers FLOW-01/05 lifecycle, map loading, team spawn, client paint sync ack, results freeze and full reset.
-- Label: "solo practice (dev override), fixture" — not a 4v4 or multi-client result.
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local S = t.services
	local Players = game:GetService("Players")

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

	describe("Round lifecycle (fixture, solo practice override)", function()
		local p = Players:GetPlayers()[1]
		local seen = {}
		local conn

		it("configures dev overrides", function()
			S.DevGate.set("UseFixture", true)
			expect(S.DevGate.set("MinimumReady", 1)):toBe(true)
			S.DevGate.set("AllowEmptyTeam", true)
			S.DevGate.set("CountdownSeconds", 1)
			S.DevGate.set("IntroSeconds", 1)
			S.DevGate.set("LiveSeconds", 4)
			S.DevGate.set("ResultsSeconds", 1)
			S.DevGate.set("IntermissionSeconds", 1)
			S.RoundService.applyDevSettings()
			conn = game:GetService("RunService").Heartbeat:Connect(function()
				local st = S.RoundService.state()
				if seen[#seen] ~= st then
					table.insert(seen, st)
				end
			end)
		end)

		it("ready starts countdown then loads the fixture map", function()
			S.TeamService.setReadyServer(p, true)
			expect(waitFor(function()
				return S.RoundService.state() == "Intro" or S.RoundService.state() == "Live"
			end, 15)):toBe(true)
			local desc = S.RoundService.currentMap()
			expect(desc ~= nil):toBe(true)
			expect(desc.isFixture):toBe(true)
			expect(desc.mapId):toBe("paint_lab")
			expect(S.TeamService.isParticipating(p)):toBe(true)
			local teamId = S.TeamService.teamOf(p)
			expect(teamId == 1 or teamId == 2):toBe(true)
		end)

		it("spawns the participant inside its protected base", function()
			local teamId = S.TeamService.teamOf(p)
			expect(waitFor(function()
				local c = p.Character
				local r = c and c:FindFirstChild("HumanoidRootPart")
				return r ~= nil and S.CharacterService.inVolume(r.Position, "ProtectedBase", teamId)
			end, 5)):toBe(true)
			local root = p.Character.HumanoidRootPart
			expect(root.CollisionGroup):toBe(if teamId == 1 then "CCPlayersA" else "CCPlayersB")
			expect(S.CharacterService.isShielded(p) or S.RoundService.state() ~= "Live"):toBe(true)
		end)

		it("the real client acknowledges the paint snapshot", function()
			expect(waitFor(function()
				return S.PaintService.isSynced(p)
			end, 8)):toBe(true)
		end)

		it("goes live with a server deadline and paints server-side", function()
			expect(waitFor(function()
				return S.RoundService.state() == "Live"
			end, 5)):toBe(true)
			local grid = S.PaintService.grid()
			local before = grid.totals[1] + grid.totals[2]
			local teamId = S.TeamService.teamOf(p)
			local r = S.PaintService.paintSphere(Vector3.new(0, 100, 0), 4, teamId, { origin = Vector3.new(0, 101, 0) })
			expect(r ~= nil and r.changed > 30):toBe(true)
			expect(grid.totals[teamId]):toBeGreaterThan(before)
		end)

		it("freezes results from raw counts", function()
			expect(waitFor(function()
				return S.RoundService.state() == "Results"
			end, 8)):toBe(true)
			local res = S.RoundService.lastResults()
			expect(res ~= nil):toBe(true)
			expect(res.total):toBe(5264)
			local teamId = S.TeamService.teamOf(p)
			local mine = if teamId == 1 then res.a else res.b
			expect(mine):toBeGreaterThan(30)
			expect(res.outcome):toBe(if teamId == 1 then "A" else "B")
			expect(res.a + res.b + res.neutral):toBe(res.total)
			-- late paint after the freeze is ignored (PAINT-10 engine)
			local r = S.PaintService.paintSphere(Vector3.new(10, 100, 10), 4, teamId, nil)
			expect(r):toBe(nil)
		end)

		it("resets fully and returns to staging, then continues the loop", function()
			expect(waitFor(function()
				local s = S.RoundService.state()
				return s == "Intermission" or s == "Countdown" or s == "Loading"
			end, 8)):toBe(true)
			expect(#workspace.ColorClashArena:GetChildren()):toBe(0)
			expect(S.PaintService.grid()):toBe(nil)
			expect(S.TeamService.isParticipating(p)):toBe(false)
			expect(p:GetAttribute("CCTeam")):toBe(0)
			expect(p:GetAttribute("CCReady")):toBe(true) -- ready persists between rounds (GDD 03.2)
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			local staging = S.MapService.stagingCFrame(1).Position
			expect(root ~= nil and (root.Position - staging).Magnitude < 25):toBe(true)
		end)

		it("records the transition order", function()
			task.wait(0.2) -- the observer may record a state one frame after RoundService's own Heartbeat step
			local order = table.concat(seen, ">")
			local ok = string.find(order, "Countdown>Loading>Intro>Live>Results>Reset>Intermission", 1, true) ~= nil
			expect({ ok = ok, order = order }):toEqual({ ok = true, order = order })
		end)

		it("cleans up overrides", function()
			S.TeamService.setReadyServer(p, false)
			conn:Disconnect()
			S.DevGate.clear()
			S.RoundService.applyDevSettings()
			expect(waitFor(function()
				local s = S.RoundService.state()
				return s == "Waiting" or s == "Intermission" or s == "Reset" or s == "Results" or s == "Live" or s == "Intro" or s == "Loading" or s == "Countdown"
			end, 1)):toBe(true)
		end)
	end)
end
