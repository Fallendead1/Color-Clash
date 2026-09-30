-- Client engine tests: UI-01 (single root, contract valid, no duplicate handlers), input contexts and focus rules
-- (GDD 04.3, 12.4). Runs inside the real Studio client VM.
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local C = t.services
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer
	local UIContract = t.require("UI/UIContract")

	describe("UI-01 bootstrap", function()
		it("has exactly one ColorClashUI root that passes the contract", function()
			local n = 0
			for _, g in player.PlayerGui:GetChildren() do
				if g.Name == UIContract.RootName then
					n += 1
				end
			end
			expect(n):toBe(1)
			local _, errors = UIContract.validate(C.UIController.root())
			expect(#errors):toBe(0)
			expect(player:GetAttribute("CCUIErrors")):toBe(0)
			local authored = game:GetService("StarterGui"):FindFirstChild("ColorClashUI")
			expect(C.UIController.isWireframe()):toBe(authored == nil)
		end)

		it("client bootstrap ran once", function()
			expect(player:GetAttribute("ColorClashClientStarted")):toBe(true)
			expect(player:GetAttribute("ColorClashClientReady")):toBe(true)
		end)

		it("a contract violation is detected (missing key, wrong class, duplicate)", function()
			local gui = C.UIController.root():Clone()
			local timer = nil
			local ready = nil
			for _, d in gui:GetDescendants() do
				if d:GetAttribute("UIKey") == "HUD.Timer" then
					timer = d
				elseif d:GetAttribute("UIKey") == "Staging.Ready" then
					ready = d
				end
			end
			timer:SetAttribute("UIKey", nil)
			local dup = ready:Clone()
			dup.Parent = ready.Parent
			local _, errors = UIContract.validate(gui)
			local text = table.concat(errors, "\n")
			expect(string.find(text, "missing mandatory UIKey HUD.Timer", 1, true) ~= nil):toBe(true)
			expect(string.find(text, "duplicate UIKey Staging.Ready", 1, true) ~= nil):toBe(true)
			gui:Destroy()
		end)
	end)

	describe("Input contexts and focus", function()
		local I = C.InputController
		local U = C.UIController

		it("combat actions are ignored outside Gameplay", function()
			local saved = U.gameplayContext
			U.setGameplayContext("Disabled")
			I.press("Primary", true)
			expect(I.isHeld("Primary")):toBe(false)
			I.press("Primary", false)
			U.setGameplayContext(saved)
		end)

		it("opening a panel releases held actions and switches to Menu; closing restores", function()
			local saved = U.gameplayContext
			U.setGameplayContext("Gameplay")
			I.press("Primary", true)
			I.press("Glide", true)
			expect(I.isHeld("Primary")):toBe(true)
			U.openPanel("Controls")
			expect(I.context()):toBe("Menu")
			expect(I.isHeld("Primary")):toBe(false)
			expect(I.isHeld("Glide")):toBe(false)
			I.press("Primary", true)
			expect(I.isHeld("Primary")):toBe(false) -- nothing fires while a panel is open
			I.press("Primary", false)
			U.closePanel("Controls")
			expect(I.context()):toBe("Gameplay")
			U.setGameplayContext(saved)
			expect(I.context()):toBe(saved)
		end)

		it("panel stack: closing the top panel reveals the one below", function()
			U.openPanel("Armory")
			U.openPanel("Controls")
			expect(U.isOpen("Armory")):toBe(true)
			expect(U.get("Armory.Root").Visible):toBe(false)
			U.closePanel()
			expect(U.get("Armory.Root").Visible):toBe(true)
			U.closeAllPanels()
			expect(#U.openPanels()):toBe(0)
		end)

		it("releaseAll clears every held action (focus loss / death path)", function()
			local saved = U.gameplayContext
			U.setGameplayContext("Gameplay")
			I.press("Primary", true)
			I.press("Secondary", true)
			I.releaseAll("test")
			expect(I.isHeld("Primary")):toBe(false)
			expect(I.isHeld("Secondary")):toBe(false)
			U.setGameplayContext(saved)
		end)

		it("glide toggle mode toggles on press only", function()
			local saved = U.gameplayContext
			U.setGameplayContext("Gameplay")
			I.setGlideToggle(true)
			I.press("Glide", true)
			I.press("Glide", false)
			expect(I.isHeld("Glide")):toBe(true)
			I.press("Glide", true)
			I.press("Glide", false)
			expect(I.isHeld("Glide")):toBe(false)
			I.setGlideToggle(false)
			U.setGameplayContext(saved)
		end)
	end)
end
