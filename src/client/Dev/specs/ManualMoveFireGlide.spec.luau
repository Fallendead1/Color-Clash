-- MOVE-02 sampler: glide on own paint (hold LeftShift+W), then a light attack is noted; the character must leave
-- Glide within 0.12 s and the camera must stay controllable. Placement: harness:Place "-28,100,-26,1,0".
return function(t)
	local it, expect = t.it, t.expect
	local C = t.services
	local UIS = game:GetService("UserInputService")
	local player = game.Players.LocalPlayer

	it("fire exits glide within 0.12 s", function()
		C.CameraController.faceDirection(Vector3.new(1, 0, 0))
		player:SetAttribute("CCSamplerReady", true)
		local t0 = os.clock()
		while C.MovementController.state() ~= "Gliding" and os.clock() - t0 < 4 do
			task.wait()
		end
		local keys = UIS:IsKeyDown(Enum.KeyCode.LeftShift)
		assert(keys or C.MovementController.state() == "Gliding", "INPUT NOT DELIVERED — rerun")
		expect(C.MovementController.state()):toBe("Gliding")
		task.wait(0.3)
		local fired = os.clock()
		C.MovementController.noteFired(nil)
		local exited = nil
		while os.clock() - fired < 0.5 do
			if C.MovementController.state() ~= "Gliding" then
				exited = os.clock() - fired
				break
			end
			task.wait()
		end
		player:SetAttribute("CCFireGlideExit", exited)
		expect(exited ~= nil):toBe(true)
		expect(exited):toBeLessThan(0.12)
		local y0 = C.CameraController.yaw()
		C.CameraController.addLook(0.05, 0)
		expect(math.abs(C.CameraController.yaw() - y0)):toBeGreaterThan(0.01)
		player:SetAttribute("CCSamplerReady", false)
	end)
end
