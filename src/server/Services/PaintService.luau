-- Authoritative paint ownership on the server (GDD 10, 11.3 PaintService).
--
-- Wire protocol on the reliable "Paint" remote (server -> client), all tagged with matchId and mapVersion:
--   ("map",    m, v, encodedDefs, meta)     surface definitions + masks (MapCodec)
--   ("snap",   m, v, chunkBuffer, isLast)   coherent snapshot parts (full chunk states with versions)
--   ("delta",  m, v, chunkBuffer)           10 Hz batched dirty chunks
--   ("freeze", m, v, fullBuffer, totals)    final frozen state used by every client's results
--   ("clear",  m)                           map unloaded; discard all paint state
-- Every chunk record carries its monotonically increasing version, so a client applies only newer records.
-- A snapshot therefore stays coherent while deltas keep flowing: each chunk converges to its newest version,
-- which is equivalent to "snapshot at S + replay after S" without an unbounded replay queue (GDD 10.5).
-- Clients acknowledge with ClientEvent {k = "PaintSynced", m, v}; combat for that player is gated on the ack.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PaintGrid = require(Shared.Paint.PaintGrid)
local MapCodec = require(Shared.Paint.MapCodec)
local GameConfig = require(Shared.Config.GameConfig)
local Validate = require(Shared.Protocol.Validate)

local PaintService = {}

local P = GameConfig.Paint

local net, diagnostics, loadout
local grid = nil
local descriptor = nil
local matchId = 0
local mapVersion = 0
local encodedDefs = nil
local synced: { [Player]: boolean } = {}
local ackHash: { [Player]: number? } = {}
local frozenAck: { [Player]: number? } = {}
local lastResync: { [Player]: number } = {}
local contribution: { [Player]: number } = {}
local raycastByTeam: { [number]: RaycastParams } = {}
local accumulator = 0
local heartbeatConn: RBXScriptConnection? = nil

local function v3(v): Vector3
	return Vector3.new(v.X, v.Y, v.Z)
end

local function vec(v: Vector3): vector
	return vector.create(v.X, v.Y, v.Z)
end

-- Raycast include list for paint visibility for a painting team: map geometry, paint surfaces and the
-- OPPOSING team's Paint Screens (an enemy screen blocks propagation; the painter's own screens do not).
local function rebuildRaycastParams()
	if not descriptor then
		return
	end
	local arena = descriptor.model.Parent
	for team = 1, 2 do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		local list = table.clone(descriptor.raycastInclude)
		local enemyScreens = arena and arena:FindFirstChild("Screens" .. (if team == 1 then "B" else "A"))
		if enemyScreens then
			table.insert(list, enemyScreens)
		end
		params.FilterDescendantsInstances = list
		params.IgnoreWater = true
		raycastByTeam[team] = params
	end
end
PaintService.rebuildRaycastParams = rebuildRaycastParams

local function visibilityFor(team: number)
	local params = raycastByTeam[team]
	return function(from: vector, to: vector): boolean
		local dir = to - from
		local dist = vector.magnitude(dir)
		if dist < 1e-3 then
			return true
		end
		local hit = Workspace:Raycast(v3(from), v3(dir), params)
		return hit == nil or (hit.Position - v3(from)).Magnitude >= dist - 0.05
	end
end

local function sendSnapshot(player: Player)
	if not grid then
		return
	end
	synced[player] = false
	net.fire(player, "Paint", "map", matchId, mapVersion, encodedDefs, {
		mapId = descriptor.mapId,
		displayName = descriptor.displayName,
		isFixture = descriptor.isFixture,
		totalScoring = grid.totalScoringArea,
		chunkCount = grid.chunkCount,
	})
	local per = P.SnapshotChunksPerMessage
	local ids = {}
	local bytes = 0
	for c = 1, grid.chunkCount do
		table.insert(ids, c)
		if #ids >= per or c == grid.chunkCount then
			local buf = grid:encodeChunks(ids)
			bytes += buffer.len(buf)
			net.fire(player, "Paint", "snap", matchId, mapVersion, buf, c == grid.chunkCount)
			ids = {}
		end
	end
	diagnostics.event("PaintSnapshotSent", { player = player.UserId, bytes = bytes, chunks = grid.chunkCount })
end

function PaintService:Init(ctx)
	net = ctx.services.NetService
	diagnostics = ctx.services.DiagnosticsService
	loadout = ctx.services.LoadoutService
end

function PaintService:Start()
	net.on("PaintResync", GameConfig.Net.ResyncRequestsPerSecond, function(player, payload)
		if not Validate.shape(payload, { m = true, v = true }, 2) then
			diagnostics.count("PaintResync.rejected.shape")
			return
		end
		if payload.m ~= matchId or payload.v ~= mapVersion or not grid then
			diagnostics.count("PaintResync.rejected.stale")
			return
		end
		local now = os.clock()
		if lastResync[player] and now - lastResync[player] < P.ResyncMinInterval then
			diagnostics.count("PaintResync.rejected.interval")
			return
		end
		lastResync[player] = now
		diagnostics.event("PaintResync", { player = player.UserId })
		sendSnapshot(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		synced[player] = nil
		ackHash[player] = nil
		frozenAck[player] = nil
		lastResync[player] = nil
		contribution[player] = nil
	end)
	heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 1 / P.DeltaRateHz then
			accumulator = 0
			PaintService.flush()
		end
	end)
end

function PaintService:Stop()
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
end

-- Called by the client-event router when a client confirms it applied the full snapshot.
-- `h` is the client's ownership hash at that moment (diagnostic only; later deltas may already differ).
function PaintService.onClientSynced(player: Player, m: any, v: any, h: number?)
	if m == matchId and v == mapVersion and grid then
		synced[player] = true
		ackHash[player] = h
		diagnostics.event("PaintSynced", { player = player.UserId })
	end
end

-- The client's hash of the frozen final state. A mismatch is a real divergence (GDD 15 PaintHashMismatch).
function PaintService.onClientHash(player: Player, m: any, v: any, h: number)
	if m ~= matchId or v ~= mapVersion or not grid or not grid.frozen then
		return
	end
	local serverHash = grid:hash()
	frozenAck[player] = h
	if h == serverHash then
		diagnostics.count("PaintHash.ok")
	else
		diagnostics.event("PaintHashMismatch", { player = player.UserId, client = h, server = serverHash })
	end
end

function PaintService.ackHash(player: Player): number?
	return ackHash[player]
end

function PaintService.frozenAck(player: Player): number?
	return frozenAck[player]
end

function PaintService.isSynced(player: Player): boolean
	return synced[player] == true
end

-- Builds the authoritative grid for a freshly loaded map and a new match.
function PaintService.setMap(desc, newMatchId: number)
	descriptor = desc
	matchId = newMatchId
	mapVersion = desc.mapVersion
	grid = PaintGrid.new(desc.defs, P)
	encodedDefs = MapCodec.encode(desc.defs)
	table.clear(synced)
	table.clear(ackHash)
	table.clear(frozenAck)
	table.clear(contribution)
	rebuildRaycastParams()
	diagnostics.event("PaintMapSet", { map = desc.mapId, match = newMatchId, scoring = grid.totalScoringArea, chunks = grid.chunkCount })
end

function PaintService.syncPlayer(player: Player)
	sendSnapshot(player)
end

function PaintService.syncAll()
	for _, p in Players:GetPlayers() do
		sendSnapshot(p)
	end
end

function PaintService.flush()
	if not grid or grid.frozen then
		return
	end
	local t0 = os.clock()
	local buf, ids = grid:flushDelta()
	if buf then
		net.fireAll("Paint", "delta", matchId, mapVersion, buf)
		diagnostics.count("PaintDelta.messages")
		diagnostics.count("PaintDelta.bytes", buffer.len(buf))
		diagnostics.count("PaintDelta.chunks", #(ids :: any))
		diagnostics.time("paint.flush", (os.clock() - t0) * 1000)
	end
end

export type PaintOpts = {
	origin: Vector3?,
	player: Player?, -- painter; enables ultimate credit and contribution when creditable
	creditable: boolean?, -- main weapon / gadget paint (false for ultimate paint, practice, base)
	minNormalY: number?,
	maxNormalY: number?,
}

local function afterStamp(result, team: number, opts: PaintOpts?)
	local player = opts and opts.player
	if not player or not result.changes then
		return
	end
	local cells = {}
	for _, c in result.changes do
		if c.scoreable and c.new == team then
			table.insert(cells, c.globalCell)
		end
	end
	if #cells > 0 then
		contribution[player] = (contribution[player] or 0) + #cells
		if opts.creditable and loadout then
			loadout.creditUltimate(player, cells)
		end
	end
end

-- Paints a sphere footprint with real occlusion (GDD 10.3). Returns the stamp result.
function PaintService.paintSphere(center: Vector3, radius: number, team: number, opts: PaintOpts?)
	if not grid or grid.frozen then
		return nil
	end
	local t0 = os.clock()
	local origin = (opts and opts.origin) or center
	local result = grid:stampSphere(vec(center), radius, team, {
		origin = vec(origin),
		isVisible = visibilityFor(team),
		minNormalY = opts and opts.minNormalY,
		maxNormalY = opts and opts.maxNormalY,
		collect = opts ~= nil and opts.player ~= nil,
	})
	afterStamp(result, team, opts)
	diagnostics.time("paint.stampSphere", (os.clock() - t0) * 1000)
	return result
end

-- Paints a horizontal oriented rectangle on floors/ramps (roller, brush). `origin` is the visibility origin.
function PaintService.paintRect(center: Vector3, forward: Vector3, length: number, width: number, team: number, opts: PaintOpts?)
	if not grid or grid.frozen then
		return nil
	end
	local t0 = os.clock()
	local origin = (opts and opts.origin) or (center + Vector3.new(0, 2, 0))
	local result = grid:stampRect(vec(center), vec(forward), length, width, 3, team, {
		origin = vec(origin),
		isVisible = visibilityFor(team),
		collect = opts ~= nil and opts.player ~= nil,
	})
	afterStamp(result, team, opts)
	diagnostics.time("paint.stampRect", (os.clock() - t0) * 1000)
	return result
end

-- Classifies the floor beneath `position` for `team` (GDD 05.1): Own/Neutral/Enemy/Base/Inert/None.
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
function PaintService.groundAt(position: Vector3, team: number?, depth: number): (string, any?, number?)
	if not descriptor then
		return "None", nil, nil
	end
	groundParams.FilterDescendantsInstances = descriptor.raycastInclude
	local hit = Workspace:Raycast(position, Vector3.new(0, -depth, 0), groundParams)
	if not hit then
		return "None", nil, nil
	end
	if not grid then
		return "Inert", nil, nil
	end
	local patch, i, j = grid:locate(vec(hit.Position), 0.6, 0.3)
	if not patch then
		return "Inert", nil, nil
	end
	local owner = buffer.readu8(patch.owner, j * patch.def.SizeU + i)
	if patch.def.Kind == "Base" then
		return if owner == team then "Base" else "Enemy", patch, owner
	end
	if owner == 0 then
		return "Neutral", patch, owner
	end
	return if owner == team then "Own" else "Enemy", patch, owner
end

-- Ownership of the climbable wall cell in front of `position` along `-normal` (for Paint Climb validation).
function PaintService.wallOwnerAt(position: Vector3): (any?, number?)
	if not grid then
		return nil, nil
	end
	local patch, i, j = grid:locate(vec(position), 0.8, nil)
	if not patch or patch.def.Normal.Y > 0.5 then
		return nil, nil
	end
	return patch, buffer.readu8(patch.owner, j * patch.def.SizeU + i)
end

-- Freezes ownership at round end and broadcasts the exact frozen state (GDD 03.4). Returns raw totals.
function PaintService.freeze(): { a: number, b: number, total: number }?
	if not grid then
		return nil
	end
	-- Flush unsent changes first: chunks painted since the last 10 Hz delta must get new versions, otherwise a client
	-- that already holds the previous version would ignore their final content (found by PAINT-10 in Studio).
	local pending = grid:flushDelta()
	if pending then
		net.fireAll("Paint", "delta", matchId, mapVersion, pending)
	end
	grid:freeze()
	local full = grid:encodeChunks()
	local totals = { a = grid.totals[1], b = grid.totals[2], total = grid.totalScoringArea, hash = grid:hash() }
	net.fireAll("Paint", "freeze", matchId, mapVersion, full, totals)
	diagnostics.event("PaintFrozen", { match = matchId, a = totals.a, b = totals.b, total = totals.total })
	return totals
end

-- Clears all paint state for the old match (GDD 10.7).
function PaintService.clear()
	local oldMatch = matchId
	grid = nil
	descriptor = nil
	encodedDefs = nil
	table.clear(synced)
	table.clear(ackHash)
	table.clear(frozenAck)
	table.clear(raycastByTeam)
	net.fireAll("Paint", "clear", oldMatch)
end

function PaintService.contributionOf(player: Player): number
	return contribution[player] or 0
end

function PaintService.grid()
	return grid
end

function PaintService.totals(): { [number]: number }?
	return grid and grid.totals
end

return PaintService
