local C = require("./common")
local R = C.R
local N = C.new
return function(gui)
	local found = {}
	local cream = R.Color3.fromRGB(242, 240, 221)
	local mint = R.Color3.fromRGB(147, 239, 197)
	for _, d in gui:GetDescendants() do
		local k = d:GetAttribute("UIKey")
		if k then
			found[k] = d
		end
		if d:IsA("TextButton") then
			d.TextWrapped = true
			d.Font = R.Enum.Font.GothamBold
			N("UIStroke", "StateOutline", d, {
				Color = R.Color3.fromRGB(81, 109, 116),
				Thickness = 1,
				ApplyStrokeMode = R.Enum.ApplyStrokeMode.Border,
			})
		end
		if d:IsA("UICorner") then
			d.CornerRadius = R.UDim.new(0, 4)
		end
		if d:IsA("UITextSizeConstraint") then
			d.MinTextSize = 12
		end
	end
	local function label(parent, name, text, pos, size, max)
		local l = N("TextLabel", name, parent, {
			Text = text,
			Position = pos,
			Size = size,
			BackgroundTransparency = 1,
			TextColor3 = cream,
			Font = R.Enum.Font.GothamBold,
			TextScaled = true,
			TextWrapped = true,
			TextXAlignment = R.Enum.TextXAlignment.Left,
		})
		N("UITextSizeConstraint", "TextBounds", l, { MinTextSize = 12, MaxTextSize = max or 24 })
		return l
	end
	-- Landscape staging uses fixed-height rows; never compress four 48px actions into overlapping scale rows.
	local staging = found["Staging.Root"]
	staging.Size = R.UDim2.new(0.43, 0, 1, -32)
	staging.Position = R.UDim2.fromOffset(16, 16)
	staging.BackgroundTransparency = 0.04
	staging.Title.Text = "COLOR\nCLASH"
	staging.Title.Size = R.UDim2.new(0.9, 0, 0, 62)
	staging.Title.Position = R.UDim2.new(0.05, 0, 0, 10)
	staging.Title.TextXAlignment = R.Enum.TextXAlignment.Left
	found["Staging.Status"].Position = R.UDim2.new(0.05, 0, 0, 78)
	found["Staging.Status"].Size = R.UDim2.new(0.9, 0, 0, 36)
	found["Staging.Kit"].Position = R.UDim2.new(0.05, 0, 0, 116)
	found["Staging.Kit"].Size = R.UDim2.new(0.9, 0, 0, 22)
	for _, key in { "Staging.Ready", "Staging.Unready" } do
		found[key].Position = R.UDim2.new(0.05, 0, 1, -176)
		found[key].Size = R.UDim2.new(0.9, 0, 0, 52)
		found[key].BackgroundColor3 = mint
		found[key].TextColor3 = R.Color3.fromRGB(17, 29, 38)
	end
	for i, key in { "Staging.OpenArmory", "Staging.OpenControls", "Staging.OpenSettings" } do
		found[key].Position = R.UDim2.new(0.05 + (i - 1) * 0.305, 0, 1, -112)
		found[key].Size = R.UDim2.new(0.29, 0, 0, 52)
	end
	label(
		staging,
		"Edition",
		"COLOR CONTROL  /  ALL KITS FREE",
		R.UDim2.new(0.05, 0, 1, -42),
		R.UDim2.new(0.9, 0, 0, 24),
		14
	)
	local onboarding = found["Staging.Onboarding"]
	onboarding.Position = R.UDim2.new(0.51, 0, 0, 20)
	onboarding.Size = R.UDim2.new(0.46, -16, 0, 230)
	found["Staging.OnboardingDismiss"].Size = R.UDim2.new(0.46, 0, 0, 48)
	found["Staging.OnboardingDismiss"].Position = R.UDim2.new(0.5, 0, 1, -56)
	for _, name in { "Armory", "Settings", "Controls", "Map", "Scoreboard", "Results" } do
		local p = found[name .. ".Root"]
		p.Size = R.UDim2.new(0.9, 0, 0.9, 0)
		p.Position = R.UDim2.fromScale(0.05, 0.05)
		p.ZIndex = 10
		N("UIStroke", "PanelEdge", p, { Color = R.Color3.fromRGB(75, 105, 112), Thickness = 1 })
		N("Frame", "AccentRule", p, { Size = R.UDim2.new(1, 0, 0, 3), BorderSizePixel = 0, BackgroundColor3 = mint })
	end
	-- Footer buttons are offset from the bottom rather than growing past the panel at compact sizes.
	for _, key in
		{ "Armory.Equip", "Armory.Close", "Controls.Close", "Settings.Close", "Map.ConfirmLaunch", "Map.Close" }
	do
		local b = found[key]
		b.Position = R.UDim2.new(b.Position.X.Scale, b.Position.X.Offset, 1, -58)
		b.Size = R.UDim2.new(b.Size.X.Scale, 0, 0, 48)
	end
	found["Settings.List"].Size = R.UDim2.new(0.94, 0, 1, -124)
	found["Settings.Status"].Position = R.UDim2.new(0.03, 0, 1, -56)
	found["Settings.Status"].Size = R.UDim2.new(0.7, 0, 0, 44)
	found["Armory.KitList"].Size = R.UDim2.new(0.36, 0, 1, -70)
	found["Armory.Detail"].Size = R.UDim2.new(0.57, 0, 1, -135)
	found["Armory.Status"].Position = R.UDim2.new(0.4, 0, 1, -88)
	found["HUD.Gadget"].Position = R.UDim2.new(0, 16, 1, -134)
	found["HUD.Gadget"].Size = R.UDim2.fromOffset(110, 40)
	found["HUD.Ultimate"].Position = R.UDim2.new(0, 134, 1, -134)
	found["HUD.Ultimate"].Size = R.UDim2.fromOffset(110, 40)
	found["HUD.Kit"].Position = R.UDim2.new(0, 16, 1, -164)
	found["HUD.Kit"].Size = R.UDim2.fromOffset(228, 26)
	label(
		found["HUD.Root"],
		"InputLegend",
		"Q GADGET  /  E ULT  /  M MAP",
		R.UDim2.new(0, 16, 1, -92),
		R.UDim2.fromOffset(228, 18),
		12
	)
	found["HUD.Paint"].Size = R.UDim2.new(0.24, 0, 0, 22)
	found["HUD.Paint"].Position = R.UDim2.new(0.34, 0, 1, -60)
	found["HUD.Health"].Size = R.UDim2.new(0.24, 0, 0, 18)
	found["HUD.Health"].Position = R.UDim2.new(0.34, 0, 1, -32)
	for _, key in { "HUD.PaintFill", "HUD.HealthFill", "HUD.UltimateFill" } do
		found[key].BackgroundTransparency = 0.25
	end
	-- A crisp four-tick reticle leaves the target visible.
	local ret = found["HUD.Reticle"]
	ret.BackgroundTransparency = 1
	ret.Size = R.UDim2.fromOffset(24, 24)
	ret.Position = R.UDim2.new(0.5, -12, 0.5, -12)
	for _, v in { { 0, 10, 6, 3 }, { 18, 10, 6, 3 }, { 10, 0, 3, 6 }, { 10, 18, 3, 6 } } do
		N("Frame", "Tick", ret, {
			Position = R.UDim2.fromScale(v[1] / 24, v[2] / 24),
			Size = R.UDim2.fromScale(v[3] / 24, v[4] / 24),
			BackgroundColor3 = cream,
			BorderSizePixel = 0,
		})
	end
	-- Original UI silhouettes drawn from native rectangles; no external image permission dependency.
	local library = N("Folder", "Icons", gui)
	local silhouettes = {
		sprayline = { { 8, 13, 33, 12 }, { 20, 25, 7, 14 }, { 40, 16, 13, 5 } },
		twin_jets = { { 5, 8, 24, 9 }, { 12, 17, 5, 12 }, { 29, 30, 24, 9 }, { 37, 39, 5, 12 } },
		lane_roller = { { 6, 7, 46, 16 }, { 28, 23, 5, 29 } },
		linecaster = { { 5, 19, 22, 10 }, { 27, 22, 31, 4 }, { 17, 29, 6, 15 }, { 17, 12, 13, 5 } },
		splash_pot = { { 12, 17, 34, 25 }, { 7, 12, 44, 6 }, { 8, 4, 6, 13 }, { 43, 4, 6, 13 } },
		street_sweeper = {
			{ 27, 5, 5, 32 },
			{ 9, 36, 42, 7 },
			{ 12, 43, 5, 11 },
			{ 23, 43, 5, 11 },
			{ 34, 43, 5, 11 },
			{
				45,
				43,
				5,
				11,
			},
		},
		popshot = { { 10, 13, 37, 22 }, { 47, 10, 7, 28 }, { 22, 35, 7, 14 } },
		splash_can = { { 18, 16, 25, 34 }, { 15, 10, 31, 7 }, { 27, 3, 8, 7 } },
		paint_screen = { { 5, 8, 50, 36 }, { 9, 47, 6, 7 }, { 45, 47, 6, 7 } },
		color_burst = { { 17, 17, 27, 27 }, { 26, 3, 8, 9 }, { 26, 49, 8, 9 }, { 3, 26, 9, 8 }, { 49, 26, 9, 8 } },
		paintstorm = { { 10, 12, 40, 15 }, { 16, 33, 4, 15 }, { 28, 30, 4, 15 }, { 40, 33, 4, 15 } },
	}
	for id, rects in silhouettes do
		local icon =
			N("Frame", id, library, { Size = R.UDim2.fromOffset(60, 60), BackgroundTransparency = 1, Visible = false })
		for _, v in rects do
			N("Frame", "Stroke", icon, {
				Size = R.UDim2.fromScale(v[3] / 60, v[4] / 60),
				Position = R.UDim2.fromScale(v[1] / 60, v[2] / 60),
				BackgroundColor3 = cream,
				BorderSizePixel = 0,
			})
		end
	end
	local glyphs = N("Folder", "InputGlyphs", gui)
	for _, key in
		{ "LMB", "RMB", "SHIFT", "SPACE", "Q", "E", "M", "TAB", "RT", "LT", "RB", "LB", "A", "B", "X", "Y", "TOUCH" }
	do
		label(glyphs, key, key, R.UDim2.new(), R.UDim2.fromOffset(48, 48), 18).Visible = false
	end
	return gui
end
