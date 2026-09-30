--!strict
-- DEV ONLY contract fixtures for the two manifest slots (GDD 09.4: code-generated test objects, not authored maps).
-- Plain blockout-scale parts with each slot's footprint, base centres, spawns, a spawn screen, mirrored cover and
-- raised platforms, so the loader contract, slot validation and the 20-round rotation (FLOW-14) run before Codex
-- delivers Switchyard and Canopy Courts. Every result on these maps is reported as "contract fixture".

local MapManifest = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.MapManifest)

local ContractMap = {}

local Y = 100

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

function ContractMap.build(slotId: string): Model
	local slot = MapManifest.Slots[slotId]
	assert(slot, "unknown slot " .. slotId)
	local FX, FZ, BX = slot.Footprint.X / 2, slot.Footprint.Z / 2, slot.BaseCenterX
	local inner = BX - 12 -- scoring floor half-width; base strips run from inner to FX

	local model = Instance.new("Model")
	model.Name = slotId .. "_contract_fixture"
	model:SetAttribute("MapId", slotId)
	model:SetAttribute("MapVersion", 1)
	model:SetAttribute("ContractVersion", 1)
	model:SetAttribute("DisplayName", slot.DisplayName .. " (contract fixture)")
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
	local fy = Y - 1

	for _, side in { -1, 1 } do
		local key = if side < 0 then "A" else "B"
		-- scoring half floor (mirror halves: exact parity)
		surface(S, "floor_" .. key, Vector3.new(inner, 2, FZ * 2), CFrame.new(side * inner / 2, fy, 0), "Top", "Floor", true, false)
		-- base strip: displays team colour, never scores
		surface(S, "base_" .. key, Vector3.new(FX - inner, 2, FZ * 2), CFrame.new(side * (inner + FX) / 2, fy, 0), "Top", "Base", false, false, if side < 0 then 1 else 2)
		-- spawn screen (two exits around it) and centre cover island
		part(G, "spawn_screen_" .. key, Vector3.new(2, 10, 24), CFrame.new(side * (BX - 16), Y + 5, 0))
		part(G, "center_cover_" .. key, Vector3.new(4, 8, 12), CFrame.new(side * 12, Y + 4, 0))
		-- raised side platform with a scoring top and a climbable face toward the centre; solid down to the floor
		local px = side * 40
		part(G, "platform_" .. key, Vector3.new(12, 8, 12), CFrame.new(px, Y + 4, FZ * 0.55))
		surface(S, "platform_top_" .. key, Vector3.new(12, 1, 12), CFrame.new(px, Y + 7.5, FZ * 0.55), "Top", "Floor", true, false)
		if side < 0 then
			surface(S, "platform_climb_" .. key, Vector3.new(0.2, 8, 12), CFrame.new(px + 6.1, Y + 4, FZ * 0.55), "Right", "Wall", false, true)
		else
			surface(S, "platform_climb_" .. key, Vector3.new(0.2, 8, 12), CFrame.new(px - 6.1, Y + 4, FZ * 0.55), "Left", "Wall", false, true)
		end
		-- spawns (8 studs apart) and the protected base volume
		local n = 0
		for _, dx in { 4, -4 } do
			for _, z in { -4, 4 } do
				n += 1
				local pos = Vector3.new(side * (BX + dx), Y + 0.1, z)
				local marker = part(folders.Spawns, key .. n, Vector3.new(2, 0.2, 2), CFrame.lookAt(pos, pos + Vector3.new(-side, 0, 0)))
				marker.Transparency = 0.6
				marker.CanCollide = false
				marker:SetAttribute("Team", key)
			end
		end
		local vol = part(folders.Volumes, "base_" .. key, Vector3.new(24, 12, 40), CFrame.new(side * BX, Y + 6, 0))
		vol.Transparency = 1
		vol.CanCollide = false
		vol:SetAttribute("VolumeKind", "ProtectedBase")
		vol:SetAttribute("Team", key)
	end
	if slotId == "canopy_courts" then
		-- non-scoring overhead canopy on posts (blocks Paintstorm); not most of the map
		part(G, "canopy_roof", Vector3.new(16, 1, 16), CFrame.new(0, Y + 12.5, -FZ * 0.5), Color3.fromRGB(70, 110, 90))
		for _, dx in { -7.5, 7.5 } do
			for _, dz in { -7.5, 7.5 } do
				part(G, "canopy_post", Vector3.new(1, 12, 1), CFrame.new(dx, Y + 6, -FZ * 0.5 + dz), Color3.fromRGB(70, 110, 90))
			end
		end
	end
	-- perimeter (visible barriers)
	part(G, "perimeter_n", Vector3.new(FX * 2 + 2, 12, 1), CFrame.new(0, Y + 6, FZ + 0.5), Color3.fromRGB(60, 60, 70))
	part(G, "perimeter_s", Vector3.new(FX * 2 + 2, 12, 1), CFrame.new(0, Y + 6, -FZ - 0.5), Color3.fromRGB(60, 60, 70))
	part(G, "perimeter_w", Vector3.new(1, 12, FZ * 2), CFrame.new(-FX - 0.5, Y + 6, 0), Color3.fromRGB(60, 60, 70))
	part(G, "perimeter_e", Vector3.new(1, 12, FZ * 2), CFrame.new(FX + 0.5, Y + 6, 0), Color3.fromRGB(60, 60, 70))
	local oob = part(folders.Volumes, "out_of_bounds", Vector3.new(800, 40, 800), CFrame.new(0, Y - 40, 0))
	oob.Transparency = 1
	oob.CanCollide = false
	oob:SetAttribute("VolumeKind", "OutOfBounds")
	local staging = part(folders.Markers, "StagingReturn", Vector3.new(2, 0.2, 2), CFrame.new(0, Y + 0.1, 200))
	staging.Transparency = 1
	staging.CanCollide = false
	return model
end

return ContractMap
