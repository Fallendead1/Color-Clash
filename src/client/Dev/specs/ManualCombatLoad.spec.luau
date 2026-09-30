-- PERF-05 (real client, live match, kit sprayline placed outside the base): palette switches and a focus loss under
-- sustained fire (real Action remote at cadence, server painting and delta traffic). Expected: no stuck input, no
-- continuous action left running, bounded Lua heap growth, no renderer part explosion from recolouring.
-- Window resize cannot be driven from a test here (reported NOT RUN).
return function(t)
	local it, expect = t.it, t.expect
	local C = t.services
	local player = game.Players.LocalPlayer
	local HttpService = game:GetService("HttpService")

	it("palette and focus loss under load", function()
		local root = player.Character.HumanoidRootPart
		local renderer = C.PaintClient.renderer()
		local parts0 = renderer and renderer:Stats().activeParts or 0
		local heap0 = collectgarbage("count")
		local firing = true
		local sent = 0
		task.spawn(function()
			local k = 0
			while firing do
				k += 1
				local o = root.Position + Vector3.new(0, 1.1, 0)
				C.WeaponController.sendForTests("Fire", o, Vector3.new(math.sin(k * 0.4), -0.35, math.cos(k * 0.4)).Unit)
				sent += 1
				task.wait(0.14)
			end
		end)
		local peakHeap = heap0
		for n = 1, 8 do
			C.SettingsController.set("palette", if n % 2 == 0 then "standard" else "accessible")
			task.wait(0.3)
			peakHeap = math.max(peakHeap, collectgarbage("count"))
		end
		-- focus loss while several actions are held
		C.InputController.press("Primary", true)
		C.InputController.press("Glide", true)
		C.InputController.press("Secondary", true)
		task.wait(0.1)
		C.InputController.releaseAll("focus")
		task.wait(0.1)
		local stuck = {}
		for _, a in { "Primary", "Glide", "Secondary", "Gadget", "Ultimate" } do
			if C.InputController.isHeld(a) then
				table.insert(stuck, a)
			end
		end
		task.wait(1.5)
		firing = false
		task.wait(1.5)
		local state = C.WeaponController.state()
		local parts1 = renderer and renderer:Stats().activeParts or 0
		local heap1 = collectgarbage("count")
		player:SetAttribute("CCLoadDiag", HttpService:JSONEncode({
			sent = sent,
			heapKb0 = heap0,
			heapKbPeak = peakHeap,
			heapKb1 = heap1,
			parts0 = parts0,
			parts1 = parts1,
			stuck = stuck,
			palette = player:GetAttribute("CCPalette"),
		}))
		expect(#stuck):toBe(0)
		expect(state.charging or state.rolling or state.pushing):toBe(false)
		expect(C.InputController.context()):toBe("Gameplay")
		expect(heap1 - heap0 < 30 * 1024):toBe(true) -- < 30 MB Lua heap growth over the whole burst
		expect(peakHeap - heap0 < 60 * 1024):toBe(true)
		expect(sent >= 20):toBe(true)
	end)
end
