-- Presentation only: style code-owned attributes, adopt the exported GUI after StarterGui replication,
-- and mount a local cosmetic harness. Never writes gameplay state or changes attack timing.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local gui = script.Parent
local Prefs = require(RS:WaitForChild("Shared").Settings.Prefs)
local assets = RS:WaitForChild("ColorClashAssets", 10)
local connections = {}
local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(connections, c)
	return c
end
local function tint(team)
	local pal = Prefs.Palettes[player:GetAttribute("CCPalette") or "standard"] or Prefs.Palettes.standard
	return Color3.fromRGB(table.unpack(pal[team] or { 230, 233, 218 }))
end
local styled = setmetatable({}, { __mode = "k" })
local function style(b)
	if not b:IsA("TextButton") or styled[b] then
		return
	end
	styled[b] = true
	local localConnections = {}
	local function bind(signal, fn)
		table.insert(localConnections, signal:Connect(fn))
	end
	local base = b.BackgroundColor3
	local over = false
	local outline = b:FindFirstChild("StateOutline")
	local function update()
		local disabled = b:GetAttribute("Disabled") or b:GetAttribute("Pending")
		local selected = GuiService.SelectedObject == b
		local color = if b:GetAttribute("Error")
			then Color3.fromRGB(153, 61, 70)
			elseif disabled then Color3.fromRGB(55, 62, 66)
			elseif b:GetAttribute("Pressed") then Color3.fromRGB(71, 139, 125)
			elseif over or selected then Color3.fromRGB(66, 111, 113)
			else base
		TweenService:Create(b, TweenInfo.new(0.09), { BackgroundColor3 = color }):Play()
		if outline then
			outline.Thickness = if selected then 3 else 1
		end
	end
	bind(b.MouseEnter, function()
		over = true
		update()
	end)
	bind(b.MouseLeave, function()
		over = false
		update()
	end)
	bind(b.SelectionGained, update)
	bind(b.SelectionLost, update)
	for _, a in { "Disabled", "Pending", "Pressed", "Error" } do
		bind(b:GetAttributeChangedSignal(a), update)
	end
	bind(b.Destroying, function()
		for _, c in localConnections do
			c:Disconnect()
		end
		table.clear(localConnections)
	end)
	update()
end
local function decorateCard(b)
	if not b:IsA("TextButton") then
		return
	end
	local id = b:GetAttribute("KitId") or b:GetAttribute("WeaponId")
	if not id then
		local names = {
			Sprayline = "sprayline",
			["Twin Jets"] = "twin_jets",
			["Lane Roller"] = "lane_roller",
			Linecaster = "linecaster",
			["Splash Pot"] = "splash_pot",
			["Street Sweeper"] = "street_sweeper",
			Popshot = "popshot",
		}
		for name, key in names do
			if string.find(b.Text, name, 1, true) then
				id = key
				break
			end
		end
	end
	local template = id and gui.Icons:FindFirstChild(id)
	if template and not b:FindFirstChild("KitIcon") then
		local icon = template:Clone()
		icon.Name = "KitIcon"
		icon.Visible = true
		icon.Size = UDim2.fromOffset(38, 38)
		icon.Position = UDim2.new(0, 4, 0.5, -19)
		icon.Parent = b
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 46)
		pad.Parent = b
	end
end
for _, d in gui:GetDescendants() do
	style(d)
	decorateCard(d)
end
connect(gui.DescendantAdded, function(d)
	style(d)
	if d:IsA("TextButton") then
		task.defer(decorateCard, d)
	end
end)
local gears = {}
local function recolor()
	for char, gear in gears do
		if gear.Parent then
			local team = char:GetAttribute("CCTeam")
			for _, p in gear:GetDescendants() do
				if p:IsA("BasePart") and p:GetAttribute("TeamTint") then
					p.Color = tint(team)
				end
			end
			local h = gear:FindFirstChild("TeamOutline")
			if h then
				h.OutlineColor = tint(team)
			end
			local mark = gear:FindFirstChild("TeamMarker", true)
			if mark then
				mark.Text = if team == 1 then "A / ▲" elseif team == 2 then "B / ■" else ""
			end
		end
	end
end
local function character(char)
	local torso = char:WaitForChild("UpperTorso", 10)
	if not torso or not assets or not gui.Parent or char:FindFirstChild("CCAthleteGear") then
		return
	end
	local template = assets.Character:FindFirstChild("AthleteGear")
	if not template then
		return
	end
	local gear = template:Clone()
	gear.Name = "CCAthleteGear"
	gear:PivotTo(torso.CFrame * CFrame.new(0, 0, 0.85))
	local w = Instance.new("WeldConstraint")
	w.Part0 = torso
	w.Part1 = gear.PrimaryPart
	w.Parent = gear.PrimaryPart
	gear.Parent = char
	gears[char] = gear
	local h = Instance.new("Highlight")
	h.Name = "TeamOutline"
	h.Adornee = char
	h.FillTransparency = 1
	h.OutlineTransparency = 0.55
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = gear
	local badge = Instance.new("BillboardGui")
	badge.Name = "Badge"
	badge.Adornee = torso
	badge.Size = UDim2.fromOffset(46, 22)
	badge.StudsOffset = Vector3.new(0, 3.2, 0)
	badge.MaxDistance = 90
	badge.AlwaysOnTop = false
	badge.Parent = gear
	local text = Instance.new("TextLabel")
	text.Name = "TeamMarker"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.2
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.Parent = badge
	connect(char:GetAttributeChangedSignal("CCTeam"), recolor)
	connect(char.AncestryChanged, function(_, parent)
		if not parent then
			gears[char] = nil
		end
	end)
	recolor()
end
local function watch(p)
	connect(p.CharacterAdded, character)
	if p.Character then
		task.spawn(character, p.Character)
	end
end
for _, p in Players:GetPlayers() do
	watch(p)
end
connect(Players.PlayerAdded, watch)
connect(player:GetAttributeChangedSignal("CCPalette"), recolor)
local screens = setmetatable({}, { __mode = "k" })
local function screen(p)
	if not p:IsA("BasePart") or not p:GetAttribute("CCScreenId") or screens[p] then
		return
	end
	screens[p] = true
	local template = assets and assets.Effects:FindFirstChild("PaintScreen")
	if not template then
		return
	end
	local frame = template:Clone()
	frame.Name = "CCScreenTrim"
	frame.Body.Transparency = 1
	frame:PivotTo(p.CFrame)
	frame.Parent = p
	local function update()
		p.Color = tint(p:GetAttribute("CCTeam"))
		for _, part in frame:GetDescendants() do
			if part:IsA("BasePart") then
				part.Color = p.Color
			end
		end
		local health = p:GetAttribute("Health") or 250
		for _, part in frame:GetChildren() do
			if part:IsA("BasePart") and part.Name ~= "Body" then
				part.Transparency = if health < 80 then 0.4 else 0
			end
		end
	end
	local paletteConnection = player:GetAttributeChangedSignal("CCPalette"):Connect(update)
	local healthConnection = p:GetAttributeChangedSignal("Health"):Connect(update)
	p.Destroying:Once(function()
		paletteConnection:Disconnect()
		healthConnection:Disconnect()
	end)
	update()
end
for _, p in workspace:GetDescendants() do
	screen(p)
end
connect(workspace.DescendantAdded, screen)
for _, d in gui:GetDescendants() do
	if d:GetAttribute("UIKey") == "HUD.Reticle" then
		connect(d:GetAttributeChangedSignal("HitConfirmed"), function()
			for _, tick in d:GetChildren() do
				if tick:IsA("Frame") then
					tick.BackgroundColor3 = if d:GetAttribute("HitConfirmed")
						then d.BackgroundColor3
						else Color3.fromRGB(242, 240, 221)
				end
			end
		end)
	end
end
local Weapons = require(RS.Shared.Config.Weapons)
local UIS = game:GetService("UserInputService")
local function iconOn(parent, id)
	local old = parent:FindFirstChild("LiveIcon")
	if old then
		old:Destroy()
	end
	local source = gui.Icons:FindFirstChild(id)
	if source then
		local icon = source:Clone()
		icon.Name = "LiveIcon"
		icon.Visible = true
		icon.Size = UDim2.fromOffset(20, 20)
		icon.Position = UDim2.new(0, 0, 0.5, -10)
		icon.Parent = parent
		if not parent:FindFirstChild("IconPadding") then
			local padding = Instance.new("UIPadding")
			padding.Name = "IconPadding"
			padding.PaddingLeft = UDim.new(0, 24)
			padding.Parent = parent
		end
	end
end
local function refreshKit()
	local kit = Weapons.Defs[player:GetAttribute("CCWeapon") or "sprayline"]
	if not kit then
		return
	end
	for _, d in gui:GetDescendants() do
		local key = d:GetAttribute("UIKey")
		if key == "HUD.Gadget" then
			iconOn(d, kit.Gadget)
		elseif key == "HUD.Ultimate" then
			iconOn(d, kit.Ultimate)
		end
	end
end
connect(player:GetAttributeChangedSignal("CCWeapon"), refreshKit)
refreshKit()
local function inputHints()
	local gamepad = string.find(UIS:GetLastInputType().Name, "Gamepad") ~= nil
	local touch = UIS:GetLastInputType() == Enum.UserInputType.Touch
	local hints = {
		Primary = if gamepad then "RT" else "LMB",
		Secondary = if gamepad then "LT" else "RMB",
		Glide = if gamepad then "RB" else "SHIFT",
		Jump = if gamepad then "A" else "SPACE",
		Gadget = if gamepad then "LB" else "Q",
		Ultimate = if gamepad then "X" else "E",
		Map = if gamepad then "Y" else "M",
	}
	gui:SetAttribute("InputGlyphSet", if touch then "touch" elseif gamepad then "gamepad" else "keyboard")
	local legend = gui:FindFirstChild("InputLegend", true)
	if legend then
		legend.Visible = not touch
		legend.Text = if gamepad then "LB GADGET  /  X ULT  /  Y MAP" else "Q GADGET  /  E ULT  /  M MAP"
	end
	for _, d in gui:GetDescendants() do
		local key = d:GetAttribute("UIKey")
		if type(key) == "string" and string.sub(key, 1, 6) == "Touch." and d:IsA("TextButton") then
			d:SetAttribute("InputGlyph", hints[string.sub(key, 7)])
		end
	end
end
connect(UIS.LastInputTypeChanged, inputHints)
inputHints()
-- UIController.start can run before StarterGui is copied. Its public adopt hook rebinds all existing handlers.
task.spawn(function()
	local scripts = player:WaitForChild("PlayerScripts"):WaitForChild("Client", 10)
	if not scripts then
		return
	end
	local UI = require(scripts.Controllers.UIController)
	local deadline = os.clock() + 15
	while not UI.root() and os.clock() < deadline do
		task.wait()
	end
	if UI.root() and UI.root() ~= gui and gui.Parent then
		local old = UI.root()
		local ok = UI.adopt(gui)
		if ok and old:GetAttribute("IsWireframe") == true then
			old:Destroy()
		end
	end
end)
connect(gui.Destroying, function()
	for _, c in connections do
		c:Disconnect()
	end
	for _, gear in gears do
		gear:Destroy()
	end
end)
