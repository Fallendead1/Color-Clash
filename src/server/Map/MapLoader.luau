--!strict
-- Loads and validates a map Model against the map content contract (GDD 09.5, docs/MAP_CONTRACT.md).
-- Produces a runtime descriptor: validated surface definitions with collision-derived legal-cell masks, spawns,
-- protected-base and out-of-bounds volumes, and the raycast include list. Invalid content is rejected with a precise
-- report before a match can start (MAP-02/03/04).

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Surface = require(Shared.Paint.Surface)
local PaintGrid = require(Shared.Paint.PaintGrid)
local GameConfig = require(Shared.Config.GameConfig)
local MapManifest = require(Shared.Config.MapManifest)

local MapLoader = {}

export type Volume = { cframe: CFrame, size: Vector3, team: number?, kind: string, part: BasePart }

export type Descriptor = {
	mapId: string,
	mapVersion: number,
	displayName: string,
	isFixture: boolean,
	model: Model,
	defs: { Surface.SurfaceDef },
	surfaceParts: { [string]: BasePart },
	spawns: { [number]: { CFrame } },
	baseVolumes: { [number]: Volume },
	outOfBounds: { Volume },
	stagingReturn: CFrame?,
	raycastInclude: { Instance },
	manifest: { scoringCells: number, wallCells: number, patches: number, maskedCells: number },
	warnings: { string },
}

local REQUIRED_FOLDERS = { "Geometry", "PaintSurfaces", "Spawns", "Volumes", "Markers", "Decor" }
local FACES = { Top = true, Front = true, Back = true, Left = true, Right = true }
local KINDS = { Floor = true, Ramp = true, Wall = true, Base = true }
local TEAM_BY_KEY = { A = 1, B = 2 }

local function v3(v: Vector3): vector
	return vector.create(v.X, v.Y, v.Z)
end

function MapLoader.pointInVolume(vol: Volume, p: Vector3): boolean
	local lp = vol.cframe:PointToObjectSpace(p)
	local h = vol.size / 2
	return math.abs(lp.X) <= h.X and math.abs(lp.Y) <= h.Y and math.abs(lp.Z) <= h.Z
end

-- Structural validation that needs no Workspace (fast, used by content tests too).
function MapLoader.validateStructure(model: Instance): { string }
	local errors = {}
	if not model:IsA("Model") then
		table.insert(errors, "root is not a Model")
		return errors
	end
	if type(model:GetAttribute("MapId")) ~= "string" then
		table.insert(errors, "missing string attribute MapId")
	end
	if type(model:GetAttribute("MapVersion")) ~= "number" then
		table.insert(errors, "missing number attribute MapVersion")
	end
	if model:GetAttribute("ContractVersion") ~= 1 then
		table.insert(errors, "ContractVersion must be 1")
	end
	for _, name in REQUIRED_FOLDERS do
		if not model:FindFirstChild(name) then
			table.insert(errors, "missing folder " .. name)
		end
	end
	if #errors > 0 then
		return errors
	end
	local seen = {}
	for _, part in (model :: any).PaintSurfaces:GetChildren() do
		if not part:IsA("BasePart") then
			table.insert(errors, "PaintSurfaces child " .. part.Name .. " is not a BasePart")
			continue
		end
		local id = part:GetAttribute("SurfaceId")
		if type(id) ~= "string" or #id == 0 then
			table.insert(errors, "surface part " .. part:GetFullName() .. " missing SurfaceId")
		elseif seen[id] then
			table.insert(errors, "duplicate SurfaceId " .. id)
		else
			seen[id] = true
		end
		if not FACES[part:GetAttribute("Face") or ""] then
			table.insert(errors, "surface " .. tostring(id) .. " has invalid Face")
		end
		if not KINDS[part:GetAttribute("SurfaceKind") or ""] then
			table.insert(errors, "surface " .. tostring(id) .. " has invalid SurfaceKind")
		end
		if type(part:GetAttribute("Scoreable")) ~= "boolean" or type(part:GetAttribute("Climbable")) ~= "boolean" then
			table.insert(errors, "surface " .. tostring(id) .. " needs boolean Scoreable and Climbable")
		end
		if not part.Anchored then
			table.insert(errors, "surface " .. tostring(id) .. " is not anchored")
		end
	end
	local counts = { [1] = 0, [2] = 0 }
	for _, s in (model :: any).Spawns:GetChildren() do
		local team = TEAM_BY_KEY[s:GetAttribute("Team") or ""]
		if not s:IsA("BasePart") or not team then
			table.insert(errors, "spawn " .. s.Name .. " must be a BasePart with Team A or B")
		else
			counts[team] += 1
		end
	end
	if counts[1] < 4 or counts[2] < 4 then
		table.insert(errors, string.format("need 4 spawns per team, found A=%d B=%d", counts[1], counts[2]))
	end
	local bases = { [1] = 0, [2] = 0 }
	local oob = 0
	for _, v in (model :: any).Volumes:GetChildren() do
		local kind = v:GetAttribute("VolumeKind")
		if not v:IsA("BasePart") then
			table.insert(errors, "volume " .. v.Name .. " is not a BasePart")
		elseif kind == "ProtectedBase" then
			local team = TEAM_BY_KEY[v:GetAttribute("Team") or ""]
			if team then
				bases[team] += 1
			else
				table.insert(errors, "ProtectedBase " .. v.Name .. " needs Team A or B")
			end
		elseif kind == "OutOfBounds" then
			oob += 1
		elseif kind ~= "Boundary" then
			table.insert(errors, "volume " .. v.Name .. " has unknown VolumeKind " .. tostring(kind))
		end
	end
	if bases[1] ~= 1 or bases[2] ~= 1 then
		table.insert(errors, "need exactly one ProtectedBase volume per team")
	end
	if oob < 1 then
		table.insert(errors, "need at least one OutOfBounds volume")
	end
	if not (model :: any).Markers:FindFirstChild("StagingReturn") then
		table.insert(errors, "missing Markers.StagingReturn")
	end
	return errors
end

-- Full load: the model must already be parented under Workspace so collision queries work.
-- Returns descriptor or nil + list of errors.
function MapLoader.load(model: Model, isFixture: boolean): (Descriptor?, { string })
	local errors = MapLoader.validateStructure(model)
	if #errors > 0 then
		return nil, errors
	end
	assert(model:IsDescendantOf(Workspace), "map must be in Workspace for validation")
	local m = model :: any
	local warnings = {}

	local include = { m.Geometry, m.PaintSurfaces }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	params.IgnoreWater = true

	local baseVolumes: { [number]: Volume } = {}
	local outOfBounds: { Volume } = {}
	for _, v in m.Volumes:GetChildren() do
		local vol: Volume = { cframe = v.CFrame, size = v.Size, kind = v:GetAttribute("VolumeKind"), team = TEAM_BY_KEY[v:GetAttribute("Team") or ""], part = v }
		if vol.kind == "ProtectedBase" then
			baseVolumes[vol.team :: number] = vol
		elseif vol.kind == "OutOfBounds" then
			table.insert(outOfBounds, vol)
		end
		v.CanQuery = false
		v.CanTouch = false
	end

	-- Surfaces with collision-derived masks. The probe spans 0.1..0.9 studs in front of a cell (0.6 x 0.6 x 0.8).
	local probe = Instance.new("Part")
	probe.Name = "ColorClashMaskProbe"
	probe.Anchored = true
	probe.CanCollide = false
	probe.CanQuery = false
	probe.CanTouch = false
	probe.Transparency = 1
	probe.Size = Vector3.new(0.6, 0.6, 0.8)
	probe.Parent = Workspace
	local probeParams = OverlapParams.new()
	probeParams.FilterType = Enum.RaycastFilterType.Include
	probeParams.FilterDescendantsInstances = include
	local defs: { Surface.SurfaceDef } = {}
	local surfaceParts: { [string]: BasePart } = {}
	local masked = 0
	local function inOutOfBounds(p: Vector3): boolean
		for _, vol in outOfBounds do
			if MapLoader.pointInVolume(vol, p) then
				return true
			end
		end
		return false
	end
	for _, part in m.PaintSurfaces:GetChildren() do
		local cf = part.CFrame
		local def = Surface.fromBox(
			part:GetAttribute("SurfaceId"),
			v3(cf.Position),
			v3(part.Size),
			v3(cf.RightVector),
			v3(cf.UpVector),
			v3(cf.LookVector),
			part:GetAttribute("Face"),
			{
				Scoreable = part:GetAttribute("Scoreable"),
				Climbable = part:GetAttribute("Climbable"),
				Kind = part:GetAttribute("SurfaceKind"),
				InitialOwner = part:GetAttribute("InitialOwner"),
			}
		)
		local ok, err = Surface.validate(def)
		if not ok then
			table.insert(errors, tostring(err))
			continue
		end
		-- face dimensions must land on the one-stud grid (no silent denominator change, GDD 03.3)
		local face = part:GetAttribute("Face")
		local dimU, dimV
		if face == "Top" then
			dimU, dimV = part.Size.X, part.Size.Z
		elseif face == "Left" or face == "Right" then
			dimU, dimV = part.Size.Z, part.Size.Y
		else
			dimU, dimV = part.Size.X, part.Size.Y
		end
		if math.abs(dimU - math.round(dimU)) > 0.01 or math.abs(dimV - math.round(dimV)) > 0.01 then
			table.insert(errors, string.format("surface %s face %.3fx%.3f is not on the one-stud grid", def.SurfaceId, dimU, dimV))
			continue
		end
		local n = def.SizeU * def.SizeV
		local mask = buffer.create(n)
		local legal = 0
		local oobCells = 0
		-- A cell is legal when the space just in front of it is free of map geometry. Raycasts cannot see a part
		-- that contains their start point, so use a precise overlap probe instead (GDD 09.5 mask validation).
		local probeCF = CFrame.fromMatrix(
			Vector3.zero,
			Vector3.new(def.U.X, def.U.Y, def.U.Z),
			Vector3.new(def.V.X, def.V.Y, def.V.Z)
		)
		for j = 0, def.SizeV - 1 do
			for i = 0, def.SizeU - 1 do
				local c = Surface.cellCenter(def, i, j)
				local at = c + def.Normal * 0.5
				probe.CFrame = probeCF + Vector3.new(at.X, at.Y, at.Z)
				local isLegal = #Workspace:GetPartsInPart(probe, probeParams) == 0
				if isLegal and def.Scoreable then
					-- protected spawn interiors never score
					local p = Vector3.new(c.X, c.Y + 0.5, c.Z)
					for _, vol in baseVolumes do
						if MapLoader.pointInVolume(vol, p) then
							isLegal = false
						end
					end
				end
				if isLegal and inOutOfBounds(Vector3.new(c.X, c.Y, c.Z) + Vector3.new(def.Normal.X, def.Normal.Y, def.Normal.Z) * 0.5) then
					oobCells += 1 -- paint that can never be reached legally (hidden score / escape route, MAP-04)
				end
				if isLegal then
					buffer.writeu8(mask, j * def.SizeU + i, 1)
					legal += 1
				else
					masked += 1
				end
			end
		end
		if legal == 0 then
			table.insert(warnings, "surface " .. def.SurfaceId .. " has no legal cells")
		end
		if oobCells > 0 then
			table.insert(errors, string.format("surface %s has %d legal cells inside an OutOfBounds volume", def.SurfaceId, oobCells))
		end
		-- a climbable face must not top out into an out-of-bounds area (no mantle onto an OOB roof, MAP-04)
		if def.Climbable and def.Normal.Y < 0.5 then
			local topY = -math.huge
			for j = 0, def.SizeV - 1 do
				for i = 0, def.SizeU - 1 do
					topY = math.max(topY, Surface.cellCenter(def, i, j).Y)
				end
			end
			local bad = false
			for j = 0, def.SizeV - 1 do
				for i = 0, def.SizeU - 1 do
					local c = Surface.cellCenter(def, i, j)
					if not bad and c.Y > topY - 0.01 then
						local over = Vector3.new(c.X, topY + 1.1, c.Z) - Vector3.new(def.Normal.X, 0, def.Normal.Z) * 1.0
						if inOutOfBounds(over) then
							bad = true
						end
					end
				end
			end
			if bad then
				table.insert(errors, "climbable surface " .. def.SurfaceId .. " tops out into an OutOfBounds volume")
			end
		end
		def.Mask = mask
		table.insert(defs, def)
		surfaceParts[def.SurfaceId] = part
	end
	probe:Destroy()

	-- No two scoring surfaces directly above one another in X/Z (GDD 09.1).
	local scoring = {}
	for _, d in defs do
		if d.Scoreable then
			table.insert(scoring, d)
		end
	end
	for a = 1, #scoring do
		local da = scoring[a]
		local minA, maxA = Surface.bounds(da, 0)
		for b = 1, #scoring do
			if a ~= b then
				local db = scoring[b]
				local minB, maxB = Surface.bounds(db, 0)
				if minA.X < maxB.X and maxA.X > minB.X and minA.Z < maxB.Z and maxA.Z > minB.Z then
					-- project a sample of A's legal cells vertically onto B's plane
					local stacked = false
					for j = 0, da.SizeV - 1 do
						for i = 0, da.SizeU - 1 do
							local k = j * da.SizeU + i
							if Surface.isLegal(da, k) then
								local c = Surface.cellCenter(da, i, j)
								local ny = db.Normal.Y
								local dist = vector.dot(c - db.Origin, db.Normal)
								local tUp = -dist / ny
								if math.abs(tUp) > 1.0 then
									local p = c + vector.create(0, tUp, 0)
									local bi, bj = Surface.locate(db, p, 0.01)
									if bi and bj and Surface.isLegal(db, bj * db.SizeU + bi) then
										stacked = true
										break
									end
								end
							end
						end
						if stacked then
							break
						end
					end
					if stacked then
						table.insert(errors, "scoring surfaces stacked in X/Z: " .. da.SurfaceId .. " / " .. db.SurfaceId)
					end
				end
			end
		end
	end

	-- Budgets and grid construction (also catches duplicate ids / invalid bases).
	local okGrid, gridErr = pcall(PaintGrid.new, defs, GameConfig.Paint)
	if not okGrid then
		table.insert(errors, tostring(gridErr))
	end
	local grid = if okGrid then gridErr else nil

	-- Spawns: inside own protected base, character clearance, no opposing sightline.
	local spawns: { [number]: { CFrame } } = { [1] = {}, [2] = {} }
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = include
	for _, s in m.Spawns:GetChildren() do
		local team = TEAM_BY_KEY[s:GetAttribute("Team")]
		local cf = s.CFrame
		table.insert(spawns[team], cf)
		s.CanCollide = false
		s.CanQuery = false
		s.CanTouch = false
		local base = baseVolumes[team]
		if not base or not MapLoader.pointInVolume(base, cf.Position + Vector3.new(0, 1, 0)) then
			table.insert(errors, "spawn " .. s.Name .. " is not inside its team's protected base")
		end
		if inOutOfBounds(cf.Position + Vector3.new(0, 1, 0)) then
			table.insert(errors, "spawn " .. s.Name .. " is inside an OutOfBounds volume")
		end
		local clearance = Workspace:GetPartBoundsInBox(cf + Vector3.new(0, 3.2, 0), Vector3.new(3, 5.5, 3), overlap)
		if #clearance > 0 then
			table.insert(errors, "spawn " .. s.Name .. " lacks character clearance (blocked by " .. clearance[1]:GetFullName() .. ")")
		end
	end
	for _, a in spawns[1] do
		for _, b in spawns[2] do
			local from = a.Position + Vector3.new(0, 4.5, 0)
			local to = b.Position + Vector3.new(0, 4.5, 0)
			if Workspace:Raycast(from, to - from, params) == nil then
				table.insert(errors, "opposing spawns have a direct sightline")
				break
			end
		end
	end
	for team = 1, 2 do
		local list = spawns[team]
		for i = 1, #list do
			for j = i + 1, #list do
				if (list[i].Position - list[j].Position).Magnitude < 7 - 1e-3 then
					table.insert(warnings, "team " .. team .. " spawns closer than 7 studs")
				end
			end
		end
	end

	-- Decor must never become a paint or damage target.
	for _, d in m.Decor:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = false
			d.CanTouch = false
		end
	end

	-- The map's own manifest (GDD 09.5): declared counts must match what the loader derives. Required for
	-- production maps; optional for code fixtures (tests set them to prove the check).
	if grid then
		local declared = {
			{ "ExpectedScoringCells", grid.totalScoringArea },
			{ "ExpectedWallCells", grid.totalWallCells },
			{ "ExpectedPatches", #defs },
		}
		for _, d in declared do
			local v = model:GetAttribute(d[1])
			if v == nil then
				if not isFixture then
					table.insert(errors, "manifest attribute " .. d[1] .. " missing (derived value " .. d[2] .. ")")
				end
			elseif v ~= d[2] then
				table.insert(errors, string.format("manifest %s = %s but the loader derives %d", d[1], tostring(v), d[2]))
			end
		end
	end

	local staging = m.Markers:FindFirstChild("StagingReturn")
	if #errors > 0 then
		return nil, errors
	end
	assert(grid, "grid missing after successful validation")
	return {
		mapId = model:GetAttribute("MapId"),
		mapVersion = model:GetAttribute("MapVersion"),
		displayName = model:GetAttribute("DisplayName") or model:GetAttribute("MapId"),
		isFixture = isFixture,
		model = model,
		defs = defs,
		surfaceParts = surfaceParts,
		spawns = spawns,
		baseVolumes = baseVolumes,
		outOfBounds = outOfBounds,
		stagingReturn = if staging and staging:IsA("BasePart") then staging.CFrame else nil,
		raycastInclude = include,
		manifest = {
			scoringCells = grid.totalScoringArea,
			wallCells = grid.totalWallCells,
			patches = #defs,
			maskedCells = masked,
		},
		warnings = warnings,
	},
		{}
end

-- Slot contract (GDD 09.2/09.3, MAP-03): the MapId names a manifest slot; footprint and base centres match it; the
-- two team halves (split at X = 0) have the same scoring area within tolerance. Returns a list of errors.
function MapLoader.validateSlot(desc: Descriptor): { string }
	local errors = {}
	local slot = MapManifest.Slots[desc.mapId]
	if not slot then
		table.insert(errors, "MapId " .. tostring(desc.mapId) .. " is not a manifest slot")
		return errors
	end
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, folder in desc.raycastInclude do
		for _, part in folder:GetDescendants() do
			if part:IsA("BasePart") then
				local h = part.Size / 2
				local cf = part.CFrame
				for _, sx in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local p = cf:PointToWorldSpace(Vector3.new(h.X * sx, 0, h.Z * sz))
						minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
						minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
					end
				end
			end
		end
	end
	local tol = MapManifest.FootprintTolerance
	local fx, fz = maxX - minX, maxZ - minZ
	if math.abs(fx - slot.Footprint.X) > slot.Footprint.X * tol or math.abs(fz - slot.Footprint.Z) > slot.Footprint.Z * tol then
		table.insert(errors, string.format("footprint %.0f x %.0f differs from slot %d x %d by more than %d%%", fx, fz, slot.Footprint.X, slot.Footprint.Z, tol * 100))
	end
	if math.abs((minX + maxX) / 2) > MapManifest.BaseCenterTolerance or math.abs((minZ + maxZ) / 2) > MapManifest.BaseCenterTolerance then
		table.insert(errors, "footprint is not centred on the world origin")
	end
	for team, sign in { [1] = -1, [2] = 1 } do
		local vol = desc.baseVolumes[team]
		if vol then
			local c = vol.cframe.Position
			if math.abs(c.X - sign * slot.BaseCenterX) > MapManifest.BaseCenterTolerance or math.abs(c.Z) > MapManifest.BaseCenterTolerance then
				table.insert(errors, string.format("team %s base centre (%.0f, %.0f) is not near X = %d, Z = 0", if team == 1 then "A" else "B", c.X, c.Z, sign * slot.BaseCenterX))
			end
		end
	end
	local half = { 0, 0 }
	for _, def in desc.defs do
		if def.Scoreable then
			for j = 0, def.SizeV - 1 do
				for i = 0, def.SizeU - 1 do
					if Surface.isLegal(def, j * def.SizeU + i) then
						local c = Surface.cellCenter(def, i, j)
						if c.X < -0.01 then
							half[1] += 1
						elseif c.X > 0.01 then
							half[2] += 1
						end
					end
				end
			end
		end
	end
	local larger = math.max(half[1], half[2], 1)
	if math.abs(half[1] - half[2]) / larger > MapManifest.SideParityTolerance then
		table.insert(errors, string.format("scoring area is not mirrored: A half %d cells, B half %d cells", half[1], half[2]))
	end
	return errors
end

return MapLoader
