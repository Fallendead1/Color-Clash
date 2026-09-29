--!strict
-- Authoritative paint ownership model (GDD 10.2, 10.3, 10.5). Pure: no Instances, no remotes.
-- The server owns one PaintGrid per loaded map; clients keep a mirror built from snapshots/deltas.
--
-- Ownership per legal cell: 0 = neutral, 1 = team A, 2 = team B. Illegal (masked) cells are not "neutral turf";
-- they are never counted and never change.
-- Cells are grouped into 16x16 chunks per patch (edge chunks padded). Each chunk has a monotonically increasing
-- version. A chunk payload carries the complete ownership of that chunk (2 bits per cell = 64 bytes), so a newer
-- version always supersedes older data and reordered/duplicated messages are harmless.
--
-- Invariant maintained incrementally: A_area + B_area + Neutral_area = TotalScoringArea.

local Surface = require("./Surface")

local PaintGrid = {}
PaintGrid.__index = PaintGrid

local CHUNK = 16
local CHUNK_CELLS = CHUNK * CHUNK
local CHUNK_BYTES = CHUNK_CELLS // 4 -- 2 bits per cell
local BUCKET = 32 -- spatial hash bucket size in studs

export type Patch = {
	index: number,
	def: Surface.SurfaceDef,
	owner: buffer,
	cellCount: number,
	legalCount: number,
	cellBase: number, -- global cell id of this patch's cell 0
	chunksU: number,
	chunksV: number,
	chunkBase: number, -- global chunk id of this patch's chunk 0
	counts: { [number]: number }, -- legal cells per owner (0,1,2)
	minB: vector,
	maxB: vector,
}

export type Change = {
	patch: number,
	cell: number,
	globalCell: number,
	old: number,
	new: number,
	scoreable: boolean,
}

export type StampOptions = {
	-- Returns true when `to` is visible from `from` (no blocking geometry). nil = no occlusion.
	isVisible: ((from: vector, to: vector) -> boolean)?,
	-- Stamp origin used for visibility tests (defaults to the stamp centre).
	origin: vector?,
	-- Restrict to surfaces whose normal has Y >= this (e.g. 0.5 for floors/ramps only).
	minNormalY: number?,
	-- Ignore surfaces whose normal has Y > this (e.g. walls only).
	maxNormalY: number?,
	-- Only surfaces facing the origin within this many studs behind the plane are considered.
	backTolerance: number?,
	-- Collect individual changes (for ultimate credit / tests). Counts are always updated.
	collect: boolean?,
}

export type StampResult = {
	changed: number,
	scoreableConverted: number, -- scoring cells converted from neutral/enemy to the painter's team
	changes: { Change }?,
}

export type Grid = typeof(setmetatable(
	{} :: {
		patches: { Patch },
		byId: { [string]: Patch },
		totals: { [number]: number }, -- scoring area per owner (0,1,2)
		totalScoringArea: number,
		totalWallCells: number,
		chunkCount: number,
		chunkVersion: { number },
		chunkPatch: { number },
		dirty: { [number]: boolean },
		dirtyCount: number,
		sequence: number,
		buckets: { [string]: { number } },
		frozen: boolean,
	},
	PaintGrid
))

local function bucketKey(x: number, y: number, z: number): string
	return x .. "," .. y .. "," .. z
end

-- Build a grid from validated surface definitions. Errors with a precise message on invalid content.
function PaintGrid.new(defs: { Surface.SurfaceDef }, limits: { MaxScoringCells: number?, MaxWallCells: number?, MaxPatches: number? }?): Grid
	local self = setmetatable({
		patches = {},
		byId = {},
		totals = { [0] = 0, [1] = 0, [2] = 0 },
		totalScoringArea = 0,
		totalWallCells = 0,
		chunkCount = 0,
		chunkVersion = {},
		chunkPatch = {},
		dirty = {},
		dirtyCount = 0,
		sequence = 0,
		buckets = {},
		frozen = false,
	}, PaintGrid)

	local lim = limits or {}
	if lim.MaxPatches and #defs > lim.MaxPatches then
		error(string.format("paint content error: %d patches exceeds budget %d", #defs, lim.MaxPatches))
	end

	local cellBase = 0
	for index, def in defs do
		local ok, err = Surface.validate(def)
		if not ok then
			error("paint content error: " .. tostring(err))
		end
		if self.byId[def.SurfaceId] then
			error("paint content error: duplicate SurfaceId " .. def.SurfaceId)
		end
		local cellCount = def.SizeU * def.SizeV
		local chunksU = math.ceil(def.SizeU / CHUNK)
		local chunksV = math.ceil(def.SizeV / CHUNK)
		local minB, maxB = Surface.bounds(def, 0.5)
		local patch: Patch = {
			index = index,
			def = def,
			owner = buffer.create(cellCount),
			cellCount = cellCount,
			legalCount = Surface.legalCount(def),
			cellBase = cellBase,
			chunksU = chunksU,
			chunksV = chunksV,
			chunkBase = self.chunkCount,
			counts = { [0] = 0, [1] = 0, [2] = 0 },
			minB = minB,
			maxB = maxB,
		}
		cellBase += cellCount
		for _ = 1, chunksU * chunksV do
			self.chunkCount += 1
			self.chunkVersion[self.chunkCount] = 0
			self.chunkPatch[self.chunkCount] = index
		end
		table.insert(self.patches, patch)
		self.byId[def.SurfaceId] = patch
		if def.Scoreable then
			self.totalScoringArea += patch.legalCount
		else
			self.totalWallCells += patch.legalCount
		end
		-- spatial index
		local x0, y0, z0 = math.floor(minB.X / BUCKET), math.floor(minB.Y / BUCKET), math.floor(minB.Z / BUCKET)
		local x1, y1, z1 = math.floor(maxB.X / BUCKET), math.floor(maxB.Y / BUCKET), math.floor(maxB.Z / BUCKET)
		for bx = x0, x1 do
			for by = y0, y1 do
				for bz = z0, z1 do
					local key = bucketKey(bx, by, bz)
					local list = self.buckets[key]
					if not list then
						list = {}
						self.buckets[key] = list
					end
					table.insert(list, index)
				end
			end
		end
	end

	if lim.MaxScoringCells and self.totalScoringArea > lim.MaxScoringCells then
		error(string.format("paint content error: %d scoring cells exceeds budget %d", self.totalScoringArea, lim.MaxScoringCells))
	end
	if lim.MaxWallCells and self.totalWallCells > lim.MaxWallCells then
		error(string.format("paint content error: %d non-scoring cells exceeds budget %d", self.totalWallCells, lim.MaxWallCells))
	end

	self:reset()
	return self
end

-- Clear all ownership to initial state; bumps every chunk version so mirrors discard older data.
function PaintGrid.reset(self: Grid)
	self.totals = { [0] = 0, [1] = 0, [2] = 0 }
	for _, patch in self.patches do
		local init = patch.def.InitialOwner or 0
		buffer.fill(patch.owner, 0, init)
		patch.counts = { [0] = 0, [1] = 0, [2] = 0 }
		patch.counts[init] = patch.legalCount
		if patch.def.Scoreable then
			self.totals[init] += patch.legalCount
		end
	end
	for c = 1, self.chunkCount do
		self.chunkVersion[c] += 1
	end
	self.dirty = {}
	self.dirtyCount = 0
	self.frozen = false
end

function PaintGrid.freeze(self: Grid)
	self.frozen = true
end

function PaintGrid.getPatch(self: Grid, surfaceId: string): Patch?
	return self.byId[surfaceId]
end

function PaintGrid.chunkOf(_self: Grid, patch: Patch, i: number, j: number): number
	return patch.chunkBase + (j // CHUNK) * patch.chunksU + (i // CHUNK) + 1
end

function PaintGrid.getOwner(_self: Grid, patch: Patch, cell: number): number
	return buffer.readu8(patch.owner, cell)
end

-- Sets one cell. Returns old owner, or nil if nothing changed / illegal.
function PaintGrid.setCell(self: Grid, patch: Patch, i: number, j: number, team: number): number?
	if self.frozen then
		return nil
	end
	local def = patch.def
	local cell = j * def.SizeU + i
	if not Surface.isLegal(def, cell) then
		return nil
	end
	local old = buffer.readu8(patch.owner, cell)
	if old == team then
		return nil
	end
	buffer.writeu8(patch.owner, cell, team)
	patch.counts[old] -= 1
	patch.counts[team] += 1
	if def.Scoreable then
		self.totals[old] -= 1
		self.totals[team] += 1
	end
	local chunk = self:chunkOf(patch, i, j)
	if not self.dirty[chunk] then
		self.dirty[chunk] = true
		self.dirtyCount += 1
	end
	return old
end

-- Candidate patches whose padded bounds intersect the axis-aligned box [minv, maxv].
function PaintGrid.query(self: Grid, minv: vector, maxv: vector): { Patch }
	local seen: { [number]: boolean } = {}
	local out: { Patch } = {}
	local x0, y0, z0 = math.floor(minv.X / BUCKET), math.floor(minv.Y / BUCKET), math.floor(minv.Z / BUCKET)
	local x1, y1, z1 = math.floor(maxv.X / BUCKET), math.floor(maxv.Y / BUCKET), math.floor(maxv.Z / BUCKET)
	for bx = x0, x1 do
		for by = y0, y1 do
			for bz = z0, z1 do
				local list = self.buckets[bucketKey(bx, by, bz)]
				if list then
					for _, idx in list do
						if not seen[idx] then
							seen[idx] = true
							local p = self.patches[idx]
							if p.minB.X <= maxv.X and p.maxB.X >= minv.X and p.minB.Y <= maxv.Y and p.maxB.Y >= minv.Y and p.minB.Z <= maxv.Z and p.maxB.Z >= minv.Z then
								table.insert(out, p)
							end
						end
					end
				end
			end
		end
	end
	table.sort(out, function(a, b)
		return a.index < b.index
	end)
	return out
end

-- Finds the patch/cell that a world point lies on (e.g. under a character). Prefers the closest plane.
function PaintGrid.locate(self: Grid, p: vector, tolerance: number, minNormalY: number?): (Patch?, number?, number?)
	local tol = vector.create(tolerance, tolerance, tolerance)
	local best: Patch?, bi: number?, bj: number?, bestD = nil, nil, nil, math.huge
	for _, patch in self:query(p - tol, p + tol) do
		if minNormalY == nil or patch.def.Normal.Y >= minNormalY then
			local i, j = Surface.locate(patch.def, p, tolerance)
			if i and j then
				local _, _, d = Surface.toLocal(patch.def, p)
				if math.abs(d) < bestD and Surface.isLegal(patch.def, j * patch.def.SizeU + i) then
					best, bi, bj, bestD = patch, i, j, math.abs(d)
				end
			end
		end
	end
	return best, bi, bj
end

local function newResult(collect: boolean?): StampResult
	return { changed = 0, scoreableConverted = 0, changes = if collect then {} else nil }
end

local function applyCell(self: Grid, patch: Patch, i: number, j: number, team: number, result: StampResult)
	local old = self:setCell(patch, i, j, team)
	if old ~= nil then
		result.changed += 1
		local scoreable = patch.def.Scoreable
		if scoreable then
			result.scoreableConverted += 1
		end
		local changes = result.changes
		if changes then
			local cell = j * patch.def.SizeU + i
			table.insert(changes, {
				patch = patch.index,
				cell = cell,
				globalCell = patch.cellBase + cell,
				old = old,
				new = team,
				scoreable = scoreable,
			})
		end
	end
end

-- Paints every legal cell whose centre lies within `radius` (3D) of `center`, on patches facing the stamp
-- origin, subject to occlusion. Used for impacts, blasts and drips.
function PaintGrid.stampSphere(self: Grid, center: vector, radius: number, team: number, opts: StampOptions?): StampResult
	local o = opts or {} :: StampOptions
	local result = newResult(o.collect)
	if self.frozen or radius <= 0 then
		return result
	end
	local origin = o.origin or center
	local isVisible = o.isVisible
	local back = o.backTolerance or 0.25
	local r = vector.create(radius, radius, radius)
	local r2 = radius * radius
	for _, patch in self:query(center - r, center + r) do
		local def = patch.def
		local ny = def.Normal.Y
		if (o.minNormalY == nil or ny >= o.minNormalY) and (o.maxNormalY == nil or ny <= o.maxNormalY) then
			local u, v, d = Surface.toLocal(def, center)
			local _, _, od = Surface.toLocal(def, origin)
			-- The stamp must be within reach of the plane and the origin must be on (or barely behind) the paintable side.
			if math.abs(d) <= radius and od >= -back then
				local planar = math.sqrt(math.max(0, r2 - d * d))
				local i0 = math.max(0, math.floor(u - planar))
				local i1 = math.min(def.SizeU - 1, math.floor(u + planar))
				local j0 = math.max(0, math.floor(v - planar))
				local j1 = math.min(def.SizeV - 1, math.floor(v + planar))
				local lift = def.Normal * 0.05
				for j = j0, j1 do
					local dv = (j + 0.5) - v
					for i = i0, i1 do
						local du = (i + 0.5) - u
						if du * du + dv * dv + d * d <= r2 then
							local cell = j * def.SizeU + i
							if Surface.isLegal(def, cell) then
								if isVisible == nil or isVisible(origin, Surface.cellCenter(def, i, j) + lift) then
									applyCell(self, patch, i, j, team, result)
								end
							end
						end
					end
				end
			end
		end
	end
	return result
end

-- Paints floor-like cells inside an oriented horizontal rectangle (roller flick/roll, brush sweep/push).
-- `forward` is projected onto the horizontal plane; the rectangle starts at `center` - forward*length/2.
-- `verticalTolerance` bounds how far above/below `center` a floor cell may be.
function PaintGrid.stampRect(
	self: Grid,
	center: vector,
	forward: vector,
	length: number,
	width: number,
	verticalTolerance: number,
	team: number,
	opts: StampOptions?
): StampResult
	local o = opts or {} :: StampOptions
	local result = newResult(o.collect)
	if self.frozen then
		return result
	end
	local flat = vector.create(forward.X, 0, forward.Z)
	if vector.magnitude(flat) < 1e-4 then
		return result
	end
	local f = vector.normalize(flat)
	local s = vector.create(-f.Z, 0, f.X)
	local halfL, halfW = length / 2, width / 2
	local reach = math.sqrt(halfL * halfL + halfW * halfW)
	local ext = vector.create(reach, verticalTolerance, reach)
	local origin = o.origin or center
	local isVisible = o.isVisible
	local minNY = o.minNormalY or 0.5
	for _, patch in self:query(center - ext, center + ext) do
		local def = patch.def
		if def.Normal.Y >= minNY then
			-- Iterate the patch cells overlapping the rectangle's bounding box (in patch-local coordinates).
			local u, v = Surface.toLocal(def, center)
			local i0 = math.max(0, math.floor(u - reach - 1))
			local i1 = math.min(def.SizeU - 1, math.floor(u + reach + 1))
			local j0 = math.max(0, math.floor(v - reach - 1))
			local j1 = math.min(def.SizeV - 1, math.floor(v + reach + 1))
			local lift = def.Normal * 0.05
			for j = j0, j1 do
				for i = i0, i1 do
					local cell = j * def.SizeU + i
					if Surface.isLegal(def, cell) then
						local c = Surface.cellCenter(def, i, j)
						local rel = c - center
						if math.abs(rel.Y) <= verticalTolerance then
							local along = vector.dot(rel, f)
							local side = vector.dot(rel, s)
							if math.abs(along) <= halfL and math.abs(side) <= halfW then
								if isVisible == nil or isVisible(origin, c + lift) then
									applyCell(self, patch, i, j, team, result)
								end
							end
						end
					end
				end
			end
		end
	end
	return result
end

---------------------------------------------------------------------------------------------------------------
-- Serialization: chunk payloads, deltas and snapshots.
---------------------------------------------------------------------------------------------------------------

-- Packs a chunk's ownership into `out` at `offset` (64 bytes). Padding cells are 0.
function PaintGrid.packChunk(self: Grid, chunk: number, out: buffer, offset: number)
	local patch = self.patches[self.chunkPatch[chunk]]
	local local_ = chunk - patch.chunkBase - 1
	local cu = local_ % patch.chunksU
	local cv = local_ // patch.chunksU
	local def = patch.def
	local baseI, baseJ = cu * CHUNK, cv * CHUNK
	buffer.fill(out, offset, 0, CHUNK_BYTES)
	for lj = 0, CHUNK - 1 do
		local j = baseJ + lj
		if j < def.SizeV then
			for li = 0, CHUNK - 1 do
				local i = baseI + li
				if i < def.SizeU then
					local own = buffer.readu8(patch.owner, j * def.SizeU + i)
					if own ~= 0 then
						local k = lj * CHUNK + li
						local byteAt = offset + (k // 4)
						local shift = (k % 4) * 2
						buffer.writeu8(out, byteAt, bit32.bor(buffer.readu8(out, byteAt), bit32.lshift(own, shift)))
					end
				end
			end
		end
	end
end

-- Applies a packed chunk payload (mirror side). Returns the number of cells whose owner changed.
-- Counts/totals are recomputed incrementally so a client mirror can also display coverage.
function PaintGrid.unpackChunk(self: Grid, chunk: number, data: buffer, offset: number): number
	local patch = self.patches[self.chunkPatch[chunk]]
	local local_ = chunk - patch.chunkBase - 1
	local cu = local_ % patch.chunksU
	local cv = local_ // patch.chunksU
	local def = patch.def
	local baseI, baseJ = cu * CHUNK, cv * CHUNK
	local changed = 0
	for lj = 0, CHUNK - 1 do
		local j = baseJ + lj
		if j < def.SizeV then
			for li = 0, CHUNK - 1 do
				local i = baseI + li
				if i < def.SizeU then
					local cell = j * def.SizeU + i
					if Surface.isLegal(def, cell) then
						local k = lj * CHUNK + li
						local own = bit32.band(bit32.rshift(buffer.readu8(data, offset + (k // 4)), (k % 4) * 2), 3)
						if own > 2 then
							own = 0
						end
						local old = buffer.readu8(patch.owner, cell)
						if old ~= own then
							buffer.writeu8(patch.owner, cell, own)
							patch.counts[old] -= 1
							patch.counts[own] += 1
							if def.Scoreable then
								self.totals[old] -= 1
								self.totals[own] += 1
							end
							changed += 1
						end
					end
				end
			end
		end
	end
	return changed
end

-- Collects dirty chunks into one delta message and clears the dirty set.
-- Wire format (buffer): u32 sequence, u16 count, then per chunk: u32 chunkId, u32 version, 64 bytes.
function PaintGrid.flushDelta(self: Grid): (buffer?, { number }?)
	if self.dirtyCount == 0 then
		return nil, nil
	end
	local ids = {}
	for chunk in self.dirty do
		table.insert(ids, chunk)
	end
	table.sort(ids)
	self.dirty = {}
	self.dirtyCount = 0
	self.sequence += 1
	local out = buffer.create(6 + #ids * (8 + CHUNK_BYTES))
	buffer.writeu32(out, 0, self.sequence)
	buffer.writeu16(out, 4, #ids)
	local at = 6
	for _, chunk in ids do
		self.chunkVersion[chunk] += 1
		buffer.writeu32(out, at, chunk)
		buffer.writeu32(out, at + 4, self.chunkVersion[chunk])
		self:packChunk(chunk, out, at + 8)
		at += 8 + CHUNK_BYTES
	end
	return out, ids
end

-- Encodes the given chunk ids (or all) with their current versions, same per-chunk layout as a delta.
-- Header: u32 sequence (the sequence this snapshot is coherent with), u16 count.
function PaintGrid.encodeChunks(self: Grid, ids: { number }?): buffer
	local list = ids
	if list == nil then
		local all = table.create(self.chunkCount)
		for c = 1, self.chunkCount do
			all[c] = c
		end
		list = all
	end
	assert(list, "chunk list missing")
	local out = buffer.create(6 + #list * (8 + CHUNK_BYTES))
	buffer.writeu32(out, 0, self.sequence)
	buffer.writeu16(out, 4, #list)
	local at = 6
	for _, chunk in list do
		buffer.writeu32(out, at, chunk)
		buffer.writeu32(out, at + 4, self.chunkVersion[chunk])
		self:packChunk(chunk, out, at + 8)
		at += 8 + CHUNK_BYTES
	end
	return out
end

-- Mirror side: applies a delta or snapshot buffer. Chunks whose version is not newer than the mirror's are
-- ignored. Returns sequence, number of applied chunks, and the list of applied chunk ids.
function PaintGrid.applyEncoded(self: Grid, data: buffer): (number, number, { number })
	local seq = buffer.readu32(data, 0)
	local count = buffer.readu16(data, 4)
	local expected = 6 + count * (8 + CHUNK_BYTES)
	if buffer.len(data) ~= expected then
		error("malformed paint payload: length " .. buffer.len(data) .. " expected " .. expected)
	end
	local applied = {}
	local at = 6
	for _ = 1, count do
		local chunk = buffer.readu32(data, at)
		local version = buffer.readu32(data, at + 4)
		if chunk >= 1 and chunk <= self.chunkCount and version > self.chunkVersion[chunk] then
			self.chunkVersion[chunk] = version
			self:unpackChunk(chunk, data, at + 8)
			table.insert(applied, chunk)
		end
		at += 8 + CHUNK_BYTES
	end
	return seq, #applied, applied
end

-- Order-independent FNV-style hash of all ownership (for PaintHashMismatch diagnostics and tests).
function PaintGrid.hash(self: Grid): number
	local h = 2166136261
	for _, patch in self.patches do
		local n = patch.cellCount
		for k = 0, n - 1 do
			h = bit32.bxor(h, buffer.readu8(patch.owner, k) + k % 251)
			h = (h * 16777619) % 4294967296
		end
	end
	return h
end

-- Recounts from buffers; used by tests to verify the incremental invariant.
function PaintGrid.recount(self: Grid): { [number]: number }
	local t = { [0] = 0, [1] = 0, [2] = 0 }
	for _, patch in self.patches do
		if patch.def.Scoreable then
			local def = patch.def
			for k = 0, patch.cellCount - 1 do
				if Surface.isLegal(def, k) then
					local own = buffer.readu8(patch.owner, k)
					t[own] += 1
				end
			end
		end
	end
	return t
end

PaintGrid.CHUNK = CHUNK
PaintGrid.CHUNK_BYTES = CHUNK_BYTES

return PaintGrid
