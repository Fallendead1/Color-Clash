-- Validated preferences and deliberately small persistence (GDD 11.6, 11.3 SettingsService, DATA-01..04).
--
-- Profile: schema version, chosen loadout, settings, onboarding flag (shared/Settings/Prefs). No currency or progress.
-- Load: bounded retries. A failed read gives a usable default session plus a visible, non-blocking warning; defaults are
--   never written over an unknown stored profile: every write is an UpdateAsync that merges ONLY this session's dirty,
--   validated fields into the latest stored copy (also safe under concurrent sessions; unknown keys survive).
-- A stored profile with a NEWER schema is read for what we understand and never written (read-only session).
-- Writes are debounced (slider bursts collapse into one write), retried with a bound, flushed on leave/shutdown, and
--   reported to the client as pending / saved / failed.
-- Backends: the DataStore "ColorClashPrefs_v1" with scope "studio" in Studio and "live" otherwise (test keys never touch
--   live data); in dev, DevGate "PrefsBackend" = "memory" selects an in-memory store with failure injection for tests.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Prefs = require(Shared.Settings.Prefs)
local Weapons = require(Shared.Config.Weapons)
local GameConfig = require(Shared.Config.GameConfig)

local DevGate = require(script.Parent.Parent.DevGate)

local SettingsService = {}

local P = GameConfig.Persistence
local net, diagnostics
local sessions: { [Player]: any } = {}
local loadedListeners: { (Player, any) -> () } = {}

local function isKit(id: string): boolean
	return Weapons.Defs[id] ~= nil
end

---------------------------------------------------------------------------------------------------------------
-- Backends: get(key) -> (ok, value | err); update(key, transform) -> (ok, value | err)
---------------------------------------------------------------------------------------------------------------

local dataStoreBackend = nil
local function realBackend()
	if not dataStoreBackend then
		local okStore, store = pcall(function()
			return DataStoreService:GetDataStore("ColorClashPrefs_v1", if RunService:IsStudio() then "studio" else "live")
		end)
		dataStoreBackend = {
			name = "datastore",
			get = function(key: string)
				if not okStore then
					return false, tostring(store)
				end
				return pcall(function()
					return (store :: DataStore):GetAsync(key)
				end)
			end,
			update = function(key: string, transform)
				if not okStore then
					return false, tostring(store)
				end
				return pcall(function()
					return (store :: DataStore):UpdateAsync(key, function(old)
						return transform(old)
					end)
				end)
			end,
		}
	end
	return dataStoreBackend
end

-- Dev/test in-memory backend. Failure injection through SettingsService.memory().
local memory = {
	name = "memory",
	store = {} :: { [string]: any },
	failReads = 0,
	failWrites = 0,
	writes = 0,
	reads = 0,
	beforeUpdate = nil :: ((string) -> ())?,
}
function memory.get(key: string)
	memory.reads += 1
	if memory.failReads > 0 then
		memory.failReads -= 1
		return false, "injected read failure"
	end
	local v = memory.store[key]
	return true, if type(v) == "table" then table.clone(v) else v
end
function memory.update(key: string, transform)
	if memory.beforeUpdate then
		memory.beforeUpdate(key) -- simulates another session writing first
	end
	if memory.failWrites > 0 then
		memory.failWrites -= 1
		return false, "injected write failure"
	end
	local old = memory.store[key]
	local new = transform(if type(old) == "table" then table.clone(old) else old)
	if new == nil then
		return true, old -- transform cancelled the write
	end
	memory.writes += 1
	memory.store[key] = new
	return true, new
end

local function backend()
	if DevGate.enabled() and DevGate.get("PrefsBackend", nil) == "memory" then
		return memory
	end
	return realBackend()
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

local function retry(attempts: number, fn: () -> (boolean, any)): (boolean, any)
	local ok, res
	for attempt = 1, attempts do
		ok, res = fn()
		if ok then
			return true, res
		end
		if attempt < attempts then
			task.wait(P.RetryBackoffSeconds * attempt)
		end
	end
	return false, res
end

---------------------------------------------------------------------------------------------------------------
-- Session state and client sync
---------------------------------------------------------------------------------------------------------------

local function publicState(sess)
	return {
		profile = {
			loadout = sess.profile.loadout,
			onboardingDismissed = sess.profile.onboardingDismissed,
			settings = table.clone(sess.profile.settings),
		},
		load = sess.load, -- loading | new | ok | repaired | newer | readFailed
		save = sess.save, -- idle | pending | saving | saved | failed | readonly
	}
end

local function push(player: Player)
	local sess = sessions[player]
	if sess and player.Parent == Players then
		net.fire(player, "SettingsState", publicState(sess))
	end
end

local function save(player: Player, reason: string): boolean
	local sess = sessions[player]
	if not sess or next(sess.dirty) == nil then
		return true
	end
	if sess.load == "newer" then
		sess.save = "readonly"
		push(player)
		return false
	end
	if sess.load == "loading" then
		return false -- the read has not finished; the dirty fields are merged when it does
	end
	local snapshot = table.clone(sess.dirty)
	sess.save = "saving"
	local cancelled = false
	local be = backend()
	local ok, err = retry(P.WriteAttempts, function()
		return be.update(keyFor(player), function(old)
			local merged = Prefs.mergeForWrite(old, snapshot)
			if merged == nil then
				cancelled = true
			end
			return merged
		end)
	end)
	diagnostics.count("Prefs.write." .. (if ok then "ok" else "failed"))
	if ok and cancelled then
		sess.load = "newer"
		sess.save = "readonly"
	elseif ok then
		for k, v in snapshot do
			if sess.dirty[k] == v then
				sess.dirty[k] = nil -- a newer change made during the write stays dirty
			end
		end
		sess.save = if next(sess.dirty) then "pending" else "saved"
		sess.writes += 1
	else
		sess.save = "failed"
		diagnostics.event("PrefsSaveFailed", { player = player.UserId, reason = reason, err = string.sub(tostring(err), 1, 120) })
		if player.Parent == Players then
			net.fire(player, "Notice", { k = "SaveFailed" })
		end
	end
	push(player)
	return ok and not cancelled
end

local function scheduleSave(player: Player)
	local sess = sessions[player]
	if not sess then
		return
	end
	sess.token += 1
	local token = sess.token
	sess.save = if sess.load == "newer" then "readonly" else "pending"
	task.delay(P.SaveDebounceSeconds, function()
		local s = sessions[player]
		if s and s.token == token then
			save(player, "debounce")
		end
	end)
end

local function load(player: Player)
	local sess = {
		profile = Prefs.defaults(Weapons.Default),
		load = "loading",
		save = "idle",
		dirty = {},
		token = 0,
		writes = 0,
	}
	sessions[player] = sess
	local ok, stored = retry(P.ReadAttempts, function()
		return backend().get(keyFor(player))
	end)
	if sessions[player] ~= sess then
		return
	end
	-- changes made while loading (e.g. an early kit pick) win over the stored copy
	local early = table.clone(sess.dirty)
	if ok then
		local profile, status = Prefs.fromStored(stored, isKit, Weapons.Default)
		sess.profile = profile
		sess.load = status
		if status == "newer" then
			sess.save = "readonly"
		end
	else
		sess.load = "readFailed"
		diagnostics.event("PrefsReadFailed", { player = player.UserId, err = string.sub(tostring(stored), 1, 120) })
		if player.Parent == Players then
			net.fire(player, "Notice", { k = "PrefsUnavailable" })
		end
	end
	Prefs.apply(sess.profile, early)
	diagnostics.count("Prefs.load." .. sess.load)
	for _, fn in loadedListeners do
		task.spawn(fn, player, sess.profile)
	end
	push(player)
	if next(sess.dirty) then
		scheduleSave(player)
	end
end

---------------------------------------------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------------------------------------------

function SettingsService:Init(ctx)
	net = ctx.services.NetService
	diagnostics = ctx.services.DiagnosticsService
end

function SettingsService:Start()
	for _, p in Players:GetPlayers() do
		task.spawn(load, p)
	end
	Players.PlayerAdded:Connect(function(p)
		task.spawn(load, p)
	end)
	Players.PlayerRemoving:Connect(function(p)
		local sess = sessions[p]
		if sess then
			if next(sess.dirty) then
				save(p, "leave")
			end
			sessions[p] = nil
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for p, sess in sessions do
			if next(sess.dirty) then
				pending += 1
				task.spawn(function()
					save(p, "shutdown")
					pending -= 1
				end)
			end
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < P.ShutdownFlushSeconds do
			task.wait(0.1)
		end
	end)
	net.on("SettingsPatch", GameConfig.Net.SettingsRequestsPerSecond, SettingsService.patch)
end

-- Client patch: only whitelisted settings and the onboarding flag (the loadout is saved by LoadoutService).
function SettingsService.patch(player: Player, payload: any)
	local sess = sessions[player]
	if not sess then
		return
	end
	local accepted, rejected = Prefs.validatePatch(payload, isKit)
	if accepted.loadout ~= nil then
		accepted.loadout = nil
		table.insert(rejected, "loadout")
	end
	if #rejected > 0 then
		diagnostics.count("Prefs.patchRejected", #rejected)
	end
	local changed = false
	for k, v in accepted do
		local field = string.match(k, "^settings%.(.+)$")
		local current = if field then sess.profile.settings[field] else sess.profile[k]
		if current ~= v then
			changed = true
			sess.dirty[k] = v
		end
	end
	if changed then
		Prefs.apply(sess.profile, accepted)
		scheduleSave(player)
	end
	push(player)
end

function SettingsService.savedLoadout(player: Player): string?
	local sess = sessions[player]
	return if sess and sess.load ~= "loading" then sess.profile.loadout else nil
end

function SettingsService.setLoadout(player: Player, id: string)
	local sess = sessions[player]
	if not sess or not isKit(id) or sess.profile.loadout == id then
		return
	end
	sess.profile.loadout = id
	sess.dirty.loadout = id
	scheduleSave(player)
end

-- Called with (player, profile) once the stored profile (or the default session) is ready.
function SettingsService.onLoaded(fn: (Player, any) -> ())
	table.insert(loadedListeners, fn)
end

function SettingsService.state(player: Player)
	local sess = sessions[player]
	return sess and publicState(sess)
end

-- Tests/dev only.
function SettingsService.memory()
	return if DevGate.enabled() then memory else nil
end

function SettingsService.devReload(player: Player)
	if DevGate.enabled() then
		load(player)
	end
end

function SettingsService.devFlush(player: Player): boolean
	return DevGate.enabled() and save(player, "test")
end

function SettingsService.writes(player: Player): number
	local sess = sessions[player]
	return sess and sess.writes or 0
end

function SettingsService.backendName(): string
	return backend().name
end

return SettingsService
