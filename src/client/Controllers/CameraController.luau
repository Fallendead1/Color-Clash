-- Third-person shoulder camera and legal aim (GDD 04.2). The player always controls look direction — during firing,
-- charging, gliding, climbing, gadgets and ultimates. No forced cutscenes, tilt or spinning.
--
-- Aim: a ray from the camera through the reticle finds the aim point; a second ray from the legal muzzle toward that
-- point decides what the shot can actually reach. If the muzzle ray is blocked short of the aim point, the HUD shows a
-- blocked-shot indicator (the server re-validates every shot anyway).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local CameraController = {}

local CAM = GameConfig.Camera
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local input = nil
local yaw, pitch = 0, -0.25
local shoulder = 1 -- 1 right, -1 left
local currentDistance = CAM.Distance
local sensitivity = 1
local invertY = false
local reducedEffects = false
local fovTarget = CAM.FieldOfView
local extraDrop = 0 -- lower camera while gliding (presentation)
local extraDropTarget = 0
local active = false
local lookParams = RaycastParams.new()
lookParams.FilterType = Enum.RaycastFilterType.Include
local aim = { point = Vector3.zero, direction = Vector3.new(0, 0, -1), muzzle = Vector3.zero, blocked = false, hitDistance = 0 }
local touchLookInput: InputObject? = nil
local lastTouchPos: Vector2? = nil

local MIN_PITCH, MAX_PITCH = math.rad(-75), math.rad(70)
local MOUSE_RATE = 0.0035
local STICK_RATE = 3.2
local TOUCH_RATE = 0.006

local function geometry(): { Instance }
	local list = {}
	local arena = Workspace:FindFirstChild("ColorClashArena")
	if arena then
		for _, m in arena:GetChildren() do
			for _, name in { "Geometry", "PaintSurfaces" } do
				local f = m:FindFirstChild(name)
				if f then
					table.insert(list, f)
				end
			end
		end
	end
	local staging = Workspace:FindFirstChild("ColorClashStaging")
	if staging then
		table.insert(list, staging)
	end
	return list
end

function CameraController.refreshGeometry()
	lookParams.FilterDescendantsInstances = geometry()
end

-- Adds a look delta in radians (all devices funnel here; tests use it to prove continuous control).
function CameraController.addLook(dYaw: number, dPitch: number)
	yaw -= dYaw
	pitch = math.clamp(pitch - dPitch * (if invertY then -1 else 1), MIN_PITCH, MAX_PITCH)
end

function CameraController.setSettings(opts: { sensitivity: number?, invertY: boolean?, reducedEffects: boolean? })
	if opts.sensitivity then
		sensitivity = math.clamp(opts.sensitivity, 0.1, 5)
	end
	if opts.invertY ~= nil then
		invertY = opts.invertY
	end
	if opts.reducedEffects ~= nil then
		reducedEffects = opts.reducedEffects
	end
end

-- Presentation code (camera shake, VFX density) reads this; gameplay warnings are never hidden by it.
function CameraController.reducedEffects(): boolean
	return reducedEffects
end

function CameraController.swapShoulder()
	shoulder = -shoulder
end

function CameraController.setShoulder(side: number)
	shoulder = if side < 0 then -1 else 1
end

function CameraController.shoulder(): number
	return shoulder
end

function CameraController.setFocus(focused: boolean)
	fovTarget = if focused then CAM.ChargerFocusFieldOfView else CAM.FieldOfView
end

function CameraController.setGlideDrop(on: boolean)
	extraDropTarget = if on then 1.2 else 0
end

function CameraController.aim()
	return aim
end

function CameraController.yaw(): number
	return yaw
end

-- Faces the camera (and so the character) along a horizontal direction, e.g. after a respawn or placement.
function CameraController.faceDirection(dir: Vector3)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude > 1e-3 then
		flat = flat.Unit
		yaw = math.atan2(-flat.X, -flat.Z)
	end
end

function CameraController.setPitch(radians: number)
	pitch = math.clamp(radians, MIN_PITCH, MAX_PITCH)
end

function CameraController.lookVector(): Vector3
	return (CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)).LookVector
end

local function root(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Legal muzzle: the weapon's Muzzle attachment when present (Codex models), else a fixed hand offset.
local function muzzlePosition(rootPart: BasePart): Vector3
	local c = player.Character
	local tool = c and c:FindFirstChild("ColorClashWeapon")
	local att = tool and tool:FindFirstChild("Muzzle", true)
	if att and att:IsA("Attachment") then
		return att.WorldPosition
	end
	local flat = CFrame.fromEulerAnglesYXZ(0, yaw, 0)
	return rootPart.Position + flat.RightVector * 0.9 * shoulder + Vector3.new(0, 1.1, 0) + flat.LookVector * 0.8
end

local function updateAim(rootPart: BasePart)
	local look = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0).LookVector
	local origin = camera.CFrame.Position
	local maxRange = 200
	local hit = Workspace:Raycast(origin, look * maxRange, lookParams)
	local point = if hit then hit.Position else origin + look * maxRange
	local muzzle = muzzlePosition(rootPart)
	local toPoint = point - muzzle
	local dist = toPoint.Magnitude
	local blocked = false
	local hitDistance = dist
	if dist > 0.05 then
		local mh = Workspace:Raycast(muzzle, toPoint, lookParams)
		if mh and (mh.Position - point).Magnitude > 1.0 then
			blocked = true
			hitDistance = (mh.Position - muzzle).Magnitude
		end
	end
	aim.point = point
	aim.direction = if dist > 0.05 then toPoint.Unit else look
	aim.muzzle = muzzle
	aim.blocked = blocked
	aim.hitDistance = hitDistance
end

local function step(dt: number)
	if not active then
		return
	end
	local rootPart = root()
	if not rootPart then
		return
	end
	-- gamepad right stick
	for _, state in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
		if state.KeyCode == Enum.KeyCode.Thumbstick2 then
			local v = state.Position
			if v.Magnitude > 0.15 then
				CameraController.addLook(v.X * STICK_RATE * sensitivity * dt, -v.Y * STICK_RATE * sensitivity * dt)
			end
		end
	end
	extraDrop += (extraDropTarget - extraDrop) * math.min(1, dt * 8)
	local rot = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)
	local pivot = rootPart.Position + Vector3.new(0, CAM.VerticalOffset - extraDrop, 0)
	local shoulderPoint = pivot + rot.RightVector * CAM.RightOffset * shoulder
	-- keep the shoulder offset itself out of walls
	local sh = Workspace:Raycast(pivot, shoulderPoint - pivot, lookParams)
	if sh then
		shoulderPoint = sh.Position - (shoulderPoint - pivot).Unit * 0.3
	end
	local back = -rot.LookVector
	local want = CAM.Distance
	local hit = Workspace:Spherecast(shoulderPoint, 0.4, back * want, lookParams)
	-- Collision always wins: never clamp to a minimum distance that would push the camera into a wall (CAM-03).
	local allowed = if hit then math.max(0, hit.Distance - 0.1) else want
	if allowed < currentDistance then
		currentDistance = allowed -- pull in immediately: never clip through walls
	else
		currentDistance = math.min(allowed, currentDistance + CAM.ReturnSpeed * dt) -- return smoothly
	end
	camera.CFrame = CFrame.lookAt(shoulderPoint + back * currentDistance, shoulderPoint + rot.LookVector)
	camera.FieldOfView += (fovTarget - camera.FieldOfView) * math.min(1, dt * 12)
	-- character faces the aim yaw (shooter control), without taking control of the camera
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Physics and not rootPart:GetAttribute("CCClimbing") then
		humanoid.AutoRotate = false
		local flat = CFrame.fromEulerAnglesYXZ(0, yaw, 0)
		rootPart.CFrame = CFrame.new(rootPart.Position) * flat
	end
	updateAim(rootPart)
end

-- Enables the gameplay camera (Gameplay/Disabled contexts) or releases it for menus.
local function applyMouse()
	local ctx = input and input.context()
	-- Locked for look whenever the shoulder camera runs and no panel is open (including Intro, where firing is
	-- disabled but the camera must stay controllable; GDD 12.1 Match intro).
	if active and ctx ~= "Menu" and input.device() == "KeyboardMouse" then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end

function CameraController.setActive(on: boolean)
	active = on
	if on then
		camera.CameraType = Enum.CameraType.Scriptable
		CameraController.refreshGeometry()
		local r = root()
		if r then
			local _, y = r.CFrame:ToEulerAnglesYXZ()
			yaw = y
		end
	else
		camera.CameraType = Enum.CameraType.Custom
		local c = player.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if h then
			camera.CameraSubject = h
			h.AutoRotate = true
		end
	end
	applyMouse()
end

function CameraController.isActive(): boolean
	return active
end

function CameraController.start(inputController)
	input = inputController
	camera = Workspace.CurrentCamera
	RunService:BindToRenderStep("ColorClashCamera", Enum.RenderPriority.Camera.Value + 1, step)
	UserInputService.InputChanged:Connect(function(io, processed)
		if not active or input.context() == "Menu" then
			return
		end
		if io.UserInputType == Enum.UserInputType.MouseMovement and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			CameraController.addLook(io.Delta.X * MOUSE_RATE * sensitivity, io.Delta.Y * MOUSE_RATE * sensitivity)
		elseif io.UserInputType == Enum.UserInputType.Touch and io == touchLookInput and lastTouchPos then
			local pos = Vector2.new(io.Position.X, io.Position.Y)
			local d = pos - lastTouchPos
			lastTouchPos = pos
			CameraController.addLook(d.X * TOUCH_RATE * sensitivity, d.Y * TOUCH_RATE * sensitivity)
		end
		local _ = processed
	end)
	-- Touch look: a drag that begins on the right half and NOT on a button rotates the camera. A touch that starts on
	-- a UI button is "processed" and never rotates the camera (GDD 04.3). Works while Fire is held (multi-touch).
	UserInputService.InputBegan:Connect(function(io, processed)
		if io.UserInputType == Enum.UserInputType.Touch and not processed and active then
			local viewport = camera.ViewportSize
			if io.Position.X > viewport.X * 0.4 and touchLookInput == nil then
				touchLookInput = io
				lastTouchPos = Vector2.new(io.Position.X, io.Position.Y)
			end
		end
	end)
	input.onAction(function(action, down)
		if action == "ShoulderSwap" and down and active then
			CameraController.swapShoulder()
		end
	end)
	UserInputService.InputEnded:Connect(function(io)
		if io == touchLookInput then
			touchLookInput = nil
			lastTouchPos = nil
		end
	end)
	input.onContext(function()
		applyMouse()
	end)
	UserInputService.LastInputTypeChanged:Connect(applyMouse)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		camera = Workspace.CurrentCamera
	end)
end

return CameraController
