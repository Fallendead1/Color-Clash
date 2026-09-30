-- Local movement prediction (GDD 05.1, 05.2). States are explicit: Standing, Airborne, Gliding, Climbing, Eliminated.
-- Ownership under the character comes from the paint mirror with the same 0.08 s boundary hysteresis the server
-- uses; speeds come from the shared Rules module. The server validates displacement and owns refill/health.
--
-- Paint Climb: hold Glide against a registered Climbable wall whose cells at the contact samples are your colour.
-- Continuous contact is required; losing friendly paint or contact detaches safely; Jump detaches; the top uses a
-- clearance-tested mantle onto a real landing surface (never through an obstacle). The camera is never rolled onto
-- the wall.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Rules = require(Shared.Movement.Rules)

local MovementController = {}
MovementController.mantleListeners = {} :: { () -> () }

local MV = GameConfig.Movement
local player = Players.LocalPlayer

local input, paintClient, cameraController, remotes
local state = "Standing"
local ground = "None"
local hysteresis = Rules.newHysteresis("None")
local currentSpeed = MV.WalkSpeed
local glideSince = 0
local activity = { firing = false, charging = false, rolling = false, pushing = false, weaponFireSpeed = nil }
local firingUntil = 0
local climb = nil -- { normal: Vector3, startY: number, lv: LinearVelocity, ao: AlignOrientation, att: Attachment }
local climbCooldownUntil = 0
local lastDetach = "" -- diagnostic: why the last climb ended
local climbDebug = "" -- diagnostic: last climb frame summary
local lastReport = { glide = false, climb = false, life = -1 }
local listeners: { (string, string) -> () } = {}
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
local controlModule = nil
local geometryDirty = true

local function character()
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return c, h, r
end

local function refreshGeometry()
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
	params.FilterDescendantsInstances = list
	geometryDirty = false
end

local function setState(s: string)
	if s ~= state then
		local old = state
		state = s
		for _, fn in listeners do
			task.spawn(fn, s, old)
		end
	end
end

function MovementController.onMantle(fn: () -> ())
	table.insert(MovementController.mantleListeners, fn)
end

function MovementController.onState(fn: (string, string) -> ())
	table.insert(listeners, fn)
end

function MovementController.state(): string
	return state
end

function MovementController.ground(): string
	return ground
end

function MovementController.speed(): number
	return currentSpeed
end

-- Weapons report their activity so speed/refill predictions match the server (the server tracks its own copy).
function MovementController.setActivity(key: string, value: any)
	activity[key] = value
end

-- A light attack happened: firing speed for a short window and glide exits immediately (<= 0.12 s rule).
function MovementController.noteFired(speedOverride: number?)
	firingUntil = os.clock() + 0.25
	activity.weaponFireSpeed = speedOverride
	if state == "Gliding" then
		setState("Standing")
	end
end

local function teamId(): number
	return player:GetAttribute("CCTeam") or 0
end

local function ownerAt(position: Vector3): (any?, number?)
	return paintClient.ownerAtPoint(position)
end

local function classifyGround(r: BasePart, h: Humanoid): string
	local hit = Workspace:Raycast(r.Position, Vector3.new(0, -(h.HipHeight + r.Size.Y / 2 + 1.2), 0), params)
	if not hit then
		return "None"
	end
	local patch, owner = ownerAt(hit.Position)
	if not patch then
		return "Inert"
	end
	local t = teamId()
	if patch.def.Kind == "Base" then
		return if owner == t then "Base" else "Enemy"
	end
	if owner == 0 then
		return "Neutral"
	end
	return if owner == t then "Own" else "Enemy"
end

-- Wall contact along `dir` from `origin`:
--   "own"    a registered climbable wall cell in the player's colour (returns the hit)
--   "notown" the climbable wall continues but this cell is neutral/enemy -> loss of friendly paint
--   "none"   no climbable wall here (open air above the top edge, or non-climbable geometry)
local function wallContact(origin: Vector3, dir: Vector3, reach: number): (string, RaycastResult?)
	local hit = Workspace:Raycast(origin, dir * reach, params)
	if not hit or hit.Instance:GetAttribute("Climbable") ~= true or math.abs(hit.Normal.Y) > 0.3 then
		return "none", nil
	end
	local grid = paintClient.grid()
	if not grid then
		return "none", nil
	end
	local patch, i, j = grid:locate(vector.create(hit.Position.X, hit.Position.Y, hit.Position.Z), 0.8, nil)
	if not patch or math.abs(patch.def.Normal.Y) > 0.3 then
		return "none", nil
	end
	if buffer.readu8(patch.owner, j * patch.def.SizeU + i) ~= teamId() then
		return "notown", hit
	end
	return "own", hit
end

-- Convenience: the hit when the contact is an own-colour climbable cell, else nil.
local function climbableWall(origin: Vector3, dir: Vector3, reach: number): RaycastResult?
	local status, hit = wallContact(origin, dir, reach)
	return if status == "own" then hit else nil
end

-- Camera-relative move input: X = right, Z = -forward (the ControlModule convention).
local function moveVector(): Vector3
	if controlModule then
		local ok, v = pcall(function()
			return controlModule:GetMoveVector()
		end)
		if ok and v and v.Magnitude > 1e-3 then
			return v
		end
	end
	-- Fallback: convert the humanoid's world-space MoveDirection into camera space.
	local _, h = character()
	local world = h and h.MoveDirection or Vector3.zero
	if world.Magnitude < 1e-3 then
		return Vector3.zero
	end
	local cam = Workspace.CurrentCamera.CFrame
	local look = Vector3.new(cam.LookVector.X, 0, cam.LookVector.Z)
	local right = Vector3.new(cam.RightVector.X, 0, cam.RightVector.Z)
	if look.Magnitude < 1e-3 or right.Magnitude < 1e-3 then
		return Vector3.zero
	end
	return Vector3.new(world:Dot(right.Unit), 0, -world:Dot(look.Unit))
end

local function stopClimb(r: BasePart?, h: Humanoid?, push: Vector3?)
	if not climb then
		return
	end
	climb.lv:Destroy()
	climb.ao:Destroy()
	climb.att:Destroy()
	climb = nil
	if r then
		r:SetAttribute("CCClimbing", nil)
		if push then
			r.AssemblyLinearVelocity = push
		end
	end
	if h then
		h:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	setState("Airborne")
end

local function startClimb(r: BasePart, h: Humanoid, hit: RaycastResult)
	local att = Instance.new("Attachment")
	att.Name = "CCClimbAttachment"
	att.Parent = r
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = 1e6
	lv.VectorVelocity = Vector3.zero
	lv.Parent = r
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.RigidityEnabled = true
	ao.CFrame = CFrame.lookAt(Vector3.zero, -hit.Normal)
	ao.Parent = r
	h:ChangeState(Enum.HumanoidStateType.Physics)
	r:SetAttribute("CCClimbing", true)
	climb = { normal = hit.Normal, startY = r.Position.Y, lv = lv, ao = ao, att = att }
	setState("Climbing")
end

-- Mantle over the top edge onto a real landing with standing clearance; otherwise refuse.
-- The mantle triggers when the root is just above the wall top (upper contact sample clear, lower sample on the
-- wall), so the landing must be at wall-top height: within [root - 1.6, root + 0.3]. A surface higher than that
-- (e.g. the top of an overhang) is not reachable by a mantle and must never be vaulted onto (MOVE-04).
local function tryMantle(r: BasePart, h: Humanoid): boolean
	local n = climb.normal
	local probeFrom = r.Position - n * 1.6 + Vector3.new(0, 0.3, 0)
	local down = Workspace:Raycast(probeFrom, Vector3.new(0, -2.0, 0), params)
	if not down or down.Normal.Y < 0.7 then
		return false
	end
	local landing = down.Position
	if landing.Y > r.Position.Y + 0.3 or landing.Y < r.Position.Y - 1.6 then
		return false
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = params.FilterDescendantsInstances
	local blocking = Workspace:GetPartBoundsInBox(CFrame.new(landing + Vector3.new(0, 3.1, 0)), Vector3.new(2.6, 5.4, 2.6), overlap)
	if #blocking > 0 then
		return false
	end
	stopClimb(r, h, nil)
	local c = player.Character
	if c then
		c:PivotTo(CFrame.new(landing + Vector3.new(0, h.HipHeight + r.Size.Y / 2 + 0.1, 0)) * r.CFrame.Rotation)
	end
	h:ChangeState(Enum.HumanoidStateType.Landed)
	setState("Standing")
	for _, fn in MovementController.mantleListeners do
		task.spawn(fn)
	end
	return true
end

local function report(lifeId: number)
	local glide = state == "Gliding" or (input.isHeld("Glide") and state ~= "Climbing")
	local climbing = state == "Climbing"
	if lastReport.glide ~= glide or lastReport.climb ~= climbing or lastReport.life ~= lifeId then
		lastReport = { glide = glide, climb = climbing, life = lifeId }
		remotes.ClientEvent:FireServer({ k = "Move", l = lifeId, glide = glide, climb = climbing })
	end
end

local function step(dt: number)
	local c, h, r = character()
	if not c or not h or not r then
		return
	end
	if player:GetAttribute("CCAlive") == false then
		stopClimb(r, h, nil)
		setState("Eliminated")
		return
	end
	if geometryDirty then
		refreshGeometry()
	end
	local now = os.clock()
	activity.firing = now < firingUntil
	local sample = classifyGround(r, h)
	ground = Rules.updateGround(hysteresis, sample, now, MV.BoundaryHysteresisSeconds)
	local glideHeld = input.isHeld("Glide")

	if state == "Climbing" and climb then
		local n = climb.normal
		local highStatus = wallContact(r.Position, -n, 2.2)
		local lowStatus = wallContact(r.Position - Vector3.new(0, 1.4, 0), -n, 2.2)
		local contactHigh = highStatus == "own"
		local contactLow = lowStatus == "own"
		local lostPaint = highStatus == "notown" or lowStatus == "notown"
		local mv = moveVector()
		-- camera-relative input: forward -> up the wall, right -> along the wall
		local camRight = Workspace.CurrentCamera.CFrame.RightVector
		local wallUp = (Vector3.yAxis - n * n:Dot(Vector3.yAxis)).Unit
		local wallRight = n:Cross(wallUp)
		if wallRight:Dot(camRight) < 0 then
			wallRight = -wallRight
		end
		local upInput = -mv.Z
		local sideInput = mv.X
		climbDebug = string.format("high=%s low=%s up=%.2f side=%.2f vel=(%.1f,%.1f,%.1f) hstate=%s", highStatus, lowStatus, upInput, sideInput, r.AssemblyLinearVelocity.X, r.AssemblyLinearVelocity.Y, r.AssemblyLinearVelocity.Z, h:GetState().Name)
		if not glideHeld or lostPaint then
			-- releasing Glide, or friendly paint lost at a contact sample (hostile repaint): detach safely
			if lostPaint then
				climbCooldownUntil = now + 0.5 -- no immediate re-grab loop while inputs stay held
			end
			lastDetach = if lostPaint then "lostPaint" else "glideReleased"
			stopClimb(r, h, nil)
		elseif h.Jump then
			lastDetach = "jump"
			stopClimb(r, h, n * 12 + Vector3.new(0, 26, 0))
		elseif not contactHigh and not contactLow then
			if upInput <= 0.2 or not tryMantle(r, h) then
				lastDetach = string.format("noContact(up=%.2f,high=%s,low=%s)", upInput, highStatus, lowStatus)
				stopClimb(r, h, nil)
			else
				lastDetach = "mantled"
			end
		elseif not contactHigh and contactLow and upInput > 0.2 then
			-- head is above the wall top: mantle or stop at the edge
			if tryMantle(r, h) then
				lastDetach = "mantled"
			else
				lastDetach = "blockedLedge"
				climb.lv.VectorVelocity = Vector3.zero
			end
		else
			local height = r.Position.Y - climb.startY
			if height > MV.MaxClimbHeight + 2 and upInput > 0 then
				upInput = 0
			end
			climb.lv.VectorVelocity = (wallUp * upInput + wallRight * sideInput) * MV.ClimbSpeed - n * 1.5
		end
		if state == "Climbing" then
			currentSpeed = MV.ClimbSpeed
			report(player:GetAttribute("CCLifeId") or 0)
			return
		end
	end

	local airborne = h.FloorMaterial == Enum.Material.Air
	-- enter climb: glide held, moving into a climbable friendly wall, not on enemy paint
	if glideHeld and now >= climbCooldownUntil and ground ~= "Enemy" and not activity.charging and not activity.rolling and not activity.pushing then
		local look = r.CFrame.LookVector
		local mv = h.MoveDirection
		local dir = if mv.Magnitude > 0.2 then mv.Unit else look
		local hit = climbableWall(r.Position, Vector3.new(dir.X, 0, dir.Z).Unit, 1.9)
		local low = hit and climbableWall(r.Position - Vector3.new(0, 1.4, 0), Vector3.new(dir.X, 0, dir.Z).Unit, 2.2)
		if hit and low and mv.Magnitude > 0.2 and mv.Unit:Dot(-hit.Normal) > 0.3 then
			startClimb(r, h, hit)
			report(player:GetAttribute("CCLifeId") or 0)
			return
		end
	end

	local act = {
		firing = activity.firing,
		charging = activity.charging,
		rolling = activity.rolling,
		pushing = activity.pushing,
		glideHeld = glideHeld,
		weaponFireSpeed = activity.weaponFireSpeed,
	}
	local gliding = not airborne and Rules.isGliding(ground, act) and not activity.charging and not activity.rolling and not activity.pushing
	if gliding then
		if state ~= "Gliding" then
			glideSince = now
		end
		setState("Gliding")
	elseif airborne then
		setState("Airborne")
	else
		setState("Standing")
	end
	local target = Rules.speed(MV, if gliding then "Gliding" else "Standing", ground, act)
	if gliding and currentSpeed < target then
		-- accelerate to glide speed over GlideAccelerationSeconds
		local rate = (MV.GlideSpeed - MV.WalkSpeed) / MV.GlideAccelerationSeconds
		currentSpeed = math.min(target, currentSpeed + rate * dt)
	else
		currentSpeed = target
	end
	if not airborne then
		h.WalkSpeed = currentSpeed
	else
		-- jumping keeps momentum within the configured cap
		h.WalkSpeed = math.min(math.max(h.WalkSpeed, currentSpeed), MV.GlideJumpMomentumCap)
	end
	cameraController.setGlideDrop(state == "Gliding")
	report(player:GetAttribute("CCLifeId") or 0)
	local _ = glideSince
end

function MovementController.start(deps)
	input, paintClient, cameraController, remotes = deps.input, deps.paint, deps.camera, deps.remotes
	task.spawn(function()
		local ok, pm = pcall(function()
			return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10))
		end)
		if ok and pm then
			controlModule = pm:GetControls()
		end
	end)
	paintClient.onChange(function(kind)
		if kind == "map" or kind == "clear" then
			geometryDirty = true
		end
	end)
	Workspace.ChildAdded:Connect(function()
		geometryDirty = true
	end)
	player.CharacterAdded:Connect(function()
		climb = nil
		hysteresis = Rules.newHysteresis("None")
		currentSpeed = MV.WalkSpeed
		firingUntil = 0
		activity = { firing = false, charging = false, rolling = false, pushing = false, weaponFireSpeed = nil }
		lastReport = { glide = false, climb = false, life = -1 }
		geometryDirty = true
		setState("Standing")
	end)
	RunService.PreSimulation:Connect(step)
end

function MovementController.lastDetach(): string
	return lastDetach
end

function MovementController.climbDebug(): string
	return climbDebug
end

-- Test hook: force a geometry refresh (arena changes).
function MovementController.refresh()
	geometryDirty = true
end

return MovementController
