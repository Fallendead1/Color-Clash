-- Touch buttons -> semantic actions (GDD 04.3, 04.4). Each button is held while its touch is down, so Fire can be
-- held while the other thumb moves or aims (multi-touch). A touch that starts on a button never rotates the camera
-- (CameraController ignores processed touches). Jump uses the humanoid jump; Map toggles the tactical map.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local TouchController = {}

local player = Players.LocalPlayer

local MAP = {
	["Touch.Primary"] = "Primary",
	["Touch.Secondary"] = "Secondary",
	["Touch.Glide"] = "Glide",
	["Touch.Gadget"] = "Gadget",
	["Touch.Ultimate"] = "Ultimate",
	["Touch.Map"] = "Map",
}

function TouchController.start(ui, input)
	for key, action in MAP do
		local b = ui.get(key)
		if b then
			b.InputBegan:Connect(function(io)
				if io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1 then
					b:SetAttribute("Pressed", true)
					input.press(action, true)
				end
			end)
			b.InputEnded:Connect(function(io)
				if io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1 then
					b:SetAttribute("Pressed", false)
					input.press(action, false)
				end
			end)
		end
	end
	local jump = ui.get("Touch.Jump")
	if jump then
		jump.InputBegan:Connect(function(io)
			if io.UserInputType == Enum.UserInputType.Touch then
				local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if h then
					h.Jump = true
				end
			end
		end)
	end
	-- A lost touch (app backgrounded) must not leave an action held: focus loss releases everything in the input
	-- layer; also clear the buttons' pressed state.
	UserInputService.WindowFocusReleased:Connect(function()
		for key in MAP do
			local b = ui.get(key)
			if b then
				b:SetAttribute("Pressed", false)
			end
		end
	end)
end

return TouchController
