--!strict
-- paint_lab: code-generated ENGINEERING FIXTURE (GDD 09.4). Not content, never in production rotation.
-- Plain parts that satisfy the map content contract so loader, paint, movement and combat code can be tested
-- before Codex delivers Switchyard and Canopy Courts. Every report must call results from this map "fixture".
--
-- Layout (floor top at Y = 100, arena X [-48, 48], Z [-32, 32]):
--   Team A base X [-48,-32] Z [-12,12]  |  scoring floors  |  Team B base X [32,48]
--   raised platform (5 high) with a 5-12-13 ramp and a climbable south face
--   free-standing paint wall at Z = -20 (both faces climbable) | neutral wall | thin cover | canopy
--   spawn screens at X = +-30 blocking opposing spawn sightlines; perimeter walls; out-of-bounds volume below

local PaintLab = {}

PaintLab.MapId = "paint_lab"
PaintLab.MapVersion = 5
PaintLab.FloorY = 100

local Y = PaintLab.FloorY

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color or Color3.fromRGB(150, 150, 155)
	p.Parent = parent
	return p
end

local function surface(parent: Instance, id: string, size: Vector3, cf: CFrame, face: string, kind: string, scoreable: boolean, climbable: boolean, initialOwner: number?): Part
	local p = part(parent, id, size, cf, if kind == "Wall" then Color3.fromRGB(205, 205, 210) else Color3.fromRGB(225, 225, 228))
	p:SetAttribute("SurfaceId", id)
	p:SetAttribute("Face", face)
	p:SetAttribute("SurfaceKind", kind)
	p:SetAttribute("Scoreable", scoreable)
	p:SetAttribute("Climbable", climbable)
	if initialOwner then
		p:SetAttribute("InitialOwner", initialOwner)
	end
	return p
end

function PaintLab.build(): (Model, Model)
	local model = Instance.new("Model")
	model.Name = "paint_lab"
	model:SetAttribute("MapId", PaintLab.MapId)
	model:SetAttribute("MapVersion", PaintLab.MapVersion)
	model:SetAttribute("ContractVersion", 1)
	model:SetAttribute("DisplayName", "Paint Lab (fixture)")
	model:SetAttribute("IsFixture", true)
	model:SetAttribute("Origin", Vector3.new(0, Y, 0))

	local folders = {}
	for _, name in { "Geometry", "PaintSurfaces", "Spawns", "Volumes", "Markers", "Decor" } do
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = model
		folders[name] = f
	end
	local G, S = folders.Geometry, folders.PaintSurfaces

	-- Scoring floors (2 thick, top at Y).
	local fy = Y - 1
	surface(S, "floor_center", Vector3.new(64, 2, 64), CFrame.new(0, fy, 0), "Top", "Floor", true, false)
	for _, side in { -1, 1 } do
		local key = if side < 0 then "A" else "B"
		surface(S, "floor_" .. key .. "_north", Vector3.new(16, 2, 20), CFrame.new(40 * side, fy, 22), "Top", "Floor", true, false)
		surface(S, "floor_" .. key .. "_south", Vector3.new(16, 2, 20), CFrame.new(40 * side, fy, -22), "Top", "Floor", true, false)
		-- protected base floor: displays team colour, never scores
		surface(S, "base_" .. key, Vector3.new(16, 2, 24), CFrame.new(40 * side, fy, 0), "Top", "Base", false, false, if side < 0 then 1 else 2)
		-- spawn screen blocking the opposing-spawn sightline; exits on both sides of it
		part(G, "spawn_screen_" .. key, Vector3.new(2, 8, 12), CFrame.new(30 * side, Y + 4, 0))
	end

	-- Raised platform (5 high) with paintable top and climbable south face.
	part(G, "platform_block", Vector3.new(12, 5, 12), CFrame.new(0, Y + 2.5, 20))
	surface(S, "platform_top", Vector3.new(12, 1, 12), CFrame.new(0, Y + 4.5, 20), "Top", "Floor", true, false)
	surface(S, "platform_climb_south", Vector3.new(12, 5, 0.2), CFrame.new(0, Y + 2.5, 13.9), "Front", "Wall", false, true)

	-- 5-12-13 ramp rising toward -X onto the platform's east edge (22.6 degrees, under the 30-degree limit).
	local theta = math.atan2(5, 12)
	local rot = CFrame.Angles(0, 0, -theta)
	local up = rot.UpVector
	local topCenter = Vector3.new(12, Y + 2.5, 20)
	surface(S, "ramp_east", Vector3.new(13, 1, 8), CFrame.new(topCenter - up * 0.5) * rot, "Top", "Ramp", true, false)
	-- Solid fill under the ramp so the floor beneath is inaccessible and excluded (GDD 09.1: no hidden scoring floor).
	-- Wedge: low edge faces +X (LookVector), high edge toward the platform; kept just under the ramp slab.
	local fill = Instance.new("WedgePart")
	fill.Name = "ramp_fill"
	fill.Anchored = true
	fill.Size = Vector3.new(8, 4.6, 12)
	fill.CFrame = CFrame.fromMatrix(Vector3.new(12, Y + 2.3, 20), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0))
	fill.Color = Color3.fromRGB(150, 150, 155)
	fill.Parent = G

	-- Free-standing paint wall, both faces climbable (paintable surface behind a paintable surface).
	-- (Edges sit on integer coordinates so floor-cell centres are never exactly on a face.)
	part(G, "paint_wall_core", Vector3.new(16, 10, 1.6), CFrame.new(0, Y + 5, -20))
	surface(S, "paint_wall_north", Vector3.new(16, 10, 0.2), CFrame.new(0, Y + 5, -19.1), "Back", "Wall", false, true)
	surface(S, "paint_wall_south", Vector3.new(16, 10, 0.2), CFrame.new(0, Y + 5, -20.9), "Front", "Wall", false, true)

	-- Neutral (non-paintable) wall, thin cover panel and a canopy on posts.
	part(G, "neutral_wall", Vector3.new(2, 8, 10), CFrame.new(-16, Y + 4, -10), Color3.fromRGB(90, 90, 100))
	part(G, "thin_cover", Vector3.new(0.5, 7, 8), CFrame.new(16, Y + 3.5, -10), Color3.fromRGB(90, 90, 100))
	part(G, "canopy_roof", Vector3.new(12, 1, 12), CFrame.new(-16, Y + 10.5, 18), Color3.fromRGB(70, 110, 90))
	for _, dx in { -5.5, 5.5 } do
		for _, dz in { -5.5, 5.5 } do
			part(G, "canopy_post", Vector3.new(1, 10, 1), CFrame.new(-16 + dx, Y + 5, 18 + dz), Color3.fromRGB(70, 110, 90))
		end
	end

	-- Perimeter walls (visible barriers, GDD 09.1).
	part(G, "perimeter_n", Vector3.new(98, 12, 1), CFrame.new(0, Y + 6, 32.5), Color3.fromRGB(60, 60, 70))
	part(G, "perimeter_s", Vector3.new(98, 12, 1), CFrame.new(0, Y + 6, -32.5), Color3.fromRGB(60, 60, 70))
	part(G, "perimeter_w", Vector3.new(1, 12, 64), CFrame.new(-48.5, Y + 6, 0), Color3.fromRGB(60, 60, 70))
	part(G, "perimeter_e", Vector3.new(1, 12, 64), CFrame.new(48.5, Y + 6, 0), Color3.fromRGB(60, 60, 70))

	-- Spawns: four per side, 8 studs apart, facing the centre.
	for _, side in { -1, 1 } do
		local key = if side < 0 then "A" else "B"
		local n = 0
		for _, x in { 44, 36 } do
			for _, z in { -4, 4 } do
				n += 1
				local pos = Vector3.new(x * side, Y + 0.1, z)
				local marker = part(folders.Spawns, key .. n, Vector3.new(2, 0.2, 2), CFrame.lookAt(pos, pos + Vector3.new(-side, 0, 0)))
				marker.Transparency = 0.6
				marker.CanCollide = false
				marker:SetAttribute("Team", key)
			end
		end
		local vol = part(folders.Volumes, "base_" .. key, Vector3.new(16, 12, 24), CFrame.new(40 * side, Y + 6, 0))
		vol.Transparency = 1
		vol.CanCollide = false
		vol:SetAttribute("VolumeKind", "ProtectedBase")
		vol:SetAttribute("Team", key)
	end
	local oob = part(folders.Volumes, "out_of_bounds", Vector3.new(600, 40, 600), CFrame.new(0, Y - 40, 0))
	oob.Transparency = 1
	oob.CanCollide = false
	oob:SetAttribute("VolumeKind", "OutOfBounds")

	local staging = part(folders.Markers, "StagingReturn", Vector3.new(2, 0.2, 2), CFrame.new(0, Y + 0.1, 200))
	staging.Transparency = 1
	staging.CanCollide = false

	-- Stationary damage capsules (test targets) on team B's side of the centre.
	local targets = Instance.new("Folder")
	targets.Name = "PracticeTargets"
	targets.Parent = folders.Markers
	for k, pos in { Vector3.new(10, Y, -4), Vector3.new(10, Y, 4), Vector3.new(24, Y, 20) } do
		local t = part(targets, "Target" .. k, Vector3.new(2.8, 5.5, 2.8), CFrame.new(pos + Vector3.new(0, 2.75, 0)), Color3.fromRGB(255, 200, 60))
		t.Shape = Enum.PartType.Cylinder
		t.CFrame = CFrame.new(pos + Vector3.new(0, 2.75, 0)) * CFrame.Angles(0, 0, math.rad(90))
		t.Size = Vector3.new(5.5, 2.8, 2.8)
		t.CanCollide = false
		t.CanQuery = false
		t:SetAttribute("TargetTeam", "B")
		t:SetAttribute("Feet", pos)
	end

	-- Safe staging platform (outside the arena; separate model).
	local stagingModel = Instance.new("Model")
	stagingModel.Name = "ColorClashStaging"
	stagingModel:SetAttribute("IsFixture", true)
	part(stagingModel, "staging_floor", Vector3.new(40, 2, 40), CFrame.new(0, Y - 1, 200), Color3.fromRGB(200, 205, 215))
	local stagingSpawn = part(stagingModel, "StagingSpawn", Vector3.new(4, 0.2, 4), CFrame.new(0, Y + 0.1, 200))
	stagingSpawn.Transparency = 1
	stagingSpawn.CanCollide = false
	stagingSpawn.CanQuery = false
	return model, stagingModel
end

return PaintLab
