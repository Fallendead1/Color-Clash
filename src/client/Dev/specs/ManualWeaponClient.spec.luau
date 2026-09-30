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
		elseif scenario == "gadget" then
			-- kit lane_roller (Paint Screen), placed at "0,100,-4,1,0" outside the base, ultimate meter below 100
			C.CameraController.faceDirection(Vector3.new(1, 0, 0))
			task.wait(0.3)
			local folder = workspace.ColorClashArena:WaitForChild("Screens" .. (if player:GetAttribute("CCTeam") == 1 then "A" else "B"), 5)
			local before = #folder:GetChildren()
			local st = C.WeaponController.stats().byAction
			local g0, u0 = st.Gadget or 0, st.Ultimate or 0
			C.InputController.press("Gadget", true)
			C.InputController.press("Gadget", false)
			local t0 = os.clock()
			while #folder:GetChildren() == before and os.clock() - t0 < 2 do
				task.wait(0.05)
			end
			C.InputController.press("Ultimate", true) -- meter not full: the client does not even send
			C.InputController.press("Ultimate", false)
			task.wait(0.1)
			st = C.WeaponController.stats().byAction
			player:SetAttribute("CCWeaponDiag", string.format("gadget sent=%d ult sent=%d screens=%d", (st.Gadget or 0) - g0, (st.Ultimate or 0) - u0, #folder:GetChildren()))
			expect((st.Gadget or 0) - g0):toBe(1)
			expect(#folder:GetChildren()):toBe(before + 1) -- the server placed the replicated screen
			expect((st.Ultimate or 0) - u0):toBe(0)
		else
			error("unknown scenario " .. tostring(scenario))
		end
	end)
end
