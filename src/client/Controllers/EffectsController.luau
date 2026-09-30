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
	p.Transparency = 0
	p.Parent = folder
	return p
end

local function give(p: BasePart)
	local visual = p:FindFirstChild("CCAuthoredVisual")
	if visual then
		visual:Destroy()
	end
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

-- Launches a cosmetic ballistic object with an explicit velocity. `onImpact(position, normal)` fires on world contact.
function EffectsController.launch(origin: Vector3, velocity: Vector3, gravity: number, range: number, teamId: number, size: number?, onImpact: ((Vector3, Vector3) -> ())?): any?
	local part = take()
	if not part then
		return nil
	end
	local sz = size or 0.5
	part.Size = Vector3.new(sz, sz, sz)
	part.Color = palette[teamId] or Color3.new(1, 1, 1)
	part.CFrame = CFrame.new(origin)
	local fx = { part = part, pos = origin, vel = velocity, gravity = gravity, traveled = 0, range = range, onImpact = onImpact, dead = false }
	table.insert(active, fx)
	return fx
end

-- Launches a cosmetic shot for a projectile/blaster weapon along `direction`.
function EffectsController.projectile(origin: Vector3, direction: Vector3, weaponId: string, teamId: number, onImpact: ((Vector3, Vector3) -> ())?): any?
	local w = Weapons.Defs[weaponId]
	if not w or not w.ProjectileSpeed then
		return nil
	end
	return EffectsController.launch(origin, direction * w.ProjectileSpeed, w.Gravity, w.Range, teamId, if w.Family == "blaster" then 0.9 else 0.5, onImpact)
end

-- Three cosmetic lobes for a Splash Pot volley (same arcs as the server).
function EffectsController.volley(origin: Vector3, direction: Vector3, weaponId: string, teamId: number, onImpact: ((Vector3, Vector3) -> ())?): { any }
	local w = Weapons.Defs[weaponId]
	local out = {}
	if not w or not w.LobeAnglesDegrees then
		return out
	end
	for _, angle in w.LobeAnglesDegrees do
		local lobe = Ballistics.yaw(vector.create(direction.X, direction.Y, direction.Z), angle)
		local vel = Vector3.new(lobe.X, lobe.Y, lobe.Z) * w.LobeSpeed + Vector3.new(0, w.LobeUpSpeed, 0)
		local fx = EffectsController.launch(origin, vel, w.Gravity, w.Range, teamId, 0.8, onImpact)
		if fx then
			table.insert(out, fx)
		end
	end
	return out
end

-- Short straight beam (charger shot, aim warning). Returns the part so warnings can be updated or removed.
local beamPool: { BasePart } = {}
function EffectsController.beam(from: Vector3, to: Vector3, teamId: number, seconds: number?, existing: BasePart?): BasePart
	local p = existing or table.remove(beamPool)
	if not p then
		p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
	end
	local len = (to - from).Magnitude
	p.Size = Vector3.new(0.12, 0.12, math.max(0.1, len))
	p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -len / 2)
	p.Color = palette[teamId] or Color3.new(1, 1, 1)
	p.Parent = folder
	if seconds then
		task.delay(seconds, function()
			p.Parent = nil
			table.insert(beamPool, p)
		end)
	end
	return p
end

function EffectsController.releaseBeam(p: BasePart?)
	if p then
		p.Parent = nil
		table.insert(beamPool, p)
	end
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

-- Functional warning zones (wireframe presentation; Codex replaces the look): a flat disc on the floor for `seconds`.
local zones: { BasePart } = {}
function EffectsController.zone(name: string, center: Vector3, radius: number, seconds: number, teamId: number, transparency: number): BasePart
	local disc = Instance.new("Part")
	disc.Name = name
	disc.Shape = Enum.PartType.Cylinder
	disc.Anchored, disc.CanCollide, disc.CanQuery, disc.CanTouch, disc.CastShadow = true, false, false, false, false
	disc.Material = Enum.Material.Neon
	disc.Color = palette[teamId] or Color3.new(0.8, 0.8, 0.8)
	disc.Transparency = transparency
	disc.Size = Vector3.new(0.2, radius * 2, radius * 2)
	disc.CFrame = CFrame.new(center + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	disc.Parent = folder
	table.insert(zones, disc)
	task.delay(seconds, function()
		local i = table.find(zones, disc)
		if i then
			table.remove(zones, i)
		end
		disc:Destroy()
	end)
	return disc
end

-- A thrown can / capsule / beacon: cosmetic arc, then a blast-radius warning where it sticks until the fuse ends.
local WARN_RADIUS = { splash_can = 10, color_burst = 12, paintstorm = 18 }
function EffectsController.throwable(origin: Vector3, velocity: Vector3, gravity: number, fuse: number, kind: string?, teamId: number)
	local born = os.clock()
	local size = if kind == "color_burst" then 1.6 else 1
	local fx = EffectsController.launch(origin, velocity, gravity, 400, teamId, size, function(pos: Vector3, _normal: Vector3)
		local left = fuse - (os.clock() - born)
		if left > 0.05 then
			EffectsController.zone("Warn_" .. tostring(kind), pos, WARN_RADIUS[kind or ""] or 8, left, teamId, 0.65)
		end
	end)
	-- Native authored capsule mounted on the existing pooled trajectory. The original warning, fuse,
	-- collision query and lifetime remain code-owned; removing the pooled part removes the visual too.
	local keys = { splash_can = "SplashCan", color_burst = "ColorBurstCapsule", paintstorm = "PaintstormBeacon" }
	local assets = game.ReplicatedStorage:FindFirstChild("ColorClashAssets")
	local library = assets and assets:FindFirstChild("Effects")
	local template = library and library:FindFirstChild(keys[kind or ""] or "")
	if fx and template and template:IsA("Model") then
		local visual = template:Clone()
		visual.Name = "CCAuthoredVisual"
		visual:PivotTo(fx.part.CFrame)
		for _, p in visual:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, false, true
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1 = fx.part, p
				weld.Parent = p
			end
		end
		fx.part.Transparency = 1
		visual.Parent = fx.part
	end
end

function EffectsController.zoneCount(): number
	return #zones
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
	local aimBeams: { [number]: BasePart } = {}
	deps.remotes.Effect.OnClientEvent:Connect(function(msg)
		if type(msg) ~= "table" or msg.u == player.UserId then
			return
		end
		local k = msg.k
		if k == "Shot" and typeof(msg.o) == "Vector3" and typeof(msg.d) == "Vector3" then
			EffectsController.projectile(msg.o, msg.d, msg.w, msg.tm)
		elseif k == "Volley" and typeof(msg.o) == "Vector3" and typeof(msg.d) == "Vector3" then
			EffectsController.volley(msg.o, msg.d, msg.w, msg.tm)
		elseif k == "Beam" and typeof(msg.o) == "Vector3" and typeof(msg.e) == "Vector3" then
			EffectsController.beam(msg.o, msg.e, msg.tm, 0.15)
		elseif k == "Aim" and typeof(msg.o) == "Vector3" and typeof(msg.d) == "Vector3" and type(msg.u) == "number" then
			-- charger warning: a line-of-sight-clipped line from the muzzle (GDD 07.3)
			local hit = Workspace:Raycast(msg.o, msg.d * 120, params)
			local finish = if hit then hit.Position else msg.o + msg.d * 120
			aimBeams[msg.u] = EffectsController.beam(msg.o, finish, msg.tm, nil, aimBeams[msg.u])
		elseif k == "ChargeEnd" and type(msg.u) == "number" then
			EffectsController.releaseBeam(aimBeams[msg.u])
			aimBeams[msg.u] = nil
		elseif k == "Burst" and typeof(msg.o) == "Vector3" then
			EffectsController.burst(msg.o, msg.tm or 1)
		elseif k == "Throw" and typeof(msg.o) == "Vector3" and typeof(msg.v) == "Vector3" then
			EffectsController.throwable(msg.o, msg.v, msg.g or 98.1, msg.fuse or 1, msg.kind, msg.tm or 1)
		elseif k == "Storm" and typeof(msg.o) == "Vector3" then
			EffectsController.zone("Storm", msg.o, msg.r or 18, msg.dur or 6, msg.tm or 1, 0.75)
		elseif k == "Fizzle" and typeof(msg.o) == "Vector3" then
			EffectsController.zone("Fizzle", msg.o, 2, 0.8, 0, 0.3)
			if ui then
				ui.setText("HUD.Callout", "Storm fizzled")
			end
		elseif k == "LaunchMarker" and typeof(msg.o) == "Vector3" then
			-- enemy-readable landing marker for the whole transit (GDD 08.4)
			EffectsController.zone("LaunchMarker", msg.o, 3, msg.dur or 1, msg.tm or 1, 0.2)
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
