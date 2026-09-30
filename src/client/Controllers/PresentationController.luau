-- Presentation hooks for Codex content (GDD 13.1, 13.3, docs/ASSET_CONTRACT.md). Code owns WHEN something plays;
-- Codex supplies WHAT plays, by key, under ReplicatedStorage.ColorClashAssets:
--   Animations/<Key> (Animation)      played on the acting character's Animator
--   Sounds/<Key>     (Sound)          positional when the cue has a position, in SoundGroup CCSfx (UI keys: CCUi)
--   Effects/<Key>    (Model/BasePart/Attachment with emitters; optional attributes Lifetime, Burst)
-- Every key is optional; a missing asset is counted (stats().missing) and skipped; nothing here affects gameplay,
-- damage or timing (a missing animation marker can never gate an attack). Transient objects are bounded.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared.Config.Weapons)

local PresentationController = {}

local player = Players.LocalPlayer
local MAX_TRANSIENT = 64
local live = 0
local stats = { played = {} :: { [string]: number }, missing = {} :: { [string]: number }, dropped = 0 }
local tracks: { [Model]: { [string]: AnimationTrack } } = {}
local loops: { [Model]: AnimationTrack? } = {}
local folder: Folder? = nil
local secondaryTrack: AnimationTrack? = nil

-- Cue kind -> presentation key(s). `%w` is replaced by the weapon id, `%k` by the ability kind.
local CUE_KEYS = {
	Shot = { sound = "Shot_%w", effect = "Muzzle_%w", anim = "Attack_%w" },
	Volley = { sound = "Shot_%w", effect = "Muzzle_%w", anim = "Attack_%w" },
	Beam = { sound = "ChargeFire", effect = "Beam", anim = "ChargeRelease" },
	ChargeStart = { sound = "ChargeStart", anim = "ChargeHold" },
	Dash = { sound = "Dash", effect = "DashWake", anim = "Dash" },
	Flick = { sound = "Melee_%w", anim = "Attack_%w" },
	Sweep = { sound = "Melee_%w", anim = "Attack_%w" },
	Burst = { sound = "Burst", effect = "Burst" },
	Throw = { sound = "Throw_%k", anim = "Throw" },
	UltPrep = { sound = "UltPrep_%k", anim = "UltPrep" },
	Storm = { sound = "Storm", effect = "Storm" },
	Fizzle = { sound = "Fizzle", effect = "Fizzle" },
	LaunchMarker = { sound = "LaunchMarker", effect = "LaunchMarker" },
}
-- Local-only presentation: continuous secondary loops for roller/brush kits.
local SECONDARY_LOOPS = { roller = "RollerSecondary", brush = "BrushSecondary" }
-- Local weapon actions (the local player receives no Effect cue for its own attacks).
local ACTION_KEYS = {
	Fire = "Shot",
	Dash = "Dash",
	ChargeStart = "ChargeStart",
	ChargeRelease = "Beam",
	Gadget = "Gadget",
	Ultimate = "UltPrep",
}
-- Looped locomotion presentation from the replicated CCMoveState attribute.
local MOVE_LOOPS = { Gliding = "Glide", Climbing = "Climb" }

local function assets(kind: string): Instance?
	local root = ReplicatedStorage:FindFirstChild("ColorClashAssets")
	return root and root:FindFirstChild(kind)
end

local function missing(key: string)
	stats.missing[key] = (stats.missing[key] or 0) + 1
end

local function played(key: string)
	stats.played[key] = (stats.played[key] or 0) + 1
end

local function expand(pattern: string?, msg): string?
	if not pattern then
		return nil
	end
	return (string.gsub(string.gsub(pattern, "%%w", tostring(msg.w or "")), "%%k", tostring(msg.kind or "")))
end

local function soundGroup(name: string): SoundGroup?
	return SoundService:FindFirstChild(name) :: SoundGroup?
end

function PresentationController.sound(key: string, position: Vector3?): boolean
	local lib = assets("Sounds")
	local template = lib and lib:FindFirstChild(key)
	if not template or not template:IsA("Sound") then
		missing("Sound." .. key)
		return false
	end
	if live >= MAX_TRANSIENT then
		stats.dropped += 1
		return false
	end
	live += 1
	local s = template:Clone()
	local holder: Instance
	if position then
		local a = Instance.new("Attachment")
		a.WorldPosition = position
		a.Parent = Workspace.Terrain
		holder = a
	else
		holder = SoundService
	end
	s.SoundGroup = soundGroup(if string.sub(key, 1, 3) == "UI_" then "CCUi" else "CCSfx") or s.SoundGroup
	s.Parent = holder
	s:Play()
	local lifetime = s:GetAttribute("Lifetime") or math.max(0.5, s.TimeLength + 0.2)
	task.delay(math.min(lifetime, 10), function()
		live -= 1
		if holder ~= SoundService then
			holder:Destroy()
		else
			s:Destroy()
		end
	end)
	played("Sound." .. key)
	return true
end

function PresentationController.effect(key: string, position: Vector3): boolean
	local lib = assets("Effects")
	local template = lib and lib:FindFirstChild(key)
	if not template then
		missing("Effect." .. key)
		return false
	end
	if live >= MAX_TRANSIENT then
		stats.dropped += 1
		return false
	end
	live += 1
	local fx = template:Clone()
	local holder: Instance = fx
	if fx:IsA("Attachment") then
		fx.WorldPosition = position
		fx.Parent = Workspace.Terrain
	else
		for _, d in fx:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		if fx:IsA("BasePart") then
			fx.Anchored, fx.CanCollide, fx.CanQuery, fx.CanTouch = true, false, false, false
			fx.Position = position
		elseif fx:IsA("Model") then
			fx:PivotTo(CFrame.new(position))
		end
		fx.Parent = folder
	end
	local burst = fx:GetAttribute("Burst")
	for _, d in fx:GetDescendants() do
		if d:IsA("ParticleEmitter") and burst then
			d:Emit(burst)
		end
	end
	task.delay(math.min(fx:GetAttribute("Lifetime") or 1.5, 10), function()
		live -= 1
		holder:Destroy()
	end)
	played("Effect." .. key)
	return true
end

function PresentationController.animate(character: Model?, key: string, looped: boolean?): AnimationTrack?
	if not character then
		return nil
	end
	local lib = assets("Animations")
	local anim = lib and lib:FindFirstChild(key)
	if not anim or not anim:IsA("Animation") then
		missing("Anim." .. key)
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local cache = tracks[character]
	if not cache then
		cache = {}
		tracks[character] = cache
		character.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				tracks[character] = nil
				loops[character] = nil
			end
		end)
	end
	local track = cache[key]
	if not track then
		local ok, t = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if not ok then
			missing("Anim." .. key)
			return nil
		end
		track = t
		cache[key] = track
	end
	track.Looped = looped == true
	track:Play(0.1)
	played("Anim." .. key)
	return track
end

-- Routes one server cue (other players' actions and world events).
function PresentationController.onCue(msg)
	local map = CUE_KEYS[msg.k]
	if not map then
		return
	end
	local pos = if typeof(msg.o) == "Vector3" then msg.o else nil
	local soundKey = expand(map.sound, msg)
	if soundKey then
		PresentationController.sound(soundKey, pos)
	end
	local effectKey = expand(map.effect, msg)
	if effectKey and pos then
		PresentationController.effect(effectKey, pos)
	end
	if msg.k == "LaunchMarker" and pos then
		if typeof(msg.f) == "Vector3" then
			PresentationController.effect("LaunchTransit", msg.f)
		end
		task.delay(math.clamp(tonumber(msg.dur) or 1, 0, 3), function()
			PresentationController.effect("LaunchLanding", pos)
		end)
	end
	local animKey = expand(map.anim, msg)
	if animKey and type(msg.u) == "number" then
		local actor = Players:GetPlayerByUserId(msg.u)
		PresentationController.animate(actor and actor.Character, animKey)
	end
end

-- Local player's own accepted-to-send actions (presentation only; the server still decides).
function PresentationController.onLocalAction(action: string)
	local character = player.Character
	if action == "ChargeReady" then
		local r = character and character:FindFirstChild("HumanoidRootPart")
		PresentationController.sound("ChargeReady", r and r.Position)
		if r then
			PresentationController.effect("ChargeReady", r.Position + Vector3.new(0, 1.1, 0))
		end
		return
	elseif action == "SecStart" or action == "SecStop" then
		local kit = Weapons.Defs[player:GetAttribute("CCWeapon") or Weapons.Default]
		local key = kit and SECONDARY_LOOPS[kit.Family]
		if key then
			if action == "SecStart" then
				secondaryTrack = PresentationController.animate(character, key, true)
			elseif secondaryTrack then
				secondaryTrack:Stop(0.1)
				secondaryTrack = nil
			end
		end
		return
	end
	local cue = ACTION_KEYS[action]
	if not cue then
		return
	end
	local weaponId = player:GetAttribute("CCWeapon") or Weapons.Default
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local map = CUE_KEYS[cue]
	if map then
		local msg = { w = weaponId, kind = "" }
		local soundKey = expand(map.sound, msg)
		if soundKey then
			PresentationController.sound(soundKey, root and root.Position)
		end
		local animKey = expand(map.anim, msg)
		if animKey then
			PresentationController.animate(character, animKey)
		end
	else
		PresentationController.animate(character, cue)
	end
end

local function watchCharacter(character: Model)
	local function refresh()
		local state = character:GetAttribute("CCMoveState")
		local current = loops[character]
		if current then
			current:Stop(0.15)
			loops[character] = nil
		end
		local key = MOVE_LOOPS[state or ""]
		if state == "Gliding" then
			PresentationController.animate(character, "GlideEntry")
		elseif current and state ~= "Climbing" then
			PresentationController.animate(character, "GlideExit")
		end
		if key then
			loops[character] = PresentationController.animate(character, key, true)
		end
	end
	character:GetAttributeChangedSignal("CCMoveState"):Connect(refresh)
end

function PresentationController.stats()
	return stats
end

function PresentationController.liveCount(): number
	return live
end

function PresentationController.start(deps)
	folder = Instance.new("Folder")
	folder.Name = "ColorClashPresentation"
	folder.Parent = Workspace
	for _, name in { "CCSfx", "CCUi" } do
		if not SoundService:FindFirstChild(name) then
			local g = Instance.new("SoundGroup")
			g.Name = name
			g.Parent = SoundService
		end
	end
	deps.remotes.Effect.OnClientEvent:Connect(function(msg)
		if type(msg) == "table" and msg.u ~= player.UserId then
			PresentationController.onCue(msg)
		end
	end)
	deps.remotes.DamageResult.OnClientEvent:Connect(function(msg)
		if type(msg) ~= "table" then
			return
		end
		if msg.k == "Hit" and msg.ok then
			PresentationController.sound("UI_HitConfirm")
		elseif msg.k == "Shielded" then
			PresentationController.sound("UI_ShieldHit")
			local victim = if type(msg.v) == "number" then Players:GetPlayerByUserId(msg.v) else nil
			local vroot = victim and victim.Character and victim.Character:FindFirstChild("HumanoidRootPart")
			if vroot then
				PresentationController.effect("ShieldHit", vroot.Position)
			end
		elseif msg.k == "Eliminated" then
			PresentationController.sound("Eliminated", if typeof(msg.pos) == "Vector3" then msg.pos else nil)
		end
	end)
	deps.remotes.Notice.OnClientEvent:Connect(function(msg)
		if type(msg) == "table" and msg.k == "FinalCue" then
			PresentationController.sound("UI_FinalCue")
		end
	end)
	deps.remotes.RoundState.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and payload.k == "Results" then
			PresentationController.sound("UI_RoundEnd")
			local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local cam = Workspace.CurrentCamera
			local at = if r then r.Position elseif cam then cam.CFrame.Position + cam.CFrame.LookVector * 12 else Vector3.zero
			PresentationController.effect("ResultsCue", at)
		end
	end)
	deps.weapon.onSend(PresentationController.onLocalAction)
	if deps.effects then
		deps.effects.onImpact(function(pos: Vector3)
			PresentationController.effect("Impact", pos)
			PresentationController.sound("Impact", pos)
		end)
	end
	if deps.ui then
		deps.ui.onPanelChanged(function(_, what)
			PresentationController.sound(if what == "open" then "UI_Confirm" else "UI_Back")
		end)
	end
	-- mantle, dry fire, low paint, glide loop, round cues, screen damage/break, elimination/spawn on every player
	if deps.movement then
		deps.movement.onMantle(function()
			PresentationController.animate(player.Character, "Mantle")
		end)
		local glideSound: Sound? = nil
		deps.movement.onState(function(_, new)
			if new == "Gliding" and not glideSound then
				local lib = assets("Sounds")
				local t = lib and lib:FindFirstChild("GlideLoop")
				if t and t:IsA("Sound") then
					glideSound = t:Clone()
					glideSound.Looped = true
					glideSound.SoundGroup = soundGroup("CCSfx") or glideSound.SoundGroup
					glideSound.Parent = SoundService
					glideSound:Play()
					played("Sound.GlideLoop")
				else
					missing("Sound.GlideLoop")
				end
			elseif new ~= "Gliding" and glideSound then
				glideSound:Destroy()
				glideSound = nil
			end
		end)
	end
	local lowPaint = false
	deps.remotes.Resource.OnClientEvent:Connect(function(msg)
		if type(msg) == "table" and type(msg.paint) == "number" then
			local low = msg.paint < 20
			if low and not lowPaint then
				PresentationController.sound("UI_LowPaint")
			end
			lowPaint = low
		end
	end)
	deps.remotes.ActionResult.OnClientEvent:Connect(function(msg)
		if type(msg) == "table" and msg.k == "Action" and msg.ok == false and msg.reason == "dry" then
			PresentationController.sound("EmptyClick")
		end
	end)
	local lastState = nil
	deps.remotes.RoundState.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and payload.k == nil and payload.state ~= lastState then
			lastState = payload.state
			if payload.state == "Intro" then
				PresentationController.sound("UI_Countdown")
			elseif payload.state == "Live" then
				PresentationController.sound("UI_RoundStart")
			end
		end
	end)
	local function watchScreen(part: Instance)
		if not part:IsA("BasePart") or part:GetAttribute("CCScreenId") == nil then
			return
		end
		part:GetAttributeChangedSignal("Health"):Connect(function()
			PresentationController.effect("ScreenHit", part.Position)
		end)
		part.AncestryChanged:Connect(function(_, parent)
			if parent == nil and (part:GetAttribute("Health") or 1) <= 0 then
				PresentationController.effect("ScreenBreak", part.Position)
				PresentationController.sound("ScreenBreak", part.Position)
			end
		end)
	end
	Workspace.DescendantAdded:Connect(watchScreen)
	local function watchAlive(p: Player)
		p:GetAttributeChangedSignal("CCAlive"):Connect(function()
			local character = p.Character
			if p:GetAttribute("CCAlive") == false then
				PresentationController.animate(character, "Eliminated")
			elseif p:GetAttribute("CCAlive") == true then
				task.defer(function()
					PresentationController.animate(p.Character, "Spawn")
				end)
			end
		end)
	end
	for _, p in Players:GetPlayers() do
		watchAlive(p)
	end
	Players.PlayerAdded:Connect(watchAlive)
	for _, p in Players:GetPlayers() do
		if p.Character then
			watchCharacter(p.Character)
		end
		p.CharacterAdded:Connect(watchCharacter)
	end
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(watchCharacter)
	end)
	player:GetAttributeChangedSignal("CCLifeId"):Connect(function()
		if player:GetAttribute("CCAlive") then
			PresentationController.sound("Spawn")
		end
	end)
end

return PresentationController
