-- MOVE-07: actions held when the player is eliminated never carry into the new life.
-- Run this spec, then trigger the server "harness:Place" with CCPlaceAction = "eliminate" within 3 s.
return function(t)
	local it, expect = t.it, t.expect
	local C = t.services
	local player = game.Players.LocalPlayer

	it("held actions are released across elimination and respawn", function()
		local life0 = player:GetAttribute("CCLifeId")
		C.InputController.press("Primary", true)
		C.InputController.press("Glide", true)
		expect(C.InputController.isHeld("Primary")):toBe(true)
		player:SetAttribute("CCSamplerReady", true)
		local t0 = os.clock()
		while player:GetAttribute("CCAlive") ~= false and os.clock() - t0 < 10 do
			task.wait()
		end
		expect(player:GetAttribute("CCAlive")):toBe(false)
		expect(C.InputController.isHeld("Primary")):toBe(false)
		expect(C.InputController.isHeld("Glide")):toBe(false)
		t0 = os.clock()
		while player:GetAttribute("CCAlive") ~= true and os.clock() - t0 < 10 do
			task.wait()
		end
		expect(player:GetAttribute("CCLifeId") ~= life0):toBe(true)
		task.wait(0.5)
		expect(C.InputController.isHeld("Primary")):toBe(false)
		expect(C.InputController.isHeld("Glide")):toBe(false)
		expect(C.MovementController.state() ~= "Gliding"):toBe(true)
		player:SetAttribute("CCSamplerReady", false)
	end)
end
