-- Remote layer (GDD 11.4). Creates the remotes once, wraps every client->server handler with a per-player rate
-- limit and a protected call, and counts rejections. Handlers must still validate payload shape themselves.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Protocol.Net)
local Validate = require(Shared.Protocol.Validate)

local NetService = {}

local remotes: { [string]: any } = {}
local limiters: { [string]: any } = {}
local diagnostics

function NetService:Init(ctx)
	diagnostics = ctx.services.DiagnosticsService
	remotes = Net.createServerRemotes()
	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in limiters do
			limiter:forget(player)
		end
	end)
end

function NetService:Start() end

-- Registers a handler. `perSecond` bounds sustained requests per player; excess requests are dropped cheaply
-- before any handler work (GDD 11.4, SEC-08). Handler errors are counted and logged, never silently swallowed.
function NetService.on(name: string, perSecond: number, handler: (Player, ...any) -> ())
	local remote = remotes[name]
	assert(remote, "unknown remote " .. name)
	local limiter = Validate.rateLimiter(perSecond, math.max(2, math.ceil(perSecond * 0.5)))
	limiters[name] = limiter
	remote.OnServerEvent:Connect(function(player: Player, ...)
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
	end)
end

function NetService.fire(player: Player, name: string, ...)
	remotes[name]:FireClient(player, ...)
end

function NetService.fireAll(name: string, ...)
	remotes[name]:FireAllClients(...)
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
