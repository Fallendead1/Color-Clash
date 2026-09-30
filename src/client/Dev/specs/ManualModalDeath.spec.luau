-- UI-09 (real client, live match): elimination while panels are open. Driver: server harness:MatchSetup, start this
-- spec, then harness:Place with CCPlaceAction = "eliminate". Expected: the tactical map closes on death (no stale
-- launch UI), the Settings panel the player opened stays consistent on the stack, the elimination screen shows, and
-- the new life gets a fresh HUD; closing the panel afterwards restores Gameplay (no stuck Menu context).
return function(t)
	local it, expect = t.it, t.expect
	local C = t.services
	local player = game.Players.LocalPlayer
	local U = C.UIController

	it("death during open panels, then respawn", function()
		local function waitAttr(name, value, timeout)
			local t0 = os.clock()
			while player:GetAttribute(name) ~= value and os.clock() - t0 < timeout do
				task.wait(0.05)
			end
			return player:GetAttribute(name) == value
		end
		expect(player:GetAttribute("CCAlive")):toBe(true)
		U.openPanel("Settings")
		C.TacticalMapController.open()
		expect(U.openPanels()[#U.openPanels()]):toBe("Map")
		player:SetAttribute("CCModalDiag", "waiting for elimination")
		expect(waitAttr("CCAlive", false, 25)):toBe(true)
		task.wait(0.3)
		expect(U.isOpen("Map")):toBe(false)
		expect(U.isOpen("Settings")):toBe(true)
		expect(U.get("Settings.Root").Visible):toBe(true)
		expect(U.get("Map.Root").Visible):toBe(false)
		expect(U.get("Elimination.Root").Visible):toBe(true)
		expect(C.InputController.context()):toBe("Menu")
		expect(waitAttr("CCAlive", true, 10)):toBe(true)
		task.wait(0.5)
		expect(U.get("Elimination.Root").Visible):toBe(false)
		local health = U.get("HUD.Health")
		expect(health:GetAttribute("Value")):toNear(1, 1e-6)
		expect(C.InputController.context()):toBe("Menu") -- still in the panel the player opened
		U.closePanel("Settings")
		task.wait(0.1)
		expect(#U.openPanels()):toBe(0)
		expect(C.InputController.context()):toBe("Gameplay")
		player:SetAttribute("CCModalDiag", "done")
	end)
end
