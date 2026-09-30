-- DEVELOPMENT WIREFRAME (GDD 12.3): a plain, functional UI generated from the same UIKey contract that Codex's
-- production UI will satisfy. It is watermarked and flagged IsWireframe = true; screenshots of it can never pass
-- final visual acceptance. Layout uses scale sizes plus pixel constraints so it works from 740x360 up to 1080p,
-- with touch targets of at least 48 px (GDD 04.4, 12.4).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local UIContract = require(Shared.UI.UIContract)
local Strings = require(Shared.UI.Strings)

local Wireframe = {}

local BG = Color3.fromRGB(24, 26, 32)
local PANEL = Color3.fromRGB(38, 42, 52)
local BUTTON = Color3.fromRGB(70, 78, 96)
local TEXT = Color3.fromRGB(240, 240, 245)
local FONT = Enum.Font.GothamMedium

local function key(inst: Instance, k: string)
	inst:SetAttribute("UIKey", k)
	return inst
end

local function frame(parent: Instance, name: string, size: UDim2, pos: UDim2, color: Color3?, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color or PANEL
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function label(parent: Instance, name: string, text: string, size: UDim2, pos: UDim2, maxText: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.Text = text
	l.TextColor3 = TEXT
	l.TextScaled = true
	l.TextWrapped = true
	l.Parent = parent
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxText or 28
	c.MinTextSize = 10
	c.Parent = l
	return l
end

local function button(parent: Instance, name: string, text: string, size: UDim2, pos: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = BUTTON
	b.BorderSizePixel = 0
	b.Font = FONT
	b.Text = text
	b.TextColor3 = TEXT
	b.TextScaled = true
	b.AutoButtonColor = true
	b.Selectable = true
	b.Parent = parent
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = 24
	c.MinTextSize = 10
	c.Parent = b
	local s = Instance.new("UISizeConstraint")
	s.MinSize = Vector2.new(48, 48) -- essential touch target minimum (GDD 04.4)
	s.Parent = b
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = b
	return b
end

local function scroll(parent: Instance, name: string, size: UDim2, pos: UDim2): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.Name = name
	s.Size = size
	s.Position = pos
	s.BackgroundColor3 = BG
	s.BackgroundTransparency = 0.2
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 8
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.Selectable = false
	s.Parent = parent
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = s
	return s
end

local function panel(parent: Instance, name: string, uiKey: string, size: UDim2): Frame
	local p = frame(parent, name, size, UDim2.fromScale((1 - size.X.Scale) / 2, (1 - size.Y.Scale) / 2), PANEL)
	key(p, uiKey)
	p.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = p
	return p
end

local function meter(parent: Instance, name: string, uiKey: string, fillKey: string, textKey: string, size: UDim2, pos: UDim2, color: Color3): Frame
	local m = key(frame(parent, name, size, pos, BG), uiKey) :: Frame
	local fill = key(frame(m, "Fill", UDim2.fromScale(1, 1), UDim2.new(), color), fillKey)
	fill.ZIndex = 2
	local t = key(label(m, "Text", "", UDim2.fromScale(1, 1), UDim2.new(), 20), textKey)
	t.ZIndex = 3
	return m
end

function Wireframe.build(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = UIContract.RootName
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets -- respect safe areas / cutouts (GDD 04.4)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui:SetAttribute("ContractVersion", UIContract.ContractVersion)
	gui:SetAttribute("IsWireframe", true)

	local watermark = label(gui, "WireframeWatermark", "WIREFRAME — DEVELOPMENT ONLY", UDim2.new(0.4, 0, 0, 18), UDim2.new(0.3, 0, 1, -18), 14)
	watermark.TextTransparency = 0.4
	watermark.ZIndex = 50

	-- Loading
	local loading = key(frame(gui, "Loading", UDim2.fromScale(1, 1), UDim2.new(), BG), "Loading.Root") :: Frame
	loading.ZIndex = 40
	loading.Visible = false
	key(label(loading, "Stage", "", UDim2.fromScale(0.6, 0.08), UDim2.fromScale(0.2, 0.4), 36), "Loading.Stage")
	key(label(loading, "Detail", "", UDim2.fromScale(0.6, 0.06), UDim2.fromScale(0.2, 0.5), 20), "Loading.Detail")
	key(button(loading, "Retry", Strings.Retry, UDim2.fromScale(0.14, 0.08), UDim2.fromScale(0.34, 0.6)), "Loading.Retry").Visible = false
	key(button(loading, "Back", Strings.Back, UDim2.fromScale(0.14, 0.08), UDim2.fromScale(0.52, 0.6)), "Loading.Back").Visible = false

	-- Staging
	local staging = key(frame(gui, "Staging", UDim2.fromScale(0.3, 0.72), UDim2.fromScale(0.02, 0.14), PANEL, 0.1), "Staging.Root") :: Frame
	label(staging, "Title", Strings.Title, UDim2.fromScale(0.9, 0.1), UDim2.fromScale(0.05, 0.02), 32)
	key(label(staging, "Status", "", UDim2.fromScale(0.9, 0.1), UDim2.fromScale(0.05, 0.13), 18), "Staging.Status")
	key(label(staging, "Kit", "", UDim2.fromScale(0.9, 0.07), UDim2.fromScale(0.05, 0.24), 18), "Staging.Kit")
	key(button(staging, "Ready", Strings.Play, UDim2.fromScale(0.9, 0.11), UDim2.fromScale(0.05, 0.33)), "Staging.Ready")
	key(button(staging, "Unready", Strings.Unready, UDim2.fromScale(0.9, 0.11), UDim2.fromScale(0.05, 0.33)), "Staging.Unready").Visible = false
	key(button(staging, "Armory", Strings.Armory, UDim2.fromScale(0.9, 0.1), UDim2.fromScale(0.05, 0.47)), "Staging.OpenArmory")
	key(button(staging, "Controls", Strings.Controls, UDim2.fromScale(0.9, 0.1), UDim2.fromScale(0.05, 0.59)), "Staging.OpenControls")
	key(button(staging, "Settings", Strings.Settings, UDim2.fromScale(0.9, 0.1), UDim2.fromScale(0.05, 0.71)), "Staging.OpenSettings")
	local onboarding = key(frame(gui, "Onboarding", UDim2.fromScale(0.34, 0.26), UDim2.fromScale(0.64, 0.14), PANEL, 0.1), "Staging.Onboarding")
	for i, line in Strings.OnboardingLines do
		label(onboarding, "Line" .. i, i .. ". " .. line, UDim2.fromScale(0.92, 0.2), UDim2.fromScale(0.04, 0.04 + (i - 1) * 0.22), 22)
	end
	key(button(onboarding, "Dismiss", Strings.Dismiss, UDim2.fromScale(0.3, 0.2), UDim2.fromScale(0.66, 0.74)), "Staging.OnboardingDismiss")

	-- Armory
	local armory = panel(gui, "Armory", "Armory.Root", UDim2.fromScale(0.7, 0.78))
	label(armory, "Title", Strings.Armory, UDim2.fromScale(0.5, 0.08), UDim2.fromScale(0.02, 0.02), 30)
	local kitList = key(scroll(armory, "KitList", UDim2.fromScale(0.36, 0.76), UDim2.fromScale(0.02, 0.12)), "Armory.KitList")
	local kitTpl = key(button(kitList, "KitTemplate", "", UDim2.new(1, -10, 0, 56), UDim2.new()), "Armory.KitTemplate")
	kitTpl.Visible = false
	key(label(armory, "Detail", "", UDim2.fromScale(0.58, 0.62), UDim2.fromScale(0.4, 0.12), 18), "Armory.Detail").TextXAlignment = Enum.TextXAlignment.Left
	key(label(armory, "Status", "", UDim2.fromScale(0.58, 0.06), UDim2.fromScale(0.4, 0.76), 18), "Armory.Status")
	key(button(armory, "Equip", Strings.Equip, UDim2.fromScale(0.2, 0.1), UDim2.fromScale(0.56, 0.86)), "Armory.Equip")
	key(button(armory, "Close", Strings.Close, UDim2.fromScale(0.16, 0.1), UDim2.fromScale(0.8, 0.86)), "Armory.Close")

	-- Controls
	local controls = panel(gui, "Controls", "Controls.Root", UDim2.fromScale(0.6, 0.7))
	key(label(controls, "Text", "", UDim2.fromScale(0.92, 0.72), UDim2.fromScale(0.04, 0.04), 20), "Controls.Text").TextXAlignment = Enum.TextXAlignment.Left
	key(button(controls, "Close", Strings.Close, UDim2.fromScale(0.2, 0.12), UDim2.fromScale(0.76, 0.84)), "Controls.Close")

	-- Settings
	local settings = panel(gui, "Settings", "Settings.Root", UDim2.fromScale(0.6, 0.78))
	label(settings, "Title", Strings.Settings, UDim2.fromScale(0.5, 0.08), UDim2.fromScale(0.02, 0.02), 30)
	local settingsList = key(scroll(settings, "List", UDim2.fromScale(0.94, 0.72), UDim2.fromScale(0.03, 0.12)), "Settings.List")
	local row = key(frame(settingsList, "RowTemplate", UDim2.new(1, -10, 0, 52), UDim2.new(), BG), "Settings.RowTemplate")
	row.Visible = false
	label(row, "Name", "", UDim2.fromScale(0.5, 1), UDim2.new(), 20).TextXAlignment = Enum.TextXAlignment.Left
	button(row, "Value", "", UDim2.fromScale(0.44, 0.9), UDim2.fromScale(0.54, 0.05))
	key(label(settings, "Status", "", UDim2.fromScale(0.7, 0.08), UDim2.fromScale(0.03, 0.88), 16), "Settings.Status").TextXAlignment = Enum.TextXAlignment.Left
	key(button(settings, "Close", Strings.Close, UDim2.fromScale(0.2, 0.1), UDim2.fromScale(0.77, 0.87)), "Settings.Close")

	-- HUD
	local hud = key(frame(gui, "HUD", UDim2.fromScale(1, 1), UDim2.new(), BG, 1), "HUD.Root") :: Frame
	hud.Visible = false
	key(label(hud, "Timer", "4:00", UDim2.fromScale(0.12, 0.06), UDim2.fromScale(0.44, 0.01), 30), "HUD.Timer")
	local bar = frame(hud, "Coverage", UDim2.fromScale(0.36, 0.022), UDim2.fromScale(0.32, 0.075), BG)
	key(frame(bar, "A", UDim2.fromScale(0, 1), UDim2.new(), Color3.fromRGB(255, 140, 0)), "HUD.CoverageA")
	key(frame(bar, "Neutral", UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(90, 90, 90)), "HUD.Neutral")
	key(frame(bar, "B", UDim2.fromScale(0, 1), UDim2.fromScale(1, 0), Color3.fromRGB(0, 170, 255)), "HUD.CoverageB")
	key(label(hud, "CoverageText", "", UDim2.fromScale(0.36, 0.035), UDim2.fromScale(0.32, 0.1), 16), "HUD.CoverageText")
	local reticle = key(frame(hud, "Reticle", UDim2.fromOffset(12, 12), UDim2.new(0.5, -6, 0.5, -6), TEXT), "HUD.Reticle") :: Frame
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(1, 0)
	rc.Parent = reticle
	key(label(hud, "ReticleState", "", UDim2.fromScale(0.2, 0.04), UDim2.fromScale(0.4, 0.53), 18), "HUD.ReticleState")
	key(label(hud, "Callout", "", UDim2.fromScale(0.4, 0.05), UDim2.fromScale(0.3, 0.36), 24), "HUD.Callout")
	key(label(hud, "Shield", "", UDim2.fromScale(0.2, 0.04), UDim2.fromScale(0.4, 0.3), 18), "HUD.Shield")
	meter(hud, "Paint", "HUD.Paint", "HUD.PaintFill", "HUD.PaintText", UDim2.fromScale(0.22, 0.035), UDim2.fromScale(0.39, 0.88), Color3.fromRGB(255, 140, 0))
	meter(hud, "Health", "HUD.Health", "HUD.HealthFill", "HUD.HealthText", UDim2.fromScale(0.22, 0.03), UDim2.fromScale(0.39, 0.93), Color3.fromRGB(90, 220, 110))
	key(label(hud, "Kit", "", UDim2.fromScale(0.2, 0.035), UDim2.fromScale(0.78, 0.74), 18), "HUD.Kit")
	local gadget = key(frame(hud, "Gadget", UDim2.fromScale(0.09, 0.07), UDim2.fromScale(0.78, 0.79), BG, 0.2), "HUD.Gadget")
	key(label(gadget, "Text", "", UDim2.fromScale(1, 1), UDim2.new(), 16), "HUD.GadgetText")
	meter(hud, "Ultimate", "HUD.Ultimate", "HUD.UltimateFill", "HUD.UltimateText", UDim2.fromScale(0.1, 0.07), UDim2.fromScale(0.88, 0.79), Color3.fromRGB(255, 220, 60))

	-- Touch controls (only shown on touch devices; landscape, above/beside readouts)
	local touch = frame(gui, "Touch", UDim2.fromScale(1, 1), UDim2.new(), BG, 1)
	touch.Name = "TouchControls"
	touch.Visible = false
	local function tbtn(name, uiKey, text, px, pos)
		local b = key(button(touch, name, text, UDim2.fromOffset(px, px), pos), uiKey)
		b.BackgroundTransparency = 0.25
		return b
	end
	-- right-thumb cluster, no overlaps down to 740x360 (UI-05): Fire above Jump, Secondary/Glide left of Fire,
	-- Gadget/Ultimate above Fire
	tbtn("Primary", "Touch.Primary", "FIRE", 88, UDim2.new(1, -120, 1, -160))
	tbtn("Jump", "Touch.Jump", "JUMP", 64, UDim2.new(1, -110, 1, -68))
	tbtn("Secondary", "Touch.Secondary", "ALT", 60, UDim2.new(1, -205, 1, -120))
	tbtn("Glide", "Touch.Glide", "GLIDE", 60, UDim2.new(1, -205, 1, -200))
	tbtn("Gadget", "Touch.Gadget", "GADGET", 56, UDim2.new(1, -124, 1, -240))
	tbtn("Ultimate", "Touch.Ultimate", "ULT", 56, UDim2.new(1, -60, 1, -240))
	tbtn("Map", "Touch.Map", "MAP", 48, UDim2.new(1, -60, 0, 70))

	-- Tactical map
	local mapRoot = panel(gui, "Map", "Map.Root", UDim2.fromScale(0.8, 0.84))
	key(frame(mapRoot, "Image", UDim2.fromScale(0.62, 0.9), UDim2.fromScale(0.02, 0.05), BG), "Map.Image")
	local targets = key(scroll(mapRoot, "Targets", UDim2.fromScale(0.32, 0.56), UDim2.fromScale(0.66, 0.05)), "Map.TargetList")
	local ttpl = key(button(targets, "TargetTemplate", "", UDim2.new(1, -10, 0, 52), UDim2.new()), "Map.TargetTemplate")
	ttpl.Visible = false
	key(label(mapRoot, "Status", "", UDim2.fromScale(0.32, 0.1), UDim2.fromScale(0.66, 0.63), 16), "Map.Status")
	key(button(mapRoot, "Confirm", "Launch", UDim2.fromScale(0.15, 0.1), UDim2.fromScale(0.66, 0.82)), "Map.ConfirmLaunch")
	key(button(mapRoot, "Close", Strings.Close, UDim2.fromScale(0.15, 0.1), UDim2.fromScale(0.83, 0.82)), "Map.Close")

	-- Scoreboard
	local board = panel(gui, "Scoreboard", "Scoreboard.Root", UDim2.fromScale(0.8, 0.7))
	key(scroll(board, "TeamA", UDim2.fromScale(0.47, 0.86), UDim2.fromScale(0.02, 0.1)), "Scoreboard.TeamA")
	key(scroll(board, "TeamB", UDim2.fromScale(0.47, 0.86), UDim2.fromScale(0.51, 0.1)), "Scoreboard.TeamB")
	key(label(board, "Header", "Paint contribution · Eliminations · Assists · Deaths", UDim2.fromScale(0.96, 0.07), UDim2.fromScale(0.02, 0.015), 18), "Scoreboard.Header")
	local srow = key(label(board, "RowTemplate", "", UDim2.new(1, -10, 0, 40), UDim2.new(), 18), "Scoreboard.RowTemplate")
	srow.Visible = false

	-- Elimination
	local elim = key(frame(gui, "Elimination", UDim2.fromScale(0.4, 0.18), UDim2.fromScale(0.3, 0.22), PANEL, 0.2), "Elimination.Root")
	elim.Visible = false
	key(label(elim, "Attacker", "", UDim2.fromScale(0.94, 0.45), UDim2.fromScale(0.03, 0.05), 24), "Elimination.Attacker")
	key(label(elim, "Countdown", "", UDim2.fromScale(0.94, 0.4), UDim2.fromScale(0.03, 0.55), 30), "Elimination.Countdown")

	-- Results
	local results = panel(gui, "Results", "Results.Root", UDim2.fromScale(0.8, 0.84))
	key(label(results, "Outcome", "", UDim2.fromScale(0.9, 0.1), UDim2.fromScale(0.05, 0.03), 40), "Results.Outcome")
	local rbar = key(frame(results, "Coverage", UDim2.fromScale(0.9, 0.05), UDim2.fromScale(0.05, 0.15), BG), "Results.Coverage")
	frame(rbar, "A", UDim2.fromScale(0, 1), UDim2.new(), Color3.fromRGB(255, 140, 0))
	frame(rbar, "B", UDim2.fromScale(0, 1), UDim2.fromScale(1, 0), Color3.fromRGB(0, 170, 255))
	key(label(results, "CoverageText", "", UDim2.fromScale(0.9, 0.06), UDim2.fromScale(0.05, 0.21), 22), "Results.CoverageText")
	local stats = key(scroll(results, "Stats", UDim2.fromScale(0.9, 0.62), UDim2.fromScale(0.05, 0.3)), "Results.Stats")
	local strow = key(label(stats, "StatRowTemplate", "", UDim2.new(1, -10, 0, 36), UDim2.new(), 18), "Results.StatRowTemplate")
	strow.Visible = false

	-- Intro
	local intro = key(frame(gui, "Intro", UDim2.fromScale(0.5, 0.2), UDim2.fromScale(0.25, 0.2), PANEL, 0.3), "Intro.Root")
	intro.Visible = false
	key(label(intro, "Title", "", UDim2.fromScale(0.94, 0.5), UDim2.fromScale(0.03, 0.05), 32), "Intro.Title")
	key(label(intro, "Count", "", UDim2.fromScale(0.94, 0.4), UDim2.fromScale(0.03, 0.55), 40), "Intro.Count")

	-- Notices
	local notices = key(frame(gui, "Notices", UDim2.fromScale(0.4, 0.2), UDim2.fromScale(0.3, 0.12), BG, 1), "Notices.Root")
	local nl = Instance.new("UIListLayout")
	nl.Padding = UDim.new(0, 4)
	nl.Parent = notices
	local ntpl = key(label(notices, "Template", "", UDim2.new(1, 0, 0, 30), UDim2.new(), 20), "Notices.Template")
	ntpl.BackgroundTransparency = 0.3
	ntpl.BackgroundColor3 = BG
	ntpl.Visible = false

	return gui
end

return Wireframe
