-- Diagnostic sampler: records input context, semantic action state and raw key state for 2.5 s.
return function(t)
	local it, expect = t.it, t.expect
	local C = t.services
	local UIS = game:GetService("UserInputService")
	local player = game.Players.LocalPlayer
	it("samples input state", function()
		player:SetAttribute("CCSamplerReady", true)
		local seenCtx, seenGlide, seenShift, seenW = {}, false, false, false
		local t0 = os.clock()
		while os.clock() - t0 < 2.5 do
			seenCtx[C.InputController.context()] = true
			seenGlide = seenGlide or C.InputController.isHeld("Glide")
			seenShift = seenShift or UIS:IsKeyDown(Enum.KeyCode.LeftShift)
			seenW = seenW or UIS:IsKeyDown(Enum.KeyCode.W)
			task.wait()
		end
		player:SetAttribute("CCSamplerReady", false)
		local ctx = {}
		for k in seenCtx do
			table.insert(ctx, k)
		end
		player:SetAttribute("CCDiag", string.format("ctx=%s glideHeld=%s shiftDown=%s wDown=%s device=%s", table.concat(ctx, ","), tostring(seenGlide), tostring(seenShift), tostring(seenW), C.InputController.device()))
		expect(true):toBe(true)
	end)
end
