-- Real client: tactical map + Team Launch through the real Launch remote (MAP-01 client side, ABIL-07 end to end).
-- Server prepares with harness:MatchSetup then harness:Place at "-17,100,-26,1,0" (own-paint strip).
-- Semantic input (InputController.press) opens the map; the controller confirms a Base launch.
return function(t)
	local it, expect = t.it, t.expect
	local C = t.services
	local player = game.Players.LocalPlayer
	local ui = C.UIController
	local map = C.TacticalMapController

	it("map projection, target list and a Base launch", function()
		local grid = C.PaintClient.grid()
		expect(grid ~= nil):toBe(true)
		C.InputController.press("Map", true)
		C.InputController.press("Map", false)
		task.wait(0.3)
		expect(ui.isOpen("Map")):toBe(true)
		expect(C.InputController.context()):toBe("Menu")
		local st = map.state()
		-- MAP-01: the map is the same grid (same scoreable area and ownership)
		expect(st.proj.scoringCells):toBe(grid.totalScoringArea)
		expect(st.proj.totals[1]):toBe(grid.totals[1])
		expect(st.proj.totals[2]):toBe(grid.totals[2])
		expect((ui.get("Map.Image"):GetAttribute("PixelsDrawn") or 0) > 0):toBe(true)
		-- solo: Base is the only target
		local list = ui.get("Map.TargetList")
		local targets = {}
		for _, b in list:GetChildren() do
			if b:GetAttribute("LaunchTarget") ~= nil then
				table.insert(targets, b:GetAttribute("LaunchTarget"))
			end
		end
		expect(#targets):toBe(1)
		expect(targets[1]):toBe("Base")
		expect(map.confirm()):toBe(false) -- nothing selected yet
		map.select("Base")
		local t0 = os.clock()
		expect(map.confirm()):toBe(true)
		local sawChannel = false
		while os.clock() - t0 < 4 and map.stats().lastState ~= "arrived" do
			if map.stats().lastState == "channel" then
				sawChannel = true
			end
			task.wait(0.05)
		end
		local dt = os.clock() - t0
		player:SetAttribute("CCMapDiag", string.format("state=%s reason=%s dt=%.2f", tostring(map.stats().lastState), tostring(map.stats().lastReason), dt))
		expect(sawChannel):toBe(true)
		expect(map.stats().lastState):toBe("arrived")
		expect(dt > 1.8 and dt < 2.6):toBe(true)
		expect(ui.isOpen("Map")):toBe(false) -- closed at departure
		local root = player.Character.HumanoidRootPart
		local team = player:GetAttribute("CCTeam")
		expect(if team == 1 then root.Position.X < -32 else root.Position.X > 32):toBe(true) -- in the own base
		-- cooldown is reported, not silently ignored
		map.open()
		map.select("Base")
		map.confirm()
		task.wait(0.5)
		expect(map.stats().lastReason):toBe("cooldown")
		expect(map.state().status):toBe("Launch is recharging")
		C.InputController.press("Map", true)
		C.InputController.press("Map", false)
		task.wait(0.2)
		expect(ui.isOpen("Map")):toBe(false)
		expect(C.InputController.context()):toBe("Gameplay")
	end)
end
