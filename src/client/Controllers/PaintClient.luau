-- Client mirror of authoritative paint (GDD 10.4-10.7). Applies snapshots/deltas by chunk version, rejects messages
-- from an old match or map, detects sequence gaps and requests a bounded resync, and acknowledges a completed
-- snapshot so the server can enable combat. Rendering goes through an IPaintRenderer (Initialize, ApplyChunk,
-- SetPalette, Reset, Destroy).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PaintGrid = require(Shared.Paint.PaintGrid)
local MapCodec = require(Shared.Paint.MapCodec)

local PaintClient = {}

local remotes
local renderer = nil
local grid = nil
local matchId = -1
local mapVersion = -1
local meta = nil
local lastDeltaSeq = 0
local synced = false
local frozenTotals = nil
local listeners: { (string, any) -> () } = {}
local resyncPending = false

local function emit(kind: string, data: any)
	for _, fn in listeners do
		task.spawn(fn, kind, data)
	end
end

function PaintClient.onChange(fn: (string, any) -> ())
	table.insert(listeners, fn)
end

function PaintClient.setRenderer(r)
	renderer = r
	if grid and renderer then
		renderer:Initialize(grid)
	end
end

local function requestResync(reason: string)
	if resyncPending or not grid then
		return
	end
	resyncPending = true
	remotes.PaintResync:FireServer({ m = matchId, v = mapVersion })
	emit("resync", reason)
	task.delay(2, function()
		resyncPending = false
	end)
end

local function applyBuffer(buf: buffer): { number }?
	if not grid then
		return nil
	end
	local ok, seq, _, applied = pcall(grid.applyEncoded, grid, buf)
	if not ok then
		warn("[ColorClash] malformed paint payload: " .. tostring(seq))
		requestResync("malformed")
		return nil
	end
	if renderer then
		for _, chunk in applied do
			renderer:ApplyChunk(chunk)
		end
	end
	return applied
end

local function onPaint(kind: string, m: any, v: any, a: any, b: any)
	if kind == "clear" then
		if renderer then
			renderer:Reset()
		end
		grid = nil
		meta = nil
		synced = false
		frozenTotals = nil
		matchId = -1
		emit("clear", nil)
		return
	end
	if kind == "map" then
		local defs, err = MapCodec.decode(a)
		if not defs then
			warn("[ColorClash] bad map payload: " .. tostring(err))
			return
		end
		if renderer then
			renderer:Reset()
		end
		local ok, g = pcall(PaintGrid.new, defs)
		if not ok then
			warn("[ColorClash] map definition rejected: " .. tostring(g))
			return
		end
		-- start below every server version so the snapshot always applies
		for c = 1, g.chunkCount do
			g.chunkVersion[c] = 0
		end
		grid = g
		matchId, mapVersion = m, v
		meta = b
		synced = false
		frozenTotals = nil
		lastDeltaSeq = 0
		if renderer then
			renderer:Initialize(grid)
		end
		emit("map", meta)
		return
	end
	-- everything else must match the current match and map (GDD 10.5: reject old match/map)
	if m ~= matchId or v ~= mapVersion or not grid then
		return
	end
	if kind == "snap" then
		applyBuffer(a)
		if b == true then
			synced = true
			lastDeltaSeq = buffer.readu32(a, 0)
			remotes.ClientEvent:FireServer({ k = "PaintSynced", m = matchId, v = mapVersion })
			emit("synced", nil)
		end
	elseif kind == "delta" then
		if grid.frozen then
			return -- PAINT-10: frozen outcome never changes
		end
		local seq = buffer.readu32(a, 0)
		applyBuffer(a)
		if synced and lastDeltaSeq > 0 and seq > lastDeltaSeq + 1 then
			requestResync("gap")
		end
		lastDeltaSeq = math.max(lastDeltaSeq, seq)
		emit("delta", nil)
	elseif kind == "freeze" then
		applyBuffer(a)
		grid:freeze()
		frozenTotals = b
		emit("freeze", { totals = b, localHash = grid:hash() })
	end
end

function PaintClient.start(r)
	remotes = r
	remotes.Paint.OnClientEvent:Connect(onPaint)
end

function PaintClient.grid()
	return grid
end

function PaintClient.meta()
	return meta
end

function PaintClient.isSynced(): boolean
	return synced
end

function PaintClient.matchId(): number
	return matchId
end

function PaintClient.frozenTotals()
	return frozenTotals
end

-- Team-relative ground classification from the mirror (prediction only; the server decides).
function PaintClient.ownerAtPoint(position: Vector3): (any?, number?)
	if not grid then
		return nil, nil
	end
	local patch, i, j = grid:locate(vector.create(position.X, position.Y, position.Z), 0.6, 0.3)
	if not patch then
		return nil, nil
	end
	return patch, buffer.readu8(patch.owner, j * patch.def.SizeU + i)
end

local _ = Players
return PaintClient
