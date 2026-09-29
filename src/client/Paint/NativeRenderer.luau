-- IPaintRenderer implementation using native parts (D-004; EditableImage is disabled for this experience).
--   Initialize(grid) · ApplyChunk(chunkId) · SetPalette(palette) · Reset() · Destroy()
-- Each 16x16 chunk is re-meshed from the client mirror: same-owner cells merge greedily into rectangles, each drawn
-- as one thin, non-colliding, non-queryable Part lying on the registered surface. Parts are pooled. Chunk updates
-- are queued and processed under a per-frame time budget so a burst of deltas cannot stall a frame.
-- Gameplay never reads the renderer: movement, refill and score use ownership buffers only (GDD 10.1).
--
-- Prediction overlay (GDD 10.6): Predict(id, cells, team) draws temporary cells; Confirm(id) / Deny(id) resolve
-- them; any prediction still pending after `PredictionTimeout` is removed so no ghost paint can persist.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Surface = require(Shared.Paint.Surface)

local NativeRenderer = {}
NativeRenderer.__index = NativeRenderer

local CHUNK = 16
local THICKNESS = 0.05
-- Seconds of renderer work per frame. The loop checks after each part, so allow headroom under the GDD 14.2
-- renderer p95 target of 3 ms (measured p95 3.41 ms with a 3.0 ms budget under an extreme paint burst).
local FRAME_BUDGET = 0.0025

export type Palette = { [number]: Color3 }

NativeRenderer.DefaultPalette = table.freeze({
	[1] = Color3.fromRGB(255, 138, 0), -- team A
	[2] = Color3.fromRGB(0, 150, 255), -- team B
})

-- Colour-vision-friendly alternative (distinguishable without red/green; GDD 04.4).
NativeRenderer.AccessiblePalette = table.freeze({
	[1] = Color3.fromRGB(240, 228, 66),
	[2] = Color3.fromRGB(0, 90, 181),
})

local function newPart(): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Locked = true
	return p
end

function NativeRenderer.new(parent: Instance?)
	local folder = Instance.new("Folder")
	folder.Name = "ColorClashPaint"
	folder.Parent = parent or Workspace
	local self = setmetatable({
		folder = folder,
		grid = nil,
		palette = table.clone(NativeRenderer.DefaultPalette),
		chunkParts = {} :: { [number]: { Part } },
		pool = {} :: { Part },
		queue = {} :: { number },
		queued = {} :: { [number]: boolean },
		predictions = {} :: { [any]: { parts: { Part }, expires: number } },
		activeParts = 0,
		stats = { applied = 0, frameMsMax = 0, lastFrameMs = 0, samples = {} },
		conn = nil :: RBXScriptConnection?,
	}, NativeRenderer)
	self.conn = RunService.RenderStepped:Connect(function()
		self:_process()
	end)
	return self
end

function NativeRenderer:_take(): Part
	local p = table.remove(self.pool)
	if not p then
		p = newPart()
	end
	self.activeParts += 1
	return p
end

function NativeRenderer:_release(p: Part)
	self.activeParts -= 1
	p.Parent = nil
	table.insert(self.pool, p)
end

function NativeRenderer:Initialize(grid)
	self:Reset()
	self.grid = grid
	for c = 1, grid.chunkCount do
		self:ApplyChunk(c)
	end
end

function NativeRenderer:ApplyChunk(chunk: number)
	if not self.queued[chunk] then
		self.queued[chunk] = true
		table.insert(self.queue, chunk)
	end
end

-- Work is sliced across frames: a chunk's rectangles are computed (cheap), then its parts are prepared a few at a
-- time, and the finished chunk is swapped in atomically (old parts out, new parts in, same frame) so there is never
-- a half-drawn or doubled chunk on screen.
function NativeRenderer:_process()
	if #self.queue == 0 and not self.job then
		self:_expirePredictions()
		return
	end
	local t0 = os.clock()
	local processed = 0
	while (os.clock() - t0) < FRAME_BUDGET do
		local job = self.job
		if not job then
			if #self.queue == 0 then
				break
			end
			local chunk = table.remove(self.queue, 1)
			self.queued[chunk] = nil
			job = { chunk = chunk, rects = self:_rects(chunk), index = 1, parts = {}, cframes = {} }
			self.job = job
		end
		local rects = job.rects
		while job.index <= #rects and (os.clock() - t0) < FRAME_BUDGET do
			local r = rects[job.index]
			local part = self:_take()
			part.Size = r.size
			part.Color = self.palette[r.owner] or Color3.new(1, 0, 1)
			part:SetAttribute("Owner", r.owner)
			table.insert(job.parts, part)
			table.insert(job.cframes, r.cframe)
			job.index += 1
		end
		if job.index > #rects then
			self:_swap(job)
			self.job = nil
			processed += 1
		end
	end
	local ms = (os.clock() - t0) * 1000
	self.stats.lastFrameMs = ms
	if ms > self.stats.frameMsMax then
		self.stats.frameMsMax = ms
	end
	local samples = self.stats.samples
	if #samples >= 2000 then
		table.remove(samples, 1)
	end
	table.insert(samples, ms)
	self.stats.applied += processed
	self:_expirePredictions()
end

function NativeRenderer:_swap(job)
	local old = self.chunkParts[job.chunk]
	if old then
		for _, p in old do
			self:_release(p)
		end
	end
	if #job.parts > 0 then
		Workspace:BulkMoveTo(job.parts, job.cframes, Enum.BulkMoveMode.FireCFrameChanged)
		for _, p in job.parts do
			p.Parent = self.folder
		end
	end
	self.chunkParts[job.chunk] = job.parts
end

-- Greedy rectangles for one chunk from the mirror ownership: { owner, size, cframe }.
function NativeRenderer:_rects(chunk: number): { any }
	local grid = self.grid
	local out = {}
	if not grid then
		return out
	end
	local patch = grid.patches[grid.chunkPatch[chunk]]
	local def = patch.def
	local localIndex = chunk - patch.chunkBase - 1
	local baseI = (localIndex % patch.chunksU) * CHUNK
	local baseJ = (localIndex // patch.chunksU) * CHUNK
	local w = math.min(CHUNK, def.SizeU - baseI)
	local h = math.min(CHUNK, def.SizeV - baseJ)
	local owner = patch.owner
	local sizeU = def.SizeU
	local visited = buffer.create(CHUNK * CHUNK)
	local lift = def.Normal * (GameConfig.Paint.SurfaceOffset + THICKNESS / 2)
	local U = Vector3.new(def.U.X, def.U.Y, def.U.Z)
	local N = Vector3.new(def.Normal.X, def.Normal.Y, def.Normal.Z)
	for lj = 0, h - 1 do
		for li = 0, w - 1 do
			local k = lj * CHUNK + li
			if buffer.readu8(visited, k) == 0 then
				local o = buffer.readu8(owner, (baseJ + lj) * sizeU + baseI + li)
				if o ~= 0 then
					-- grow right
					local rw = 1
					while li + rw < w do
						local kk = lj * CHUNK + li + rw
						if buffer.readu8(visited, kk) ~= 0 or buffer.readu8(owner, (baseJ + lj) * sizeU + baseI + li + rw) ~= o then
							break
						end
						rw += 1
					end
					-- grow down while the whole row segment matches
					local rh = 1
					while lj + rh < h do
						local ok = true
						for x = 0, rw - 1 do
							local kk = (lj + rh) * CHUNK + li + x
							if buffer.readu8(visited, kk) ~= 0 or buffer.readu8(owner, (baseJ + lj + rh) * sizeU + baseI + li + x) ~= o then
								ok = false
								break
							end
						end
						if not ok then
							break
						end
						rh += 1
					end
					for y = 0, rh - 1 do
						for x = 0, rw - 1 do
							buffer.writeu8(visited, (lj + y) * CHUNK + li + x, 1)
						end
					end
					local ci = baseI + li + rw / 2
					local cj = baseJ + lj + rh / 2
					local center = def.Origin + def.U * ci + def.V * cj + lift
					table.insert(out, {
						owner = o,
						size = Vector3.new(rw, THICKNESS, rh),
						cframe = CFrame.fromMatrix(Vector3.new(center.X, center.Y, center.Z), U, N),
					})
				end
			end
		end
	end
	return out
end

function NativeRenderer:SetPalette(palette: Palette)
	self.palette = table.clone(palette)
	for _, parts in self.chunkParts do
		for _, p in parts do
			p.Color = self.palette[p:GetAttribute("Owner")] or p.Color
		end
	end
	for _, pred in self.predictions do
		for _, p in pred.parts do
			p.Color = self.palette[p:GetAttribute("Owner")] or p.Color
		end
	end
end

function NativeRenderer:Reset()
	for _, parts in self.chunkParts do
		for _, p in parts do
			self:_release(p)
		end
	end
	if self.job then
		for _, p in self.job.parts do
			self:_release(p)
		end
		self.job = nil
	end
	for id in self.predictions do
		self:Deny(id)
	end
	table.clear(self.chunkParts)
	table.clear(self.queue)
	table.clear(self.queued)
	self.grid = nil
end

function NativeRenderer:Destroy()
	self:Reset()
	if self.conn then
		self.conn:Disconnect()
		self.conn = nil
	end
	for _, p in self.pool do
		p:Destroy()
	end
	table.clear(self.pool)
	self.folder:Destroy()
end

---------------------------------------------------------------------------------------------------------------
-- Prediction overlay
---------------------------------------------------------------------------------------------------------------

-- `cells` = list of { patch = patchIndex, i = cellI, j = cellJ }. Drawn as single-cell tiles slightly above paint.
function NativeRenderer:Predict(id: any, cells: { any }, team: number)
	if not self.grid or self.predictions[id] then
		return
	end
	local parts = {}
	for _, c in cells do
		local patch = self.grid.patches[c.patch]
		if patch then
			local def = patch.def
			local center = Surface.cellCenter(def, c.i, c.j) + def.Normal * (GameConfig.Paint.SurfaceOffset + THICKNESS * 1.5)
			local p = self:_take()
			p.Size = Vector3.new(1, THICKNESS, 1)
			p.Color = self.palette[team]
			p:SetAttribute("Owner", team)
			p:SetAttribute("Predicted", true)
			p.CFrame = CFrame.fromMatrix(Vector3.new(center.X, center.Y, center.Z), Vector3.new(def.U.X, def.U.Y, def.U.Z), Vector3.new(def.Normal.X, def.Normal.Y, def.Normal.Z))
			p.Parent = self.folder
			table.insert(parts, p)
		end
	end
	self.predictions[id] = { parts = parts, expires = os.clock() + 2 }
end

-- Authoritative chunks have arrived for this action: the overlay is no longer needed.
function NativeRenderer:Confirm(id: any)
	self:Deny(id)
end

-- The server denied the action (or it expired): remove its predicted paint.
function NativeRenderer:Deny(id: any)
	local pred = self.predictions[id]
	if not pred then
		return
	end
	self.predictions[id] = nil
	for _, p in pred.parts do
		p:SetAttribute("Predicted", nil)
		self:_release(p)
	end
end

-- After a denial arrives the caller sets a short expiry; nothing predicted survives past its expiry.
function NativeRenderer:ExpireIn(id: any, seconds: number)
	local pred = self.predictions[id]
	if pred then
		pred.expires = math.min(pred.expires, os.clock() + seconds)
	end
end

function NativeRenderer:_expirePredictions()
	local now = os.clock()
	for id, pred in self.predictions do
		if now >= pred.expires then
			self:Deny(id)
		end
	end
end

function NativeRenderer:Stats()
	local predicted = 0
	for _, pred in self.predictions do
		predicted += #pred.parts
	end
	return {
		activeParts = self.activeParts,
		pooled = #self.pool,
		queued = #self.queue + (if self.job then 1 else 0),
		predicted = predicted,
		applied = self.stats.applied,
		frameMsMax = self.stats.frameMsMax,
		lastFrameMs = self.stats.lastFrameMs,
	}
end

function NativeRenderer:ResetStats()
	self.stats.frameMsMax = 0
	self.stats.applied = 0
	table.clear(self.stats.samples)
end

-- p95 of renderer work per frame (ms) over frames that had work since the last ResetStats.
function NativeRenderer:WorkP95(): number
	local s = table.clone(self.stats.samples)
	if #s == 0 then
		return 0
	end
	table.sort(s)
	return s[math.max(1, math.ceil(#s * 0.95))]
end

-- Test helper: the owner rendered at a cell (by inspecting the rectangle covering its centre), or 0.
function NativeRenderer:RenderedOwnerAt(patchIndex: number, i: number, j: number): number
	local grid = self.grid
	if not grid then
		return 0
	end
	local patch = grid.patches[patchIndex]
	local chunk = grid:chunkOf(patch, i, j)
	local c = Surface.cellCenter(patch.def, i, j)
	local p = Vector3.new(c.X, c.Y, c.Z)
	for _, part in self.chunkParts[chunk] or {} do
		local lp = part.CFrame:PointToObjectSpace(p)
		if math.abs(lp.X) <= part.Size.X / 2 + 1e-3 and math.abs(lp.Z) <= part.Size.Z / 2 + 1e-3 and math.abs(lp.Y) < 0.5 then
			return part:GetAttribute("Owner") or 0
		end
	end
	return 0
end

return NativeRenderer
