-- Real-mouse firing sampler (hold left mouse ~1 s via the Studio MCP). Scenario from CCFireScenario:
--   "hit"  : placed at "0,100,-4,1,0" facing practice target 1 at x=10 -> cadence-paced shots, confirmed hits,
--            predicted + authoritative paint, no lingering prediction
--   "base" : placed inside the own protected base facing out -> every shot denied ("base"); predicted paint from
--            denied shots is removed within 0.5 s (PAINT-12 with real weapon fire)
return function(t)
	local it, expect = t.it, t.expect
	local C = t.services
	local UIS = game:GetService("UserInputService")
	local player = game.Players.LocalPlayer

	it("fires with the real mouse", function()
		local scenario = player:GetAttribute("CCFireScenario")
		local teamId = player:GetAttribute("CCTeam")
		local faceX = if scenario == "base" then (if teamId == 1 then 1 else -1) else 1
		C.CameraController.faceDirection(Vector3.new(faceX, 0, 0))
		C.CameraController.setPitch(if scenario == "base" then -0.35 else -0.12)
		task.wait(0.3)
		local w0 = table.clone(C.WeaponController.stats())
		local grid = C.PaintClient.grid()
		local owned0 = grid and grid.totals[teamId] or 0
		local target = workspace.ColorClashArena:FindFirstChild("PracticeTargets", true)
		local t1 = target and target:FindFirstChild("Target1")
		local health0 = t1 and t1:GetAttribute("Health")
		player:SetAttribute("CCSamplerReady", true)
		local mouseFrames, maxPredicted = 0, 0
		local minHealth = 100
		local t0 = os.clock()
		while os.clock() - t0 < 2.2 do
			if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				mouseFrames += 1
			end
			maxPredicted = math.max(maxPredicted, C.PaintClient.renderer():Stats().predicted)
			if t1 then
				minHealth = math.min(minHealth, t1:GetAttribute("Health") or 100)
			end
			task.wait()
		end
		task.wait(0.7) -- let denials/confirmations settle (0.5 s tolerance + margin)
		player:SetAttribute("CCSamplerReady", false)
		local w1 = C.WeaponController.stats()
		local sent = w1.sent - w0.sent
		local denied = w1.denied - w0.denied
		local predictedLeft = C.PaintClient.renderer():Stats().predicted
		local health1 = t1 and t1:GetAttribute("Health")
		local owned1 = grid and grid.totals[teamId] or 0
		player:SetAttribute("CCFireDiag", string.format("%s mouseFrames=%d sent=%d denied=%d maxPredicted=%d predictedLeft=%d health %s->%s min=%d owned %d->%d", scenario, mouseFrames, sent, denied, maxPredicted, predictedLeft, tostring(health0), tostring(health1), minHealth, owned0, owned1))
		assert(mouseFrames > 20, "INPUT NOT DELIVERED — rerun")
		expect(predictedLeft):toBe(0)
		if scenario == "hit" then
			-- ~1 s of held fire at a 0.12 s cadence
			expect(sent):toBeGreaterThan(5)
			expect(sent):toBeLessThan(12)
			expect(denied):toBe(0)
			expect(minHealth):toBeLessThan(100) -- confirmed server hits on the target
			expect(owned1):toBeGreaterThan(owned0) -- authoritative paint arrived (trail drips / impacts)
		else
			expect(sent):toBeGreaterThan(3)
			expect(denied):toBe(sent)
			-- With Studio's near-zero latency the denial usually arrives before the cosmetic shot lands, so the shot is
			-- cancelled before any predicted paint is drawn (maxPredicted may be 0). Either way nothing may remain.
			expect(owned1):toBe(owned0)
		end
	end)
end
