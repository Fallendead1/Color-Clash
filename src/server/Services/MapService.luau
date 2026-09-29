-- Map rotation, loading, validation and staging area (GDD 03.2 map selection, 09, 11.3 MapService).
--
-- Production maps: Models under ServerStorage.ColorClashMaps (Codex content, docs/MAP_CONTRACT.md).
-- Staging area: Workspace.ColorClashStaging containing a BasePart "StagingSpawn".
-- Dev only (DevGate): when no production maps exist, or DevGate "UseFixture" is set, the code-generated paint_lab
-- fixture is used and every descriptor is flagged isFixture = true. The fixture can never enter a production build.

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local MapLoader = require(script.Parent.Parent.Map.MapLoader)
local DevGate = require(script.Parent.Parent.DevGate)

local MapService = {}

type Entry = { id: string, template: Model, isFixture: boolean }

local diagnostics
local arenaFolder: Folder
local current = nil
local rotationIndex = 0
local rotationSeed = 0
local fixtureTemplate: Model? = nil

local function ensureFolder(parent: Instance, name: string): Folder
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f :: Folder
end

local function buildFixture()
	local dev = DevGate.devFolder()
	if not dev or fixtureTemplate then
		return
	end
	local PaintLab = require((dev :: any).fixtures.PaintLab)
	local model, staging = PaintLab.build()
	fixtureTemplate = model
	if not Workspace:FindFirstChild("ColorClashStaging") then
		staging.Parent = Workspace
	else
		staging:Destroy()
	end
end

function MapService:Init(ctx)
	diagnostics = ctx.services.DiagnosticsService
	arenaFolder = ensureFolder(Workspace, "ColorClashArena")
	rotationSeed = math.random(1, 2)
end

function MapService:Start()
	if DevGate.enabled() then
		buildFixture()
	end
end

-- The ordered rotation. Production maps alternate; the fixture appears only in dev mode.
function MapService.rotation(): { Entry }
	local list: { Entry } = {}
	local maps = ServerStorage:FindFirstChild("ColorClashMaps")
	if maps and not DevGate.get("UseFixture", false) then
		for _, m in maps:GetChildren() do
			if m:IsA("Model") and m:GetAttribute("IsFixture") ~= true then
				table.insert(list, { id = m:GetAttribute("MapId") or m.Name, template = m, isFixture = false })
			end
		end
		table.sort(list, function(a, b)
			return a.id < b.id
		end)
	end
	if #list == 0 and DevGate.enabled() then
		buildFixture()
		if fixtureTemplate then
			table.insert(list, { id = fixtureTemplate:GetAttribute("MapId"), template = fixtureTemplate, isFixture = true })
		end
	end
	return list
end

function MapService.unload()
	if current then
		current.model:Destroy()
		current = nil
	end
	arenaFolder:ClearAllChildren()
end

-- Loads the next map in the alternating rotation. Returns descriptor or nil + errors (loading failure keeps the
-- round in a recoverable state; GDD 03.6).
function MapService.loadNext(): (any?, { string })
	local rotation = MapService.rotation()
	if #rotation == 0 then
		diagnostics.event("MapLoadFailed", { reason = "no maps available" })
		return nil, { "no maps available: add Codex maps to ServerStorage.ColorClashMaps" }
	end
	rotationIndex += 1
	local entry = rotation[((rotationIndex + rotationSeed - 1) % #rotation) + 1]
	MapService.unload()
	local t0 = os.clock()
	local clone = entry.template:Clone()
	clone.Parent = arenaFolder
	local desc, errors = MapLoader.load(clone, entry.isFixture)
	local ms = (os.clock() - t0) * 1000
	diagnostics.time("map.load", ms)
	if not desc then
		clone:Destroy()
		diagnostics.event("MapLoadFailed", { map = entry.id, first = errors[1], count = #errors })
		return nil, errors
	end
	current = desc
	diagnostics.event("MapLoaded", {
		map = desc.mapId,
		version = desc.mapVersion,
		fixture = desc.isFixture,
		ms = math.floor(ms),
		scoring = desc.manifest.scoringCells,
	})
	return desc, {}
end

function MapService.current()
	return current
end

-- Safe staging position (above the staging floor).
function MapService.stagingCFrame(index: number?): CFrame
	local staging = Workspace:FindFirstChild("ColorClashStaging")
	local spawnPart = staging and staging:FindFirstChild("StagingSpawn", true)
	local base = if spawnPart and spawnPart:IsA("BasePart") then spawnPart.CFrame else CFrame.new(0, 105, 200)
	local k = (index or 0) % 8
	return base * CFrame.new((k % 4) * 4 - 6, 3, (k // 4) * 4 - 2)
end

return MapService
