-- Server entry point. Creates remotes and starts every service exactly once (GDD 11.3, 11.5).
-- Order matters only for Init (wiring); Start runs after every service is initialised.

local ServerScriptService = game:GetService("ServerScriptService")

if ServerScriptService:GetAttribute("ColorClashServerStarted") then
	warn("[ColorClash] duplicate server bootstrap ignored")
	return
end
ServerScriptService:SetAttribute("ColorClashServerStarted", true)

local Services = script.Parent.Services
local DevGate = require(script.Parent.DevGate)

local ORDER = {
	"DiagnosticsService",
	"NetService",
	"SettingsService",
	"MapService",
	"TeamService",
	"LoadoutService",
	"PaintService",
	"CombatService",
	"CharacterService",
	"RoundService",
}

local ctx = { services = {} }
for _, name in ORDER do
	ctx.services[name] = require(Services[name])
end

local t0 = os.clock()
for _, name in ORDER do
	ctx.services[name]:Init(ctx)
end
for _, name in ORDER do
	ctx.services[name]:Start()
end

ServerScriptService:SetAttribute("ColorClashServices", #ORDER)
ctx.services.DiagnosticsService.event("ServerBooted", { ms = math.floor((os.clock() - t0) * 1000), dev = DevGate.enabled() })
print(string.format("[ColorClash] server ready: %d services, dev=%s", #ORDER, tostring(DevGate.enabled())))
