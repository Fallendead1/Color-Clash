-- Semantic input layer (GDD 04.3): one place maps keyboard/mouse, gamepad and touch to actions. Weapon and UI code
-- listen to actions, never to devices. Contexts:
--   "Gameplay" : combat actions active
--   "Menu"     : a panel is open; combat actions are ignored and nothing fires
--   "Disabled" : eliminated / loading / intro; combat actions ignored
-- Every held action is released on context change, focus loss, death, respawn and round transitions, so a weapon
-- never keeps firing because a finger or controller disconnected.

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local InputController = {}

export type Action = "Primary" | "Secondary" | "Glide" | "Gadget" | "Ultimate" | "Map" | "Scoreboard" | "ShoulderSwap" | "Cancel" | "Jump"

local BINDINGS: { [string]: { Enum.KeyCode | Enum.UserInputType } } = {
	Primary = { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 },
	Secondary = { Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2 },
	Glide = { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonR1 },
	Gadget = { Enum.KeyCode.Q, Enum.KeyCode.ButtonL1 },
	Ultimate = { Enum.KeyCode.E, Enum.KeyCode.ButtonX },
	Map = { Enum.KeyCode.M, Enum.KeyCode.ButtonY },
	Scoreboard = { Enum.KeyCode.Tab, Enum.KeyCode.ButtonSelect },
	ShoulderSwap = { Enum.KeyCode.C, Enum.KeyCode.ButtonR3 },
	Cancel = { Enum.KeyCode.ButtonB },
}

-- Actions that work outside the Gameplay context (panel toggles and cancel).
local MENU_SAFE = { Map = true, Scoreboard = true, Cancel = true }
local COMBAT = { Primary = true, Secondary = true, Glide = true, Gadget = true, Ultimate = true }

local context = "Disabled"
local held: { [string]: boolean } = {}
local listeners: { (string, boolean) -> () } = {}
local contextListeners: { (string) -> () } = {}
local lastDevice = "KeyboardMouse"
local glideToggleMode = false
local glideToggled = false
local primaryBlockedUntilRelease = false

local function emit(action: string, down: boolean)
	for _, fn in listeners do
		local ok, err = pcall(fn, action, down)
		if not ok then
			warn("[ColorClash] input listener error: " .. tostring(err))
		end
	end
end

local function setHeld(action: string, down: boolean)
	if held[action] == down then
		return
	end
	held[action] = down
	emit(action, down)
end

function InputController.releaseAll(reason: string?)
	for action, down in held do
		if down then
			held[action] = false
			emit(action, false)
		end
	end
	glideToggled = false
	local _ = reason
end

function InputController.onAction(fn: (string, boolean) -> ())
	table.insert(listeners, fn)
end

function InputController.onContext(fn: (string) -> ())
	table.insert(contextListeners, fn)
end

function InputController.isHeld(action: string): boolean
	return held[action] == true
end

function InputController.context(): string
	return context
end

function InputController.setContext(ctx: string)
	if ctx == context then
		return
	end
	local previous = context
	context = ctx
	InputController.releaseAll("context")
	-- Closing a panel must not turn the click that closed it into a shot (GDD 12.4).
	if ctx == "Gameplay" and previous == "Menu" then
		primaryBlockedUntilRelease = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
	end
	for _, fn in contextListeners do
		task.spawn(fn, ctx)
	end
end

function InputController.setGlideToggle(enabled: boolean)
	glideToggleMode = enabled
	glideToggled = false
end

function InputController.device(): string
	return lastDevice
end

local function handle(action: string, down: boolean): boolean
	if COMBAT[action] and context ~= "Gameplay" then
		return false
	end
	if not COMBAT[action] and not MENU_SAFE[action] and context ~= "Gameplay" then
		return false
	end
	if action == "Primary" and primaryBlockedUntilRelease then
		if not down then
			primaryBlockedUntilRelease = false
		end
		return true
	end
	if action == "Glide" and glideToggleMode then
		if down then
			glideToggled = not glideToggled
			setHeld("Glide", glideToggled)
		end
		return true
	end
	setHeld(action, down)
	return true
end

-- Touch buttons and other UI controls call this (the same action path as keys; GDD 04.3).
function InputController.press(action: string, down: boolean)
	lastDevice = "Touch"
	handle(action, down)
end

function InputController.start()
	for action, inputs in BINDINGS do
		ContextActionService:BindActionAtPriority("CC_" .. action, function(_, state, input)
			if state == Enum.UserInputState.Begin then
				local consumed = handle(action, true)
				return if consumed then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				handle(action, false)
			end
			local _ = input
			return Enum.ContextActionResult.Pass
		end, false, Enum.ContextActionPriority.High.Value, table.unpack(inputs))
	end
	UserInputService.WindowFocusReleased:Connect(function()
		InputController.releaseAll("focus")
	end)
	UserInputService.LastInputTypeChanged:Connect(function(t)
		if t == Enum.UserInputType.Touch then
			lastDevice = "Touch"
		elseif string.find(t.Name, "Gamepad") then
			lastDevice = "Gamepad"
		elseif t == Enum.UserInputType.Keyboard or string.find(t.Name, "Mouse") then
			lastDevice = "KeyboardMouse"
		end
	end)
	UserInputService.GamepadDisconnected:Connect(function()
		InputController.releaseAll("gamepad disconnected")
	end)
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		lastDevice = "Touch"
		glideToggleMode = true -- touch default: glide toggle (GDD 04.3)
	end
end

InputController.BINDINGS = BINDINGS

return InputController
