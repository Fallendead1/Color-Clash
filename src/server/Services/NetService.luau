-- Remote layer (GDD 11.4). Creates the remotes once, wraps every client->server handler with a per-player rate
-- limit and a protected call, and counts rejections. Handlers must still validate payload shape themselves.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Protocol.Net)
local Validate = require(Shared.Protocol.Validate)

local DevGate = require(script.Parent.Parent.DevGate)

local NetService = {}

local remotes: { [string]: any } = {}
local limiters: { [string]: any } = {}
local lastAt: { [Player]: { [string]: number } } = {} -- simulated in-order delivery per player/channel
local diagnostics

function NetService:Init(ctx)
	diagnostics = ctx.services.DiagnosticsService
	remotes = Net.createServerRemotes()
	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in limiters do
			limiter:forget(player)
		end
		lastAt[player] = nil
	end)
end

function NetService:Start() end

---------------------------------------------------------------------------------------------------------------
-- Dev-only network simulation (NET-05/06): DevGate NetLatencyMs (one-way), NetJitterMs, NetLossPct. Applied to both
-- directions. Reliable remotes stay ordered per player and remote (like Roblox); only unreliable ones may drop.
-- Off unless set; never active in production (DevGate).
---------------------------------------------------------------------------------------------------------------

local function simDelay(): number?
	if not DevGate.enabled() then
		return nil
	end
	local lat = DevGate.get("NetLatencyMs", 0)
	local jit = DevGate.get("NetJitterMs", 0)
	if lat <= 0 and jit <= 0 then
		return nil
	end
	return math.max(0, lat + (math.random() * 2 - 1) * jit) / 1000
end

local function schedule(player: Player, channel: string, reliable: boolean, fn: () -> ())
	local d = simDelay()
	if d == nil then
		fn()
		return
	end
	if not reliable and math.random() * 100 < DevGate.get("NetLossPct", 0) then
		diagnostics.count("NetSim.dropped")
		return
	end
	local now = os.clock()
	local at = now + d
	if reliable then
		local per = lastAt[player]
		if not per then
			per = {}
			lastAt[player] = per
		end
		at = math.max(at, (per[channel] or 0) + 1e-4) -- in-order delivery
		per[channel] = at
	end
	task.delay(at - now, fn)
end

-- Registers a handler. `perSecond` bounds sustained requests per player; excess requests are dropped cheaply
-- before any handler work (GDD 11.4, SEC-08). Handler errors are counted and logged, never silently swallowed.
function NetService.on(name: string, perSecond: number, handler: (Player, ...any) -> ())
	local remote = remotes[name]
	assert(remote, "unknown remote " .. name)
	local limiter = Validate.rateLimiter(perSecond, math.max(2, math.ceil(perSecond * 0.5)))
	limiters[name] = limiter
	local reliable = Net.Remotes[name] ~= "unreliable"
	local function deliver(player: Player, ...)
		if not limiter:allow(player, os.clock()) then
			diagnostics.count("RemoteRateLimited." .. name)
			return
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			diagnostics.count("RemoteHandlerError." .. name)
			diagnostics.event("RemoteHandlerError", { remote = name, err = string.sub(tostring(err), 1, 200) })
			warn("[ColorClash] handler error in " .. name .. ": " .. tostring(err))
		end
	end
	remote.OnServerEvent:Connect(function(player: Player, ...)
		if simDelay() == nil then
			deliver(player, ...)
			return
		end
		local args = table.pack(...)
		schedule(player, "in:" .. name, reliable, function()
			if player.Parent == Players then
				deliver(player, table.unpack(args, 1, args.n))
			end
		end)
	end)
end

function NetService.fire(player: Player, name: string, ...)
	if simDelay() == nil then
		remotes[name]:FireClient(player, ...)
		return
	end
	local args = table.pack(...)
	schedule(player, "out:" .. name, Net.Remotes[name] ~= "unreliable", function()
		if player.Parent == Players then
			remotes[name]:FireClient(player, table.unpack(args, 1, args.n))
		end
	end)
end

function NetService.fireAll(name: string, ...)
	if simDelay() == nil then
		remotes[name]:FireAllClients(...)
		return
	end
	for _, p in Players:GetPlayers() do
		NetService.fire(p, name, ...)
	end
end

function NetService.fireList(players: { Player }, name: string, ...)
	local r = remotes[name]
	for _, p in players do
		if p.Parent == Players then
			r:FireClient(p, ...)
		end
	end
end

function NetService.remote(name: string)
	return remotes[name]
end

return NetService
