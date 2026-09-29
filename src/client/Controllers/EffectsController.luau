-- Presentation-only effects (GDD 06.2, 06.3, 13.1 VFX timing): cosmetic projectiles for local and remote shots,
-- confirmed-hit markers, elimination paint bursts. Pooled and bounded (GDD 14.2: 192 transient objects). Nothing here
-- affects gameplay; Codex replaces the placeholder visuals.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Ballistics = require(Shared.Combat.Ballistics)
local Weapons = require(Shared.Config.Weapons)

local EffectsController = {}

local MAX_OBJECTS = 192
local player = Players.LocalPlayer
local folder: Folder
local pool: { BasePart } = {}
local active: { any } = {}
local liveCount = 0
local palette = { [1] = Color3.fromRGB(255, 138, 0), [2] = Color3.fromRGB(0, 150, 255) }
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
local ui = nil

local function take(): BasePart?
	if liveCount >= MAX_OBJECTS then
		return nil
	end
	local p = table.remove(pool)
	if not p then
		p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(0.5, 0.5, 0.5)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
	end
	liveCount += 1
	p.Parent = folder
	return p
end

local function give(p: BasePart)
	liveCount -= 1
	p.Parent = nil
	table.insert(pool, p)
end

function EffectsController.setPalette(pal)
	palette = table.clone(pal)
end

function EffectsController.refreshGeometry()
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
	params.FilterDescendantsInstances = list
end

-- Launches a cosmetic projectile. `onImpact(position, normal)` fires when it hits world geometry.
function EffectsController.projectile(origin: Vector3, direction: Vector3, weaponId: string, teamId: number, onImpact: ((Vector3, Vector3) -> ())?): any?
	local w = Weapons.Defs[weaponId]
	if not w or not w.ProjectileSpeed then
		return nil
	end
	local part = take()
	if not part then
		return nil
	end
	part.Color = palette[teamId] or Color3.new(1, 1, 1)
	part.CFrame = CFrame.new(origin)
	local fx = { part = part, pos = origin, vel = direction * w.ProjectileSpeed, gravity = w.Gravity, traveled = 0, range = w.Range, onImpact = onImpact, dead = false }
	table.insert(active, fx)
	return fx
end

function EffectsController.cancel(fx)
	if fx and not fx.dead then
		fx.dead = true
	end
end

local function step(dt: number)
	local k = 1
	while k <= #active do
		local fx = active[k]
		local done = fx.dead
		if not done then
			local np, nv = Ballistics.step(vector.create(fx.pos.X, fx.pos.Y, fx.pos.Z), vector.create(fx.vel.X, fx.vel.Y, fx.vel.Z), fx.gravity, dt)
			local b = Vector3.new(np.X, np.Y, np.Z)
			local seg = b - fx.pos
			local hit = Workspace:Raycast(fx.pos, seg, params)
			if hit then
				if fx.onImpact then
					task.spawn(fx.onImpact, hit.Position, hit.Normal)
				end
				done = true
			else
				fx.traveled += seg.Magnitude
				fx.pos = b
				fx.vel = Vector3.new(nv.X, nv.Y, nv.Z)
				fx.part.CFrame = CFrame.new(b)
				if fx.traveled >= fx.range then
					done = true
				end
			end
		end
		if done then
			give(fx.part)
			active[k] = active[#active]
			active[#active] = nil
		else
			k += 1
		end
	end
end

-- Short confirmed-hit marker on the reticle (distinct from the local impact cue; GDD 06.2).
function EffectsController.hitMarker(shielded: boolean)
	local reticle = ui and ui.get("HUD.Reticle")
	if not reticle then
		return
	end
	reticle:SetAttribute("HitConfirmed", true)
	reticle.Size = UDim2.fromOffset(20, 20)
	reticle.Position = UDim2.new(0.5, -10, 0.5, -10)
	reticle.BackgroundColor3 = if shielded then Color3.fromRGB(120, 200, 255) else Color3.fromRGB(255, 255, 255)
	task.delay(0.12, function()
		reticle:SetAttribute("HitConfirmed", false)
		reticle.Size = UDim2.fromOffset(12, 12)
		reticle.Position = UDim2.new(0.5, -6, 0.5, -6)
	end)
end

-- Small paint burst where a player was eliminated (presentation; no scoring paint; GDD 06.3).
function EffectsController.burst(position: Vector3, teamId: number)
	for k = 1, 6 do
		local p = take()
		if not p then
			return
		end
		p.Color = palette[teamId] or Color3.new(1, 1, 1)
		local dir = Vector3.new(math.cos(k), 0.8, math.sin(k)).Unit
		local fx = { part = p, pos = position, vel = dir * 18, gravity = 60, traveled = 0, range = 8, onImpact = nil, dead = false }
		table.insert(active, fx)
	end
end

function EffectsController.stats()
	return { active = #active, live = liveCount, pooled = #pool }
end

function EffectsController.start(deps)
	ui = deps.ui
	folder = Instance.new("Folder")
	folder.Name = "ColorClashEffects"
	folder.Parent = Workspace
	EffectsController.refreshGeometry()
	RunService.RenderStepped:Connect(step)
	deps.remotes.Effect.OnClientEvent:Connect(function(msg)
		if type(msg) ~= "table" then
			return
		end
		if msg.k == "Shot" and msg.u ~= player.UserId and typeof(msg.o) == "Vector3" and typeof(msg.d) == "Vector3" then
			EffectsController.projectile(msg.o, msg.d, msg.w, msg.tm)
		end
	end)
	deps.remotes.DamageResult.OnClientEvent:Connect(function(msg)
		if type(msg) ~= "table" then
			return
		end
		if msg.k == "Hit" and msg.ok then
			EffectsController.hitMarker(false)
		elseif msg.k == "Shielded" then
			EffectsController.hitMarker(true)
		elseif msg.k == "Eliminated" and typeof(msg.pos) == "Vector3" then
			EffectsController.burst(msg.pos, msg.team or 1)
		end
	end)
end

return EffectsController
