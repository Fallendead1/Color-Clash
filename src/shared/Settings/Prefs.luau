--!strict
-- Player preference profile (GDD 11.6): schema version, chosen loadout, settings and onboarding. Pure: shared by the
-- server (validation, persistence merge) and the client (controls, local application). Nothing here grants power.
--
-- Stored profile: { v = SchemaVersion, loadout = kitId, onboardingDismissed = bool, settings = { [field] = value } }
-- Unknown keys found in a stored profile are PRESERVED on write (a newer server may have added them); only fields the
-- session actually changed are merged into the latest stored copy (safe under concurrent sessions).

local Prefs = {}

Prefs.SchemaVersion = 1

export type Field = {
	kind: "number" | "boolean" | "enum",
	default: any,
	min: number?,
	max: number?,
	step: number?,
	values: { string }?,
	label: string,
}

-- Order matters for UI rows.
Prefs.Order = { "sensitivity", "invertY", "glideMode", "shoulder", "palette", "reducedEffects", "musicVolume", "sfxVolume" }

Prefs.Fields = {
	sensitivity = { kind = "number", default = 1, min = 0.2, max = 3, step = 0.1, label = "Look sensitivity" },
	invertY = { kind = "boolean", default = false, label = "Invert Y" },
	-- "auto": hold on keyboard/gamepad, toggle on touch (GDD 04.3)
	glideMode = { kind = "enum", default = "auto", values = { "auto", "hold", "toggle" }, label = "Paint Glide" },
	shoulder = { kind = "enum", default = "right", values = { "right", "left" }, label = "Camera shoulder" },
	palette = { kind = "enum", default = "standard", values = { "standard", "accessible" }, label = "Team colours" },
	reducedEffects = { kind = "boolean", default = false, label = "Reduced effects" },
	musicVolume = { kind = "number", default = 0.6, min = 0, max = 1, step = 0.1, label = "Music volume" },
	sfxVolume = { kind = "number", default = 0.8, min = 0, max = 1, step = 0.1, label = "Effects volume" },
} :: { [string]: Field }

-- Team palettes (ownership ids, never RGB comparisons). "accessible" avoids a red/green or orange/blue-only cue pair
-- for common colour-vision deficiencies (yellow vs deep blue, maximal luminance difference).
-- RGB triples (pure data; clients convert with Color3.fromRGB).
Prefs.Palettes = {
	standard = { [1] = { 255, 138, 0 }, [2] = { 0, 150, 255 } },
	accessible = { [1] = { 240, 228, 66 }, [2] = { 0, 90, 181 } },
}

local function roundStep(v: number, f: Field): number
	local step = f.step or 0
	if step > 0 then
		v = (f.min or 0) + math.round((v - (f.min or 0)) / step) * step
		v = math.round(v * 1000) / 1000
	end
	return math.clamp(v, f.min or -math.huge, f.max or math.huge)
end

-- Returns a validated value for `name`, or nil when the value is unacceptable.
function Prefs.validateField(name: string, value: any): any?
	local f = Prefs.Fields[name]
	if not f then
		return nil
	end
	if f.kind == "number" then
		if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
			return nil
		end
		return roundStep(value, f)
	elseif f.kind == "boolean" then
		return if type(value) == "boolean" then value else nil
	else
		if type(value) ~= "string" then
			return nil
		end
		return if table.find(f.values :: { string }, value) then value else nil
	end
end

function Prefs.defaults(defaultLoadout: string): any
	local settings = {}
	for name, f in Prefs.Fields do
		settings[name] = f.default
	end
	return { v = Prefs.SchemaVersion, loadout = defaultLoadout, onboardingDismissed = false, settings = settings }
end

-- Reads a stored profile into a session profile. status: "new" (nothing stored), "ok", "repaired" (invalid fields
-- replaced by defaults) or "newer" (a higher schema: read what we understand, never write).
function Prefs.fromStored(stored: any, isKit: (string) -> boolean, defaultLoadout: string): (any, string)
	local profile = Prefs.defaults(defaultLoadout)
	if stored == nil then
		return profile, "new"
	end
	if type(stored) ~= "table" then
		return profile, "repaired"
	end
	local status = "ok"
	if type(stored.v) == "number" and stored.v > Prefs.SchemaVersion then
		status = "newer"
	end
	if type(stored.loadout) == "string" and isKit(stored.loadout) then
		profile.loadout = stored.loadout
	elseif stored.loadout ~= nil then
		status = if status == "newer" then status else "repaired"
	end
	if type(stored.onboardingDismissed) == "boolean" then
		profile.onboardingDismissed = stored.onboardingDismissed
	end
	if type(stored.settings) == "table" then
		for name in Prefs.Fields do
			local raw = stored.settings[name]
			if raw ~= nil then
				local v = Prefs.validateField(name, raw)
				if v ~= nil then
					profile.settings[name] = v
				elseif status ~= "newer" then
					status = "repaired"
				end
			end
		end
	end
	return profile, status
end

-- Validates a client patch. Returns the accepted changes (flat: loadout / onboardingDismissed / settings.<field>)
-- and the list of rejected keys. Unknown keys are rejected; nothing outside the schema is ever accepted.
function Prefs.validatePatch(patch: any, isKit: (string) -> boolean): ({ [string]: any }, { string })
	local accepted, rejected = {}, {}
	if type(patch) ~= "table" then
		return accepted, { "<payload>" }
	end
	local n = 0
	for key, value in patch do
		n += 1
		if n > 16 then
			table.insert(rejected, "<too many keys>")
			break
		end
		if key == "loadout" then
			if type(value) == "string" and isKit(value) then
				accepted.loadout = value
			else
				table.insert(rejected, "loadout")
			end
		elseif key == "onboardingDismissed" then
			if type(value) == "boolean" then
				accepted.onboardingDismissed = value
			else
				table.insert(rejected, key)
			end
		elseif type(key) == "string" and Prefs.Fields[key] then
			local v = Prefs.validateField(key, value)
			if v ~= nil then
				accepted["settings." .. key] = v
			else
				table.insert(rejected, key)
			end
		else
			table.insert(rejected, tostring(key))
		end
	end
	return accepted, rejected
end

-- Applies flat changes to a session profile (in place).
function Prefs.apply(profile: any, changes: { [string]: any })
	for key, v in changes do
		local field = string.match(key, "^settings%.(.+)$")
		if field then
			profile.settings[field] = v
		else
			profile[key] = v
		end
	end
end

-- Merges only `dirty` flat changes into the LATEST stored value (UpdateAsync transform). Unknown keys survive.
-- Returns nil when the stored schema is newer (the caller must not write).
function Prefs.mergeForWrite(stored: any, dirty: { [string]: any }): any?
	local out
	if type(stored) == "table" then
		if type(stored.v) == "number" and stored.v > Prefs.SchemaVersion then
			return nil
		end
		out = table.clone(stored)
		out.settings = if type(stored.settings) == "table" then table.clone(stored.settings) else {}
	else
		out = { settings = {} }
	end
	out.v = Prefs.SchemaVersion
	for key, v in dirty do
		local field = string.match(key, "^settings%.(.+)$")
		if field then
			out.settings[field] = v
		else
			out[key] = v
		end
	end
	return out
end

-- UI helper: the next value when a row's button is activated (numbers step up and wrap; enums/bools cycle).
function Prefs.nextValue(name: string, current: any): any
	local f = Prefs.Fields[name]
	if f.kind == "boolean" then
		return not current
	elseif f.kind == "enum" then
		local values = f.values :: { string }
		local i = table.find(values, current) or 0
		return values[i % #values + 1]
	end
	local nextV = roundStep((current or f.default) + (f.step or 0.1), f)
	if nextV >= (f.max :: number) and current >= (f.max :: number) - 1e-6 then
		return f.min
	end
	return nextV
end

function Prefs.format(name: string, value: any): string
	local f = Prefs.Fields[name]
	if f.kind == "boolean" then
		return if value then "On" else "Off"
	elseif f.kind == "enum" then
		return string.upper(string.sub(value, 1, 1)) .. string.sub(value, 2)
	end
	if (f.max :: number) <= 1 then
		return string.format("%d%%", math.round(value * 100))
	end
	return string.format("%.1f", value)
end

return Prefs
