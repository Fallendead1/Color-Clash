-- Duel sampler for the TWO-CLIENT test (run in the attacking client's window). Faces the opponent position published
-- by the server (Workspace attribute CCDuelTarget) and fires for ~1.5 s.
-- Input path: real OS mouse if the Studio MCP injection reaches this window within 0.6 s; otherwise the same semantic
-- Primary action is pressed inside this real client (InputController.press — the touch path). Either way the shots
-- travel over the real network from this client to the server. The path used is reported in CCDuelDiag.
return function(t)
	local it, expect = t.it, t.expect
	local C = t.services
	local UIS = game:GetService("UserInputService")
	local player = game.Players.LocalPlayer

	it("aims at the opponent and fires over the network", function()
		local target = workspace:GetAttribute("CCDuelTarget")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		assert(typeof(target) == "Vector3" and root, "no duel target / character")
		C.CameraController.faceDirection(target - root.Position)
		C.CameraController.setPitch(-0.05)
		task.wait(0.3)
		local w0 = table.clone(C.WeaponController.stats())
		player:SetAttribute("CCSamplerReady", true)
		local mouseFrames = 0
		local t0 = os.clock()
		while os.clock() - t0 < 0.6 do
			if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				mouseFrames += 1
			end
			task.wait()
		end
		local path = "mouse"
		if mouseFrames == 0 then
			path = "semantic-press"
			C.InputController.press("Primary", true)
			task.wait(1.5)
			C.InputController.press("Primary", false)
		else
			task.wait(1.5)
		end
		player:SetAttribute("CCSamplerReady", false)
		task.wait(0.3)
		local w1 = C.WeaponController.stats()
		player:SetAttribute("CCDuelDiag", string.format("path=%s mouseFrames=%d sent=%d denied=%d", path, mouseFrames, w1.sent - w0.sent, w1.denied - w0.denied))
		expect(w1.sent - w0.sent):toBeGreaterThan(5)
		expect(w1.denied - w0.denied):toBe(0)
	end)
end
