-- Real-client weapon behaviour driven through the semantic input layer (no OS injection needed).
-- Scenario from LocalPlayer attribute CCWeaponScenario (server prepares kit + placement with harness steps):
--   "dash"   : kit twin_jets, placed at "-13,100,-10,0,1" (neutral wall x -17..-15 to the camera-right side);
--              a stationary dash goes camera-right into the wall and must stop at it (WEAPON-02 bounded dash)
--   "charge" : kit linecaster; opening a panel mid-charge and pressing Glide mid-charge both cancel (never fire)
return function(t)
	local it, expect = t.it, t.expect
	local C = t.services
	local player = game.Players.LocalPlayer
	local RunService = game:GetService("RunService")

	it("weapon scenario", function()
		local scenario = player:GetAttribute("CCWeaponScenario")
		local root = player.Character.HumanoidRootPart
		if scenario == "dash" then
			C.CameraController.faceDirection(Vector3.new(0, 0, 1))
			task.wait(0.4)
			local minX = root.Position.X
			local conn = RunService.PostSimulation:Connect(function()
				minX = math.min(minX, root.Position.X)
			end)
			local sent0 = C.WeaponController.stats().byAction.Dash or 0
			C.InputController.press("Secondary", true)
			task.wait(0.05)
			C.InputController.press("Secondary", false)
			task.wait(0.6)
			conn:Disconnect()
			player:SetAttribute("CCWeaponDiag", string.format("dash sent=%d minX=%.2f endX=%.2f", (C.WeaponController.stats().byAction.Dash or 0) - sent0, minX, root.Position.X))
			expect((C.WeaponController.stats().byAction.Dash or 0) - sent0):toBe(1)
			expect(minX):toBeGreaterThan(-15.2) -- the wall face is at x = -15: the dash stops there
			expect(minX):toBeLessThan(-13.5) -- and it did move toward it
		elseif scenario == "charge" then
			C.CameraController.faceDirection(Vector3.new(1, 0, 0))
			task.wait(0.3)
			local st = C.WeaponController.stats().byAction
			local rel0, can0 = st.ChargeRelease or 0, st.ChargeCancel or 0
			-- panel entry mid-charge cancels
			C.InputController.press("Primary", true)
			task.wait(0.6)
			expect(C.WeaponController.state().charging):toBe(true)
			C.UIController.openPanel("Controls")
			task.wait(0.1)
			expect(C.WeaponController.state().charging):toBe(false)
			C.UIController.closePanel("Controls")
			C.InputController.press("Primary", false)
			-- glide mid-charge cancels
			task.wait(0.4)
			C.InputController.press("Primary", true)
			task.wait(0.4)
			C.InputController.press("Glide", true)
			task.wait(0.1)
			expect(C.WeaponController.state().charging):toBe(false)
			C.InputController.press("Glide", false)
			C.InputController.press("Primary", false)
			task.wait(0.2)
			st = C.WeaponController.stats().byAction
			player:SetAttribute("CCWeaponDiag", string.format("charge release=%d cancel=%d", (st.ChargeRelease or 0) - rel0, (st.ChargeCancel or 0) - can0))
			expect((st.ChargeRelease or 0) - rel0):toBe(0)
			expect((st.ChargeCancel or 0) - can0):toBe(2)
		else
			error("unknown scenario " .. tostring(scenario))
		end
	end)
end
