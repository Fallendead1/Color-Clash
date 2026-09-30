-- Settings panel behaviour and local application (GDD 12.1 Settings, 04.4, 11.6). Functional only: Codex restyles.
-- Values apply locally at once (camera, glide mode, shoulder, palette, reduced effects, volumes); the server validates
-- and saves asynchronously. Rapid changes are coalesced into one patch after a short idle, so a slider burst never
-- becomes a remote per tick. The row UI is generated from Prefs.Order via Settings.RowTemplate (Name label + Value
-- button that cycles); a production UI may instead call SettingsController.set(field, value) from its own controls.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Prefs = require(Shared.Settings.Prefs)

local SettingsController = {}

local player = Players.LocalPlayer
local ui, input, camera, paint, effects, remotes
local values: { [string]: any } = {}
local serverState = nil
local pendingPatch: { [string]: any } = {}
local patchToken = 0
local rows: { [string]: GuiObject } = {}
local stats = { patchesSent = 0, applied = 0 }
local groups: { [string]: SoundGroup } = {}

local PATCH_IDLE = 0.4

local function soundGroup(name: string): SoundGroup
	local g = groups[name]
	if not g then
		g = SoundService:FindFirstChild(name) :: SoundGroup?
		if not g then
			g = Instance.new("SoundGroup")
			g.Name = name
			g.Parent = SoundService
		end
		groups[name] = g :: SoundGroup
	end
	return g :: SoundGroup
end

local function palette(name: string)
	local p = Prefs.Palettes[name] or Prefs.Palettes.standard
	local out = {}
	for team, rgb in p do
		out[team] = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	end
	return out
end

-- Applies every value locally (idempotent).
local function applyAll()
	stats.applied += 1
	camera.setSettings({ sensitivity = values.sensitivity, invertY = values.invertY, reducedEffects = values.reducedEffects })
	camera.setShoulder(if values.shoulder == "left" then -1 else 1)
	input.setGlideMode(values.glideMode)
	local pal = palette(values.palette)
	local renderer = paint.renderer()
	if renderer then
		renderer:SetPalette(pal)
	end
	effects.setPalette(pal)
	player:SetAttribute("CCPalette", values.palette)
	soundGroup("CCMusic").Volume = values.musicVolume
	soundGroup("CCSfx").Volume = values.sfxVolume
end

local function refreshRows()
	for name, row in rows do
		local v = row:FindFirstChild("Value")
		if v and v:IsA("TextButton") then
			v.Text = Prefs.format(name, values[name])
		end
	end
	local st = serverState
	local status = ""
	if st then
		if st.load == "readFailed" then
			status = "Saved settings couldn't be loaded; changes are kept for this session"
		elseif st.load == "newer" or st.save == "readonly" then
			status = "Settings are read-only in this server"
		elseif st.save == "failed" then
			status = "Couldn't save — your settings still apply now"
		elseif st.save == "pending" or st.save == "saving" or next(pendingPatch) then
			status = "Saving…"
		elseif st.save == "saved" then
			status = "Saved"
		end
	end
	ui.setText("Settings.Status", status)
end

local function flushPatch()
	if next(pendingPatch) == nil then
		return
	end
	local patch = pendingPatch
	pendingPatch = {}
	remotes.SettingsPatch:FireServer(patch)
	stats.patchesSent += 1
end

-- Sets one preference: validated locally, applied at once, sent after a short idle.
function SettingsController.set(name: string, value: any): boolean
	local v = Prefs.validateField(name, value)
	if v == nil then
		return false
	end
	values[name] = v
	pendingPatch[name] = v
	applyAll()
	refreshRows()
	patchToken += 1
	local token = patchToken
	task.delay(PATCH_IDLE, function()
		if token == patchToken then
			flushPatch()
			refreshRows()
		end
	end)
	return true
end

function SettingsController.get(name: string): any
	return values[name]
end

function SettingsController.stats()
	return stats
end

function SettingsController.serverState()
	return serverState
end

local function buildRows()
	if next(rows) then
		return
	end
	for k, name in Prefs.Order do
		local row = ui.cloneTemplate("Settings.RowTemplate", "Settings.List")
		if row then
			row.Name = "Pref_" .. name
			row.LayoutOrder = k
			row:SetAttribute("PrefField", name)
			local label = row:FindFirstChild("Name")
			if label and label:IsA("TextLabel") then
				label.Text = Prefs.Fields[name].label
			end
			local button = row:FindFirstChild("Value")
			if button and button:IsA("GuiButton") then
				button.Activated:Connect(function()
					SettingsController.set(name, Prefs.nextValue(name, values[name]))
				end)
			end
			rows[name] = row
		end
	end
	refreshRows()
end

function SettingsController.start(deps)
	ui, input, camera, paint, effects, remotes = deps.ui, deps.input, deps.camera, deps.paint, deps.effects, deps.remotes
	for name, f in Prefs.Fields do
		values[name] = f.default
	end
	applyAll()
	buildRows()
	remotes.SettingsState.OnClientEvent:Connect(function(msg)
		if type(msg) ~= "table" or type(msg.profile) ~= "table" then
			return
		end
		serverState = msg
		-- server values win, except fields changed locally and not yet acknowledged
		for name in Prefs.Fields do
			local v = Prefs.validateField(name, msg.profile.settings and msg.profile.settings[name])
			if v ~= nil and pendingPatch[name] == nil then
				values[name] = v
			end
		end
		applyAll()
		refreshRows()
	end)
	ui.onAdopted(function()
		for _, row in rows do
			row:Destroy()
		end
		table.clear(rows)
		buildRows() -- rows now live in the adopted UI
	end)
	ui.onPanelChanged(function(name, what)
		if name == "Settings" and what == "close" then
			flushPatch() -- closing the panel sends at once
		end
	end)
	-- the renderer may be recreated with a map: keep the chosen palette
	paint.onChange(function(kind)
		if kind == "map" then
			local renderer = paint.renderer()
			if renderer then
				renderer:SetPalette(palette(values.palette))
			end
		end
	end)
end

return SettingsController
