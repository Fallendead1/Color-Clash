--!strict
-- Tactical map data (GDD 08.4, 12.1 Map, MAP-01). Pure: projects the SAME paint grid the client already mirrors onto
-- a top-down raster, so the map shows exactly the scoreable surfaces and ownership (no separate map model, no hidden
-- second layer). MapLoader rejects stacked scoring surfaces, so each raster pixel is fed by one height layer; the
-- projection reports any pixel that mixes layers so a test can prove it.
--
-- Launch selection is also pure: living teammates (never self, never an enemy) plus "Base".

local Surface = require("./Surface")

local TacticalMap = {}

export type Projection = {
	minX: number,
	minZ: number,
	pixel: number,
	w: number,
	h: number,
	-- per pixel (index = z * w + x + 1): legal scoring cells per owner, packed as { n0, n1, n2 }
	counts: { [number]: { number } },
	totals: { [number]: number },
	scoringCells: number,
	stackedPixels: number, -- pixels fed by scoring cells more than `layerGap` studs apart vertically
}

local LAYER_GAP = 4

-- Rasterises every scoreable patch of `grid` (a PaintGrid) at `pixel` studs per pixel.
function TacticalMap.project(grid: any, pixel: number): Projection
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	for _, patch in grid.patches do
		if patch.def.Scoreable then
			minX = math.min(minX, patch.minB.X)
			minZ = math.min(minZ, patch.minB.Z)
			maxX = math.max(maxX, patch.maxB.X)
			maxZ = math.max(maxZ, patch.maxB.Z)
		end
	end
	local proj: Projection = {
		minX = if minX == math.huge then 0 else minX,
		minZ = if minZ == math.huge then 0 else minZ,
		pixel = pixel,
		w = 0,
		h = 0,
		counts = {},
		totals = { [0] = 0, [1] = 0, [2] = 0 },
		scoringCells = 0,
		stackedPixels = 0,
	}
	if minX == math.huge then
		return proj
	end
	proj.w = math.max(1, math.ceil((maxX - minX) / pixel))
	proj.h = math.max(1, math.ceil((maxZ - minZ) / pixel))
	local heights: { [number]: { number } } = {}
	for _, patch in grid.patches do
		local def = patch.def
		if not def.Scoreable then
			continue
		end
		for cell = 0, patch.cellCount - 1 do
			if not Surface.isLegal(def, cell) then
				continue
			end
			local i, j = Surface.cellCoords(def, cell)
			local c = Surface.cellCenter(def, i, j)
			local px = math.clamp(math.floor((c.X - proj.minX) / pixel), 0, proj.w - 1)
			local pz = math.clamp(math.floor((c.Z - proj.minZ) / pixel), 0, proj.h - 1)
			local idx = pz * proj.w + px + 1
			local owner = buffer.readu8(patch.owner, cell)
			local slot = proj.counts[idx]
			if not slot then
				slot = { 0, 0, 0 }
				proj.counts[idx] = slot
				heights[idx] = { c.Y, c.Y }
			end
			slot[owner + 1] += 1
			local hr = heights[idx]
			hr[1] = math.min(hr[1], c.Y)
			hr[2] = math.max(hr[2], c.Y)
			proj.totals[owner] += 1
			proj.scoringCells += 1
		end
	end
	for _, hr in heights do
		if hr[2] - hr[1] > LAYER_GAP then
			proj.stackedPixels += 1
		end
	end
	return proj
end

-- Majority owner of a pixel (0 neutral, 1, 2) or nil when no scoring floor projects there.
function TacticalMap.pixelOwner(proj: Projection, x: number, z: number): number?
	local slot = proj.counts[z * proj.w + x + 1]
	if not slot then
		return nil
	end
	if slot[2] >= slot[1] and slot[2] >= slot[3] and slot[2] > 0 then
		return 1
	elseif slot[3] >= slot[1] and slot[3] > 0 then
		return 2
	end
	return 0
end

-- Normalised [0,1] map coordinates of a world position (for teammate / marker icons).
function TacticalMap.toMap(proj: Projection, x: number, z: number): (number, number)
	local u = (x - proj.minX) / math.max(1e-6, proj.w * proj.pixel)
	local v = (z - proj.minZ) / math.max(1e-6, proj.h * proj.pixel)
	return math.clamp(u, 0, 1), math.clamp(v, 0, 1)
end

export type Candidate = { id: number, team: number, alive: boolean, name: string }
export type Target = { key: number | string, label: string }

-- Launch choices for `selfId` on `selfTeam`: "Base" first, then living teammates sorted by name.
function TacticalMap.launchTargets(selfId: number, selfTeam: number, candidates: { Candidate }): { Target }
	local list: { Target } = { { key = "Base", label = "Base" } }
	local mates = {}
	for _, c in candidates do
		if c.id ~= selfId and c.team == selfTeam and selfTeam ~= 0 and c.alive then
			table.insert(mates, c)
		end
	end
	table.sort(mates, function(a, b)
		return a.name < b.name
	end)
	for _, c in mates do
		table.insert(list, { key = c.id, label = c.name })
	end
	return list
end

return TacticalMap
