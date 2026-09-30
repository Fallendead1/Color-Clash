-- Client UI behaviour (Phase 07): UI-04 gamepad reach/escape, UI-05 viewport layout (wireframe), UI-06 long names and
-- eight-player scoreboard, UI-08 notices, UI-10 production-UI swap by keys, Settings apply + coalesced patches.
-- Staging-safe: runs outside a match. Layout checks apply to the WIREFRAME (Codex re-runs them on production UI).
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local C = t.services
	local UIContract = t.require("UI/UIContract")
	local Players = game:GetService("Players")
	local GuiService = game:GetService("GuiService")
	local player = Players.LocalPlayer
	local U = C.UIController
	local I = C.InputController
	local Wireframe = require(player.PlayerScripts.Client.UI.Wireframe)

	-- time-based (RenderStepped does not fire while the Studio viewport is hidden)
	local function waitFrames(n)
		task.wait(0.03 * n)
	end

	describe("UI-04 gamepad only", function()
		it("every panel opens with a gamepad selection inside it and closes with B", function()
			I.setDeviceForTests("Gamepad")
			for _, name in { "Armory", "Controls", "Settings", "Scoreboard" } do
				I.setDeviceForTests("Gamepad") -- the semantic press() below marks Touch; a real B press does not
				U.openPanel(name)
				waitFrames(8)
				local rootInst = U.get(U.PANELS[name])
				local sel = GuiService.SelectedObject
				player:SetAttribute("CCGamepadDiag", string.format("%s sel=%s device=%s", name, tostring(sel and sel:GetFullName()), I.device()))
				if name ~= "Scoreboard" then -- the scoreboard is read-only; it only needs to be escapable
					expect(sel ~= nil and sel:IsDescendantOf(rootInst)):toBe(true)
				end
				expect(I.context()):toBe("Menu")
				I.press("Cancel", true)
				I.press("Cancel", false)
				waitFrames(1)
				expect(U.isOpen(name)):toBe(false)
			end
			expect(#U.openPanels()):toBe(0)
			-- staging buttons are reachable by gamepad selection
			for _, key in { "Staging.Ready", "Staging.OpenArmory", "Staging.OpenControls", "Staging.OpenSettings" } do
				local b = U.get(key)
				expect(b ~= nil and b.Selectable):toBe(true)
			end
			I.setDeviceForTests(nil)
		end)
	end)

	describe("UI-05 viewports (wireframe)", function()
		it("buttons stay on screen, touch targets >= 48 px and do not overlap, text fits", function()
			local sizes = { { 1920, 1080 }, { 1366, 768 }, { 1280, 720 }, { 1024, 768 }, { 844, 390 }, { 740, 360 } }
			local problems = {}
			for _, sz in sizes do
				local holder = Instance.new("ScreenGui")
				holder.Name = "CCViewportTest"
				holder.IgnoreGuiInset = true
				holder.ScreenInsets = Enum.ScreenInsets.None
				holder.Enabled = true
				local viewport = Instance.new("Frame")
				viewport.Size = UDim2.fromOffset(sz[1], sz[2])
				viewport.BackgroundTransparency = 1
				viewport.Parent = holder
				local wf = Wireframe.build()
				for _, c in wf:GetChildren() do
					c.Parent = viewport
				end
				wf:Destroy()
				holder.Parent = player.PlayerGui
				local found = {}
				for _, d in viewport:GetDescendants() do
					local k = d:GetAttribute("UIKey")
					if k then
						found[k] = d
					end
				end
				-- show every panel and the touch layer (one at a time for panels, since they are centred overlays)
				local touch = found["Touch.Root"]
				if touch then
					touch.Visible = true
				end
				local origin = viewport.AbsolutePosition
				local function inside(g: GuiObject): boolean
					local p, s = g.AbsolutePosition - origin, g.AbsoluteSize
					return p.X >= -1 and p.Y >= -1 and p.X + s.X <= sz[1] + 1 and p.Y + s.Y <= sz[2] + 1
				end
				for panelName, rootKey in U.PANELS do
					local root = found[rootKey]
					if root then
						root.Visible = true
						waitFrames(2)
						for _, d in root:GetDescendants() do
							if d:IsA("GuiButton") and d:GetAttribute("UIKey") and not string.find(d:GetAttribute("UIKey"), "Template") then
								if not inside(d) then
									table.insert(problems, string.format("%dx%d %s off-screen", sz[1], sz[2], d:GetAttribute("UIKey")))
								end
								if d.AbsoluteSize.Y < 47.5 or d.AbsoluteSize.X < 47.5 then
									table.insert(problems, string.format("%dx%d %s smaller than 48 px", sz[1], sz[2], d:GetAttribute("UIKey")))
								end
							end
						end
						root.Visible = false
					end
					local _ = panelName
				end
				waitFrames(1)
				local touchKeys = {}
				for k, inst in found do
					if string.sub(k, 1, 6) == "Touch." and inst:IsA("GuiButton") then
						table.insert(touchKeys, inst)
						if not inside(inst) then
							table.insert(problems, string.format("%dx%d %s off-screen", sz[1], sz[2], k))
						end
						if inst.AbsoluteSize.X < 47.5 then
							table.insert(problems, string.format("%dx%d %s smaller than 48 px", sz[1], sz[2], k))
						end
					end
				end
				for a = 1, #touchKeys do
					for b = a + 1, #touchKeys do
						local pa, sa = touchKeys[a].AbsolutePosition, touchKeys[a].AbsoluteSize
						local pb, sb = touchKeys[b].AbsolutePosition, touchKeys[b].AbsoluteSize
						if pa.X < pb.X + sb.X and pb.X < pa.X + sa.X and pa.Y < pb.Y + sb.Y and pb.Y < pa.Y + sa.Y then
							table.insert(problems, string.format("%dx%d %s overlaps %s", sz[1], sz[2], touchKeys[a]:GetAttribute("UIKey"), touchKeys[b]:GetAttribute("UIKey")))
						end
					end
				end
				holder:Destroy()
			end
			player:SetAttribute("CCLayoutDiag", table.concat(problems, " | "))
			expect(#problems):toBe(0)
			expect(U.root().ScreenInsets):toBe(Enum.ScreenInsets.CoreUISafeInsets)
		end)
	end)

	describe("UI-06 long text and eight players", function()
		it("scoreboard groups, sorts by contribution and truncates long names", function()
			local long = "Participant_With_A_Very_Long_Display_Name_" -- 42 chars
			local list = {}
			for k = 1, 8 do
				table.insert(list, { userId = 1000 + k, name = long .. k, team = if k % 2 == 0 then 2 else 1, participating = true, paint = k * 37 % 200, eliminations = k, assists = 8 - k, deaths = k % 3 })
			end
			table.insert(list, { userId = 2000, name = "spectator", team = 0, participating = false, paint = 0 })
			U.openPanel("Scoreboard")
			C.ScoreboardController.renderRoster(list)
			waitFrames(2)
			local rows = C.ScoreboardController.rows()
			expect(#rows):toBe(8)
			local byParent = {}
			for _, r in rows do
				byParent[r.Parent] = byParent[r.Parent] or {}
				table.insert(byParent[r.Parent], r)
				expect(r.TextTruncate):toBe(Enum.TextTruncate.AtEnd)
				expect(r.AbsoluteSize.X <= r.Parent.AbsoluteSize.X + 1):toBe(true)
			end
			local teams = 0
			for parent, group in byParent do
				teams += 1
				expect(#group):toBe(4)
				table.sort(group, function(a, b)
					return a.LayoutOrder < b.LayoutOrder
				end)
				local last = math.huge
				for _, r in group do
					local paint = 0
					for _, src in list do
						if src.userId == r:GetAttribute("UserId") then
							paint = src.paint
						end
					end
					expect(paint <= last):toBe(true)
					last = paint
				end
				local _ = parent
			end
			expect(teams):toBe(2)
			-- empty roster
			C.ScoreboardController.renderRoster({})
			expect(#C.ScoreboardController.rows()):toBe(0)
			U.closePanel("Scoreboard")
			-- 30 % longer status text stays inside its label (scaled + wrapped)
			local status = U.get("Staging.Status")
			local before = status.Text
			status.Text = string.rep("Waiting for players to be ready ", 4)
			waitFrames(2)
			expect(status.TextScaled or status.TextFits):toBe(true)
			status.Text = before
		end)
	end)

	describe("UI-08 notices", function()
		it("connection delay needs two slow samples and is rate-limited", function()
			local S = C.ScreensController
			expect(S.checkConnection(0.6, 1000)):toBe(false)
			expect(S.checkConnection(0.7, 1002)):toBe(true)
			expect(S.checkConnection(0.7, 1004)):toBe(false) -- within 30 s
			expect(S.checkConnection(0.05, 1006)):toBe(false)
		end)
	end)

	describe("Settings apply locally and coalesce patches", function()
		it("sensitivity/palette apply at once; a burst becomes one patch", function()
			local SC = C.SettingsController
			local sent0 = SC.stats().patchesSent
			local sens0, pal0 = SC.get("sensitivity"), SC.get("palette")
			for k = 1, 10 do
				SC.set("sensitivity", 0.5 + k * 0.1)
			end
			SC.set("palette", "accessible")
			expect(player:GetAttribute("CCPalette")):toBe("accessible")
			expect(SC.get("sensitivity")):toNear(1.5, 1e-6)
			expect(SC.set("sensitivity", "fast")):toBe(false)
			task.wait(0.7)
			expect(SC.stats().patchesSent):toBe(sent0 + 1)
			SC.set("sensitivity", sens0)
			SC.set("palette", pal0)
			task.wait(0.7)
		end)
	end)

	describe("UI-10 production UI swap by keys", function()
		it("a restructured non-wireframe UI with the same keys is adopted and every binding works", function()
			local original = U.root()
			local prod = Wireframe.build()
			prod.Name = UIContract.RootName
			prod:SetAttribute("IsWireframe", false)
			-- change the hierarchy: every top-level child moves under two new wrapper frames with other names
			local layer = Instance.new("Frame")
			layer.Name = "CodexLayer"
			layer.Size = UDim2.fromScale(1, 1)
			layer.BackgroundTransparency = 1
			local inner = layer:Clone()
			inner.Name = "Inner"
			inner.Parent = layer
			for _, c in prod:GetChildren() do
				if c:IsA("GuiObject") then
					c.Name = "Prod_" .. c.Name
					c.Parent = inner
				end
			end
			layer.Parent = prod
			local ok, errors = U.adopt(prod)
			if not ok then
				error(table.concat(errors, "; "))
			end
			expect(U.isWireframe()):toBe(false)
			expect(U.root()):toBe(prod)
			expect(original.Enabled):toBe(false)
			-- bindings by key: open Settings through the staging button handler, close through Settings.Close
			expect(U.activate("Staging.OpenSettings")):toBe(true)
			expect(U.isOpen("Settings")):toBe(true)
			expect(U.get("Settings.Root").Visible):toBe(true)
			expect(U.get("Settings.Root"):IsDescendantOf(prod)):toBe(true)
			local rowsInProd = 0
			for _, d in U.get("Settings.List"):GetChildren() do
				if d:GetAttribute("PrefField") then
					rowsInProd += 1
				end
			end
			expect(rowsInProd):toBe(8)
			expect(U.activate("Settings.Close")):toBe(true)
			expect(U.isOpen("Settings")):toBe(false)
			-- back to the wireframe
			local back = U.adopt(original)
			expect(back):toBe(true)
			expect(U.isWireframe()):toBe(true)
			prod:Destroy()
		end)
	end)
end
