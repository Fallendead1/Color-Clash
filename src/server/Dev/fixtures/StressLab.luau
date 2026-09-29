--!strict
-- stress_lab: ENGINEERING FIXTURE at the maximum paint budget (GDD 09.1, 09.4 "duplicate at maximum surface budgets").
-- 5 floor patches of 100x100 = 50,000 scoring cells and 4 wall patches of 100x40 = 16,000 non-scoring cells, with the
-- minimum contract furniture (bases, spawns, volumes, staging marker). Used only for PAINT-08 / PERF-01 benchmarks.

local StressLab = {}

StressLab.MapId = "stress_lab"
StressLab.MapVersion = 1

local Y = 300

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.fromRGB(215, 215, 220)
	p.Parent = parent
	return p
end

function StressLab.build(): Model
	local model = Instance.new("Model")
	model.Name = "stress_lab"
	model:SetAttribute("MapId", StressLab.MapId)
	model:SetAttribute("MapVersion", StressLab.MapVersion)
	model:SetAttribute("ContractVersion", 1)
	model:SetAttribute("DisplayName", "Stress Lab (fixture)")
	model:SetAttribute("IsFixture", true)
	local f = {}
	for _, name in { "Geometry", "PaintSurfaces", "Spawns", "Volumes", "Markers", "Decor" } do
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = model
		f[name] = folder
	end
	-- five 100x100 scoring floors in a row along X (x from -250 to 250), top at Y
	for k = 1, 5 do
		local cx = -300 + k * 100
		local p = part(f.PaintSurfaces, "floor" .. k, Vector3.new(100, 2, 100), CFrame.new(cx, Y - 1, 0))
		p:SetAttribute("SurfaceId", "stress_floor_" .. k)
		p:SetAttribute("Face", "Top")
		p:SetAttribute("SurfaceKind", "Floor")
		p:SetAttribute("Scoreable", true)
		p:SetAttribute("Climbable", false)
	end
	-- four 100x40 walls along the north edge, facing -Z (toward the floors)
	for k = 1, 4 do
		local cx = -250 + k * 100
		local w = part(f.PaintSurfaces, "wall" .. k, Vector3.new(100, 40, 1), CFrame.new(cx, Y + 20, 51.5))
		w:SetAttribute("SurfaceId", "stress_wall_" .. k)
		w:SetAttribute("Face", "Front")
		w:SetAttribute("SurfaceKind", "Wall")
		w:SetAttribute("Scoreable", false)
		w:SetAttribute("Climbable", false)
	end
	-- bases: small non-painted pads at each end (outside the scoring floors)
	for _, side in { -1, 1 } do
		local key = if side < 0 then "A" else "B"
		part(f.Geometry, "pad_" .. key, Vector3.new(20, 2, 30), CFrame.new(side * 262, Y - 1, 0))
		local vol = part(f.Volumes, "base_" .. key, Vector3.new(20, 12, 30), CFrame.new(side * 262, Y + 6, 0))
		vol.CanCollide = false
		vol.Transparency = 1
		vol:SetAttribute("VolumeKind", "ProtectedBase")
		vol:SetAttribute("Team", key)
		part(f.Geometry, "screen_" .. key, Vector3.new(2, 10, 20), CFrame.new(side * 250, Y + 5, 0))
		local n = 0
		for _, x in { 266, 258 } do
			for _, z in { -4, 4 } do
				n += 1
				local s = part(f.Spawns, key .. n, Vector3.new(2, 0.2, 2), CFrame.new(side * x, Y + 0.1, z))
				s.CanCollide = false
				s:SetAttribute("Team", key)
			end
		end
	end
	local oob = part(f.Volumes, "oob", Vector3.new(1000, 40, 1000), CFrame.new(0, Y - 60, 0))
	oob.CanCollide = false
	oob.Transparency = 1
	oob:SetAttribute("VolumeKind", "OutOfBounds")
	local st = part(f.Markers, "StagingReturn", Vector3.new(2, 0.2, 2), CFrame.new(0, 100.1, 200))
	st.CanCollide = false
	st.Transparency = 1
	return model
end

return StressLab
