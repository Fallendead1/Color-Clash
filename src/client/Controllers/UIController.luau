-- UI adapter (GDD 12.3, 12.4). Binds screens through UIKey attributes so Codex's production UI can replace the
-- development wireframe without code changes (UI-10). Owns the panel stack and its input contexts.
--
-- Root selection: a PlayerGui ScreenGui "ColorClashUI" that is not flagged IsWireframe and passes contract validation
-- is used as production UI. Otherwise the wireframe is generated (and a diagnostic explains why).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local UIContract = require(Shared.UI.UIContract)

local Wireframe = require(script.Parent.Parent.UI.Wireframe)

local UIController = {}

local player = Players.LocalPlayer
local root: ScreenGui? = nil
local keys: { [string]: Instance } = {}
local isWireframe = true
local validationErrors: { string } = {}
local panelStack: { string } = {}
local input = nil
local pending: { [string]: boolean } = {}
local panelListeners: { (string?, string?) -> () } = {}
local handlers: { [string]: () -> () } = {} -- key -> guarded handler (survives a UI swap)
local connections: { [string]: RBXScriptConnection } = {}
local adoptListeners: { () -> () } = {}

local PANELS = {
	Armory = "Armory.Root",
	Controls = "Controls.Root",
	Settings = "Settings.Root",
	Map = "Map.Root",
	Scoreboard = "Scoreboard.Root",
}

function UIController.start(inputController)
	input = inputController
	local pg = player:WaitForChild("PlayerGui")
	local candidate = pg:FindFirstChild(UIContract.RootName)
	if candidate and candidate:IsA("ScreenGui") and candidate:GetAttribute("IsWireframe") ~= true then
		local found, errors = UIContract.validate(candidate)
		if #errors == 0 then
			root = candidate
			keys = found
			isWireframe = false
		else
			validationErrors = errors
			warn("[ColorClash] production UI failed contract validation; using wireframe. First error: " .. errors[1])
			candidate.Enabled = false
		end
	end
	if not root then
		local gui = Wireframe.build()
		local found, errors = UIContract.validate(gui)
		if #errors > 0 then
			warn("[ColorClash] wireframe failed its own contract: " .. errors[1])
			validationErrors = errors
		end
		gui.Parent = pg
		root = gui
		keys = found
		isWireframe = true
	end
	player:SetAttribute("CCUIWireframe", isWireframe)
	player:SetAttribute("CCUIErrors", #validationErrors)
	-- Cancel / gamepad B closes the top panel (every screen escapable without a mouse; GDD 12.4, UI-04)
	inputController.onAction(function(action: string, down: boolean)
		if action == "Cancel" and down and #panelStack > 0 then
			UIController.closePanel()
		end
	end)
end

function UIController.get(key: string): any
	return keys[key]
end

function UIController.root(): ScreenGui?
	return root
end

function UIController.isWireframe(): boolean
	return isWireframe
end

function UIController.errors(): { string }
	return validationErrors
end

function UIController.setText(key: string, text: string)
	local inst = keys[key]
	if inst and (inst :: any).Text ~= text then
		inst.Text = text
	end
end

function UIController.setVisible(key: string, visible: boolean)
	local inst = keys[key]
	if inst and (inst :: any).Visible ~= visible then
		inst.Visible = visible
	end
end

-- Meter helper: sets attribute Value (0..1) on the container (for production animation) and scales `fillKey`.
function UIController.setMeter(key: string, fillKey: string?, value: number)
	local v = math.clamp(value, 0, 1)
	local inst = keys[key]
	if inst then
		inst:SetAttribute("Value", v)
	end
	local fill = fillKey and keys[fillKey]
	if fill then
		fill.Size = UDim2.fromScale(v, 1)
	end
end

-- Binds a button. While `fn` runs (it may yield waiting for a server answer) the button is pending and extra
-- activations are ignored — Equip and Ready cannot double-submit (GDD 12.4).
local function connect(key: string)
	local old = connections[key]
	if old then
		old:Disconnect()
		connections[key] = nil
	end
	local inst = keys[key]
	if inst and inst:IsA("GuiButton") and handlers[key] then
		connections[key] = inst.Activated:Connect(handlers[key])
	end
end

function UIController.onActivated(key: string, fn: () -> ())
	handlers[key] = function()
		local inst = keys[key]
		if pending[key] or (inst and inst:GetAttribute("Disabled") == true) then
			return
		end
		pending[key] = true
		if inst then
			inst:SetAttribute("Pending", true)
		end
		local ok, err = pcall(fn)
		pending[key] = nil
		if inst then
			inst:SetAttribute("Pending", false)
		end
		if not ok then
			warn("[ColorClash] UI action " .. key .. " failed: " .. tostring(err))
		end
	end
	connect(key)
end

-- Runs a bound button's handler through the same guarded path as a click/tap/gamepad press (tests, accessibility).
function UIController.activate(key: string): boolean
	local h = handlers[key]
	local inst = keys[key]
	if not h or not inst or inst:GetAttribute("Disabled") == true then
		return false
	end
	h()
	return true
end

-- Swaps to another UI root that satisfies the same contract (UI-10: Codex's production UI replacing the wireframe,
-- or any later hot swap). Every handler is rebound by key; nothing depends on the old hierarchy.
function UIController.adopt(gui: ScreenGui): (boolean, { string })
	local found, errors = UIContract.validate(gui)
	if #errors > 0 then
		return false, errors
	end
	local old = root
	root = gui
	keys = found
	isWireframe = gui:GetAttribute("IsWireframe") == true
	validationErrors = {}
	if gui.Parent == nil then
		gui.Parent = player:WaitForChild("PlayerGui")
	end
	gui.Enabled = true
	for key in handlers do
		connect(key)
	end
	for name, k in PANELS do
		UIController.setVisible(k, panelStack[#panelStack] == name)
	end
	if old and old ~= gui then
		old.Enabled = false
	end
	player:SetAttribute("CCUIWireframe", isWireframe)
	player:SetAttribute("CCUIErrors", 0)
	for _, fn in adoptListeners do
		task.spawn(fn)
	end
	return true, {}
end

function UIController.onAdopted(fn: () -> ())
	table.insert(adoptListeners, fn)
end

function UIController.setEnabled(key: string, enabled: boolean)
	local inst = keys[key]
	if inst and inst:IsA("GuiButton") then
		inst.Active = enabled
		inst.AutoButtonColor = enabled
		inst:SetAttribute("Disabled", not enabled)
		if inst:IsA("TextButton") then
			inst.TextTransparency = if enabled then 0 else 0.5
		end
	end
end

-- Clones a template row (templates stay hidden). The clone keeps no global UIKey binding.
function UIController.cloneTemplate(key: string, parentKey: string?): GuiObject?
	local tpl = keys[key]
	if not tpl then
		return nil
	end
	local c = tpl:Clone() :: GuiObject
	c:SetAttribute("UIKey", nil)
	for _, d in c:GetDescendants() do
		d:SetAttribute("UIKey", nil)
	end
	c.Visible = true
	c.Parent = if parentKey and keys[parentKey] then keys[parentKey] else tpl.Parent
	return c
end

local function firstButton(container: Instance): GuiObject?
	local best: GuiObject? = nil
	for _, d in container:GetDescendants() do
		if d:IsA("GuiButton") and d.Visible and d:GetAttribute("UIKey") ~= nil then
			if not best or d.AbsolutePosition.Y < best.AbsolutePosition.Y then
				best = d
			end
		end
	end
	return best
end

local function topPanel(): string?
	return panelStack[#panelStack]
end

local function refreshContext()
	if #panelStack > 0 then
		input.setContext("Menu")
	else
		input.setContext(UIController.gameplayContext or "Disabled")
	end
end

-- The context to restore when no panel is open (set by the round/character controllers).
UIController.gameplayContext = "Disabled"

function UIController.setGameplayContext(ctx: string)
	UIController.gameplayContext = ctx
	if #panelStack == 0 then
		input.setContext(ctx)
	end
end

function UIController.onPanelChanged(fn: (string?, string?) -> ())
	table.insert(panelListeners, fn)
end

function UIController.openPanel(name: string)
	local key = PANELS[name]
	if not key or not keys[key] then
		return
	end
	local idx = table.find(panelStack, name)
	if idx then
		table.remove(panelStack, idx)
	end
	table.insert(panelStack, name)
	for n, k in PANELS do
		UIController.setVisible(k, n == name)
	end
	refreshContext()
	if input.device() == "Gamepad" then
		-- a panel made visible this frame is not yet selectable: select once it is laid out (retry briefly)
		task.spawn(function()
			for _ = 1, 10 do
				task.wait(0.03)
				if panelStack[#panelStack] ~= name then
					return
				end
				local target = firstButton(keys[key])
				if not target then
					return
				end
				pcall(function()
					GuiService.SelectedObject = target
				end)
				if GuiService.SelectedObject == target then
					return
				end
			end
		end)
	end
	for _, fn in panelListeners do
		task.spawn(fn, name, "open")
	end
end

function UIController.closePanel(name: string?)
	local target = name or topPanel()
	if not target then
		return
	end
	local idx = table.find(panelStack, target)
	if idx then
		table.remove(panelStack, idx)
	end
	UIController.setVisible(PANELS[target], false)
	local nextPanel = topPanel()
	if nextPanel then
		UIController.setVisible(PANELS[nextPanel], true)
	end
	if GuiService.SelectedObject and keys[PANELS[target]] and GuiService.SelectedObject:IsDescendantOf(keys[PANELS[target]]) then
		GuiService.SelectedObject = nil
	end
	refreshContext()
	for _, fn in panelListeners do
		task.spawn(fn, target, "close")
	end
end

function UIController.closeAllPanels()
	while #panelStack > 0 do
		UIController.closePanel(panelStack[#panelStack])
	end
end

function UIController.isOpen(name: string): boolean
	return table.find(panelStack, name) ~= nil
end

function UIController.openPanels(): { string }
	return table.clone(panelStack)
end

UIController.PANELS = PANELS

return UIController
