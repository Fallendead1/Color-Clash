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

	local staging = m.Markers:FindFirstChild("StagingReturn")
	if #errors > 0 then
		return nil, errors
	end
	assert(grid)
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

return MapLoader
