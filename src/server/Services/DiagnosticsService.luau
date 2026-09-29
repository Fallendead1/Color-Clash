-- Counters, timings and a bounded telemetry log (GDD 11.3 DiagnosticsService, 15). No external webhooks.
-- Unknown values stay nil (never a fake zero). Server-authoritative milestones use server time.

local HttpService = game:GetService("HttpService")

local DiagnosticsService = {}

local MAX_EVENTS = 600
local MAX_TIMINGS = 512

local counters: { [string]: number } = {}
local events: { any } = {}
local eventHead = 0
local timings: { [string]: { number } } = {}
local sessionId = HttpService:GenerateGUID(false)

function DiagnosticsService:Init(_ctx) end
function DiagnosticsService:Start() end

function DiagnosticsService.sessionId(): string
	return sessionId
end

-- Increments `name` (e.g. "ShotRejected.cadence"). Cheap enough to call on hot paths.
function DiagnosticsService.count(name: string, n: number?)
	counters[name] = (counters[name] or 0) + (n or 1)
end

function DiagnosticsService.getCount(name: string): number
	return counters[name] or 0
end

function DiagnosticsService.counters(): { [string]: number }
	return table.clone(counters)
end

-- Records an event in a ring buffer. `data` must be a small table of primitives.
function DiagnosticsService.event(name: string, data: { [string]: any }?)
	eventHead = eventHead % MAX_EVENTS + 1
	events[eventHead] = {
		name = name,
		t = workspace:GetServerTimeNow(),
		data = data,
	}
	DiagnosticsService.count("event." .. name)
end

-- Returns events newest last, optionally filtered by name.
function DiagnosticsService.recent(filter: string?, limit: number?): { any }
	local out = {}
	local n = #events
	for k = 1, n do
		local idx = (eventHead + k - 1) % n + 1
		local e = events[idx]
		if e and (filter == nil or e.name == filter) then
			table.insert(out, e)
		end
	end
	if limit and #out > limit then
		return { table.unpack(out, #out - limit + 1, #out) }
	end
	return out
end

-- Timing samples in milliseconds, bounded per key.
function DiagnosticsService.time(key: string, ms: number)
	local list = timings[key]
	if not list then
		list = {}
		timings[key] = list
	end
	if #list >= MAX_TIMINGS then
		table.remove(list, 1)
	end
	table.insert(list, ms)
end

-- p50/p95/max of a timing key, or nil when no samples exist.
function DiagnosticsService.percentiles(key: string): { n: number, p50: number, p95: number, max: number }?
	local list = timings[key]
	if not list or #list == 0 then
		return nil
	end
	local sorted = table.clone(list)
	table.sort(sorted)
	local function at(p)
		return sorted[math.clamp(math.ceil(p * #sorted), 1, #sorted)]
	end
	return { n = #sorted, p50 = at(0.5), p95 = at(0.95), max = sorted[#sorted] }
end

function DiagnosticsService.resetForTests()
	table.clear(counters)
	table.clear(events)
	table.clear(timings)
	eventHead = 0
end

return DiagnosticsService
