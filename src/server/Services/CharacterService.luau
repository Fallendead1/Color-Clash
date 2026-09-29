-- Normalized characters, lives, health, regeneration, spawn protection, base/out-of-bounds rules, movement
-- validation and the paint-tank refill tick (GDD 04.1, 05, 06.3, 06.4, 11.3 CharacterService).
--
-- Health is server-owned (Humanoid health is display only and never reaches 0, so Roblox never kills or respawns
-- a character on its own). Every life has a LifeId; delayed callbacks check it before acting.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Rules = require(Shared.Movement.Rules)
local Validate = require(Shared.Protocol.Validate)

local MapLoader = require(script.Parent.Parent.Map.MapLoader)

local CharacterService = {}

local C = GameConfig.Combat
local H = GameConfig.Health
local MV = GameConfig.Movement

export type Life = {
	lifeId: number,
	alive: boolean,
	health: number,
	lastDamageAt: number, -- match clock
	character: Model?,
	humanoid: Humanoid?,
	root: BasePart?,
	team: number,
	shieldUntil: number, -- match clock; spawn shield
	landingProtectUntil: number,
	glideHeld: boolean,
	climbing: boolean,
	ground: string,
	hysteresis: any,
	damageLog: { { attacker: Player?, amount: number, t: number, weapon: string? } },
	lastValidPos: Vector3?,
	violations: number,
	burstAllowance: number,
	respawnAt: number?,
	eliminatedAt: number?,
	stats: { eliminations: number, assists: number, deaths: number },
	inMatch: boolean,
	lastSent: { [string]: any },
	suppressValidationUntil: number,
}

local lives: { [Player]: Life } = {}
local lifeCounter = 0
local net, diagnostics, team, loadout, paint, round, map, combat
local barriers: { Instance } = {}
local tickAccumulator = 0
local validateAccumulator = 0

local GROUPS = { "CCPlayersA", "CCPlayersB", "CCPlayersStaging", "CCBarrierA", "CCBarrierB" }

local function setupCollisionGroups()
	for _, g in GROUPS do
		if not PhysicsService:IsCollisionGroupRegistered(g) then
			PhysicsService:RegisterCollisionGroup(g)
		end
	end
	-- Opposing characters never shove or trap each other (GDD 05.4): players never collide with players.
	for _, a in { "CCPlayersA", "CCPlayersB", "CCPlayersStaging" } do
		for _, b in { "CCPlayersA", "CCPlayersB", "CCPlayersStaging" } do
			PhysicsService:CollisionGroupSetCollidable(a, b, false)
		end
	end
	-- A protected base blocks only the opposing team (GDD 06.4).
	PhysicsService:CollisionGroupSetCollidable("CCBarrierA", "CCPlayersA", false)
	PhysicsService:CollisionGroupSetCollidable("CCBarrierA", "CCPlayersB", true)
	PhysicsService:CollisionGroupSetCollidable("CCBarrierA", "CCPlayersStaging", false)
	PhysicsService:CollisionGroupSetCollidable("CCBarrierB", "CCPlayersB", false)
	PhysicsService:CollisionGroupSetCollidable("CCBarrierB", "CCPlayersA", true)
	PhysicsService:CollisionGroupSetCollidable("CCBarrierB", "CCPlayersStaging", false)
	for _, g in { "CCBarrierA", "CCBarrierB" } do
		PhysicsService:CollisionGroupSetCollidable(g, "Default", false)
		PhysicsService:CollisionGroupSetCollidable(g, g == "CCBarrierA" and "CCBarrierB" or "CCBarrierA", false)
	end
end

local function groupFor(teamId: number): string
	return if teamId == 1 then "CCPlayersA" elseif teamId == 2 then "CCPlayersB" else "CCPlayersStaging"
end

local function applyGroup(character: Model, teamId: number)
	local g = groupFor(teamId)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = g
		end
	end
end

local function normalizedDescription(): HumanoidDescription
	-- Default body, no accessories, unit scales: one fair hitbox for everyone (GDD 04.1).
	local desc = Instance.new("HumanoidDescription")
	desc.HeightScale = 1
	desc.WidthScale = 1
	desc.DepthScale = 1
	desc.HeadScale = 1
	desc.BodyTypeScale = 0
	desc.ProportionScale = 0
	return desc
end

local function newLife(player: Player): Life
	local prev = lives[player]
	lifeCounter += 1
	return {
		lifeId = lifeCounter,
		alive = false,
		health = H.Max,
		lastDamageAt = -math.huge,
		character = nil,
		humanoid = nil,
		root = nil,
		team = team.teamOf(player),
		shieldUntil = -math.huge,
		landingProtectUntil = -math.huge,
		glideHeld = false,
		climbing = false,
		ground = "None",
		hysteresis = Rules.newHysteresis("None"),
		damageLog = {},
		lastValidPos = nil,
		violations = 0,
		burstAllowance = 0,
		respawnAt = nil,
		eliminatedAt = nil,
		stats = if prev then prev.stats else { eliminations = 0, assists = 0, deaths = 0 },
		inMatch = false,
		lastSent = {},
		suppressValidationUntil = 0,
	}
end

function CharacterService:Init(ctx)
	net = ctx.services.NetService
	diagnostics = ctx.services.DiagnosticsService
	team = ctx.services.TeamService
	loadout = ctx.services.LoadoutService
	paint = ctx.services.PaintService
	round = ctx.services.RoundService
	map = ctx.services.MapService
	combat = ctx.services.CombatService
	Players.CharacterAutoLoads = false
	setupCollisionGroups()
end

local function matchNow(): number
	return round.matchNow()
end

-- Spawns (or respawns) a character at `cframe`. Returns the new life.
local function spawnAt(player: Player, cframe: CFrame, teamId: number, inMatch: boolean): Life?
	if player.Parent ~= Players then
		return nil
	end
	local life = newLife(player)
	life.team = teamId
	life.inMatch = inMatch
	lives[player] = life
	local ok, err = pcall(function()
		player:LoadCharacterWithHumanoidDescription(normalizedDescription())
	end)
	if not ok then
		diagnostics.event("SpawnFailed", { player = player.UserId, err = string.sub(tostring(err), 1, 120) })
		return nil
	end
	if lives[player] ~= life then
		return nil -- a newer spawn superseded this one while loading
	end
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return nil
	end
	local healthScript = character:FindFirstChild("Health")
	if healthScript and healthScript:IsA("Script") then
		healthScript:Destroy() -- regeneration is server-rule driven (GDD 05.4)
	end
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.MaxHealth = H.Max
	humanoid.Health = H.Max
	humanoid.WalkSpeed = MV.WalkSpeed
	humanoid.JumpPower = MV.JumpPower
	humanoid.UseJumpPower = true
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	applyGroup(character, if inMatch then teamId else 0)
	character:PivotTo(cframe + Vector3.new(0, 3, 0))
	life.character = character
	life.humanoid = humanoid
	life.root = root :: BasePart
	life.alive = true
	life.health = H.Max
	life.lastValidPos = (root :: BasePart).Position
	life.suppressValidationUntil = os.clock() + 1
	if inMatch then
		life.shieldUntil = matchNow() + C.SpawnShieldSeconds
	end
	loadout.fillTank(player)
	character:SetAttribute("CCLifeId", life.lifeId)
	character:SetAttribute("CCTeam", teamId)
	player:SetAttribute("CCLifeId", life.lifeId)
	player:SetAttribute("CCAlive", true)
	if combat then
		combat.onLifeStarted(player, life)
	end
	net.fire(player, "Resource", { life = life.lifeId, hp = life.health, paint = loadout.paint(player), ult = loadout.ultimate(player), alive = true, shield = inMatch })
	diagnostics.event("Respawned", { player = player.UserId, life = life.lifeId, match = inMatch })
	return life
end

function CharacterService.spawnInStaging(player: Player, index: number?)
	return spawnAt(player, map.stagingCFrame(index), 0, false)
end

-- Chooses a validated friendly spawn: the listed spawn with no living teammate within 3 studs.
function CharacterService.pickSpawn(teamId: number, preferIndex: number?): CFrame?
	local desc = map.current()
	if not desc then
		return nil
	end
	local list = desc.spawns[teamId]
	if not list or #list == 0 then
		return nil
	end
	local start = ((preferIndex or math.random(1, #list)) - 1) % #list
	for k = 0, #list - 1 do
		local cf = list[(start + k) % #list + 1]
		local occupied = false
		for _, l in lives do
			if l.alive and l.root and (l.root.Position - cf.Position).Magnitude < 3 then
				occupied = true
				break
			end
		end
		if not occupied then
			return cf
		end
	end
	return list[start + 1]
end

function CharacterService.spawnForMatch(player: Player, teamId: number, index: number?)
	local cf = CharacterService.pickSpawn(teamId, index)
	if not cf then
		diagnostics.event("SpawnBlocked", { player = player.UserId, reason = "no spawn" })
		return nil
	end
	return spawnAt(player, cf, teamId, true)
end

function CharacterService:Start()
	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			round.onPlayerJoined(player)
		end)
	end)
	for _, p in Players:GetPlayers() do
		task.defer(function()
			round.onPlayerJoined(p)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		lives[player] = nil
	end)
	net.on("ClientEvent", 20, function(player, payload)
		CharacterService.onClientEvent(player, payload)
	end)
	RunService.Heartbeat:Connect(function(dt)
		tickAccumulator += dt
		validateAccumulator += dt
		if tickAccumulator >= 0.1 then
			local step = tickAccumulator
			tickAccumulator = 0
			CharacterService.tick(step)
		end
		if validateAccumulator >= 0.25 then
			local step = validateAccumulator
			validateAccumulator = 0
			CharacterService.validateMovement(step)
		end
	end)
end

-- Client movement-state reports and milestones. Only whitelisted keys; values are advisory and re-validated.
function CharacterService.onClientEvent(player: Player, payload: any)
	if type(payload) ~= "table" or not Validate.oneOf(payload.k, { Move = true, PaintSynced = true, Active = true, Milestone = true }) then
		diagnostics.count("ClientEvent.rejected")
		return
	end
	local k = payload.k
	if k == "PaintSynced" then
		if Validate.shape(payload, { k = true, m = true, v = true }, 3) then
			paint.onClientSynced(player, payload.m, payload.v)
		end
	elseif k == "Move" then
		if not Validate.shape(payload, { k = true, l = true, glide = true, climb = true }, 4) then
			return
		end
		local life = lives[player]
		if life and life.alive and payload.l == life.lifeId and Validate.boolean(payload.glide) and Validate.boolean(payload.climb) then
			life.glideHeld = payload.glide
			life.climbing = payload.climb and CharacterService.validClimb(life)
			if combat and (payload.glide or payload.climb) then
				combat.onGlideOrClimb(player)
			end
			team.touch(player)
		end
	elseif k == "Active" then
		team.touch(player)
	elseif k == "Milestone" then
		if Validate.shape(payload, { k = true, name = true }, 2) and Validate.oneOf(payload.name, { FirstMove = true, FirstPaint = true, FirstGlide = true, ClientReady = true }) then
			diagnostics.event(payload.name, { player = player.UserId })
		end
	end
end

-- A climb is legal only against a registered climbable wall cell owned by the player's team (GDD 05.2).
function CharacterService.validClimb(life: Life): boolean
	local root = life.root
	if not root then
		return false
	end
	local desc = map.current()
	if not desc then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { desc.model:FindFirstChild("PaintSurfaces") }
	local look = root.CFrame.LookVector
	local hit = Workspace:Raycast(root.Position, Vector3.new(look.X, 0, look.Z).Unit * 3, params)
	if not hit then
		return false
	end
	local part = hit.Instance
	if part:GetAttribute("Climbable") ~= true then
		return false
	end
	local patch, owner = paint.wallOwnerAt(hit.Position)
	return patch ~= nil and owner == life.team
end

function CharacterService.life(player: Player): Life?
	return lives[player]
end

function CharacterService.isAlive(player: Player): boolean
	local l = lives[player]
	return l ~= nil and l.alive
end

function CharacterService.isShielded(player: Player): boolean
	local l = lives[player]
	if not l then
		return false
	end
	local now = matchNow()
	return now < l.shieldUntil or now < l.landingProtectUntil
end

-- First legal offensive action removes spawn/landing protection immediately (GDD 06.4, 08.4).
function CharacterService.onOffensiveAction(player: Player)
	local l = lives[player]
	if l then
		l.shieldUntil = -math.huge
		l.landingProtectUntil = -math.huge
	end
end

function CharacterService.inVolume(position: Vector3, kind: string, teamId: number?): boolean
	local desc = map.current()
	if not desc then
		return false
	end
	if kind == "ProtectedBase" then
		local vol = desc.baseVolumes[teamId]
		return vol ~= nil and MapLoader.pointInVolume(vol, position)
	elseif kind == "OutOfBounds" then
		for _, vol in desc.outOfBounds do
			if MapLoader.pointInVolume(vol, position) then
				return true
			end
		end
	end
	return false
end

-- Builds enemy-only collision barriers from the protected-base volumes of the loaded map.
function CharacterService.buildBarriers()
	for _, b in barriers do
		b:Destroy()
	end
	table.clear(barriers)
	local desc = map.current()
	if not desc then
		return
	end
	for teamId, vol in desc.baseVolumes do
		local b = Instance.new("Part")
		b.Name = "BaseBarrier" .. (if teamId == 1 then "A" else "B")
		b.Anchored = true
		b.CanQuery = false
		b.CanTouch = false
		b.Transparency = 1
		-- extend far upward so enemies cannot stand on top of the volume
		b.Size = vol.size + Vector3.new(0, 200, 0)
		b.CFrame = vol.cframe * CFrame.new(0, 100, 0)
		b.CollisionGroup = if teamId == 1 then "CCBarrierA" else "CCBarrierB"
		b.Parent = desc.model
		table.insert(barriers, b)
	end
end

---------------------------------------------------------------------------------------------------------------
-- Damage, elimination and respawn (single path; CombatService calls applyDamage)
---------------------------------------------------------------------------------------------------------------

-- Applies damage from `attacker` (nil = environment). Returns "applied" | "shielded" | "dead" | "friendly" | "inactive".
function CharacterService.applyDamage(victim: Player, amount: number, attacker: Player?, weapon: string?): string
	local life = lives[victim]
	if not life or not life.alive or not life.inMatch then
		return "dead"
	end
	if not round.isCombatLive() then
		return "inactive"
	end
	if attacker and team.teamOf(attacker) == life.team then
		return "friendly"
	end
	if CharacterService.isShielded(victim) then
		diagnostics.count("Damage.shielded")
		return "shielded"
	end
	local now = matchNow()
	life.health = math.max(0, life.health - amount)
	life.lastDamageAt = now
	table.insert(life.damageLog, { attacker = attacker, amount = amount, t = now, weapon = weapon })
	if #life.damageLog > 32 then
		table.remove(life.damageLog, 1)
	end
	if combat then
		combat.onDamaged(victim)
	end
	if life.humanoid then
		life.humanoid.Health = math.max(1, life.health)
	end
	if life.health <= 0 then
		CharacterService.eliminate(victim, attacker, weapon)
	end
	return "applied"
end

-- Elimination (GDD 06.3): stops actions once, credits the final damaging enemy (or the most recent qualifying hit
-- within 5 s for environmental deaths), assists >= 20 damage within 5 s, begins the 4 s respawn.
function CharacterService.eliminate(victim: Player, attacker: Player?, weapon: string?)
	local life = lives[victim]
	if not life or not life.alive then
		return
	end
	life.alive = false
	local now = matchNow()
	life.eliminatedAt = now
	local credited: Player? = attacker
	if credited == nil then
		for k = #life.damageLog, 1, -1 do
			local e = life.damageLog[k]
			if now - e.t <= C.EnvironmentalCreditWindowSeconds and e.attacker then
				credited = e.attacker
				weapon = e.weapon
				break
			end
		end
	end
	local assistTotals: { [Player]: number } = {}
	for _, e in life.damageLog do
		if e.attacker and e.attacker ~= credited and now - e.t <= C.AssistWindowSeconds then
			assistTotals[e.attacker] = (assistTotals[e.attacker] or 0) + e.amount
		end
	end
	life.stats.deaths += 1
	local assists = {}
	if credited and lives[credited] then
		lives[credited].stats.eliminations += 1
	end
	for p, dmg in assistTotals do
		if dmg >= C.AssistMinimumDamage and lives[p] and team.teamOf(p) ~= life.team then
			lives[p].stats.assists += 1
			table.insert(assists, p.UserId)
		end
	end
	if combat then
		combat.onEliminated(victim)
	end
	loadout.onEliminated(victim)
	local pos = life.root and life.root.Position
	victim:SetAttribute("CCAlive", false)
	net.fireAll("DamageResult", {
		k = "Eliminated",
		victim = victim.UserId,
		attacker = credited and credited.UserId,
		weapon = weapon,
		assists = assists,
		life = life.lifeId,
		pos = pos,
		team = life.team,
	})
	diagnostics.event("Eliminated", { victim = victim.UserId, attacker = credited and credited.UserId, weapon = weapon, life = life.lifeId })
	if life.character then
		life.character:Destroy()
		life.character = nil
	end
	life.respawnAt = now + GameConfig.Match.RespawnSeconds
	net.fire(victim, "Resource", { life = life.lifeId, alive = false, respawnAt = life.respawnAt, hp = 0 })
end

---------------------------------------------------------------------------------------------------------------
-- Ticks
---------------------------------------------------------------------------------------------------------------

local function sendResource(player: Player, life: Life)
	local msg = {
		life = life.lifeId,
		hp = math.floor(life.health + 0.5),
		paint = math.floor(loadout.paint(player) * 10 + 0.5) / 10,
		ult = math.floor(loadout.ultimate(player) * 10 + 0.5) / 10,
		shield = CharacterService.isShielded(player),
		ground = life.ground,
	}
	local changed = false
	for k, v in msg do
		if life.lastSent[k] ~= v then
			changed = true
			break
		end
	end
	if changed then
		life.lastSent = msg
		net.fire(player, "Resource", msg)
	end
end

function CharacterService.tick(dt: number)
	local live = round.isCombatLive()
	local paused = round.isPaused()
	local now = matchNow()
	for player, life in lives do
		if player.Parent ~= Players then
			continue
		end
		if not life.alive then
			if life.inMatch and life.respawnAt and now >= life.respawnAt and not paused and round.isMatchActive() then
				life.respawnAt = nil
				task.spawn(CharacterService.spawnForMatch, player, life.team)
			end
			continue
		end
		local root = life.root
		if not root or not root.Parent then
			continue
		end
		local pos = root.Position
		-- ground classification with boundary hysteresis
		local sample = paint.groundAt(pos, life.team, MV.SurfaceProbeDepth + 1)
		life.ground = Rules.updateGround(life.hysteresis, sample, os.clock(), MV.BoundaryHysteresisSeconds)
		if paused then
			sendResource(player, life)
			continue
		end
		if life.inMatch then
			-- out of bounds is an elimination with recent-hit credit (GDD 05.4)
			if CharacterService.inVolume(pos, "OutOfBounds") then
				CharacterService.eliminate(player, nil, nil)
				continue
			end
			-- enemies never stand inside a protected base; push out as a backstop to the physical barrier
			local enemy = 3 - life.team
			if CharacterService.inVolume(pos, "ProtectedBase", enemy) then
				local desc = map.current()
				local vol = desc and desc.baseVolumes[enemy]
				if vol then
					local lp = vol.cframe:PointToObjectSpace(pos)
					local h = vol.size / 2
					local dx = h.X - math.abs(lp.X)
					local dz = h.Z - math.abs(lp.Z)
					local out = if dx < dz then Vector3.new(math.sign(lp.X) * (h.X + 2), lp.Y, lp.Z) else Vector3.new(lp.X, lp.Y, math.sign(lp.Z) * (h.Z + 2))
					root.CFrame = CFrame.new(vol.cframe:PointToWorldSpace(out)) * root.CFrame.Rotation
					diagnostics.count("BaseIntrusionCorrected")
				end
			end
		end
		-- health regeneration (match clock; frozen while paused)
		if life.health < H.Max and now - life.lastDamageAt >= H.RegenDelay then
			life.health = math.min(H.Max, life.health + H.RegenRate * dt)
			if life.humanoid then
				life.humanoid.Health = math.max(1, life.health)
			end
		end
		-- paint refill
		local busy = combat and combat.activity(player) or { firing = false, charging = false, rolling = false, pushing = false }
		local act = {
			firing = busy.firing,
			charging = busy.charging,
			rolling = busy.rolling,
			pushing = busy.pushing,
			glideHeld = life.glideHeld,
		}
		local state = if life.climbing then "Climbing" elseif life.ground == "None" then "Airborne" else "Standing"
		local inOwnBase = life.inMatch and CharacterService.inVolume(pos, "ProtectedBase", life.team)
		if not life.inMatch then
			-- staging practice: refill freely so players can paint immediately (GDD 03.1)
			inOwnBase = true
		end
		local rate = Rules.refill(GameConfig.Tank, state, life.ground, act, loadout.sinceLastUse(player, now), inOwnBase)
		if rate > 0 then
			loadout.refill(player, rate * dt)
		end
		sendResource(player, life)
	end
end

-- Server displacement check (GDD 10.6): sustained impossible horizontal movement is corrected, never kicked.
function CharacterService.validateMovement(dt: number)
	if round.isPaused() then
		return
	end
	local clock = os.clock()
	for player, life in lives do
		local root = life.root
		if not life.alive or not root or not root.Parent or clock < life.suppressValidationUntil then
			if root and root.Parent then
				life.lastValidPos = root.Position
			end
			continue
		end
		local pos = root.Position
		local last = life.lastValidPos or pos
		local flat = Vector3.new(pos.X - last.X, 0, pos.Z - last.Z).Magnitude
		local maxSpeed = math.max(MV.GlideSpeed, MV.BrushPushSpeed) * 1.3
		local allowed = maxSpeed * dt + 3 + life.burstAllowance
		life.burstAllowance = 0
		if flat > allowed then
			life.violations += 1
			diagnostics.count("Movement.violation")
			if life.violations >= 3 then
				root.CFrame = CFrame.new(last) * root.CFrame.Rotation
				root.AssemblyLinearVelocity = Vector3.zero
				life.violations = 0
				diagnostics.event("MovementCorrected", { player = player.UserId, dist = math.floor(flat) })
			end
		else
			life.violations = 0
			life.lastValidPos = pos
		end
	end
end

-- CombatService grants a one-window allowance for legal bursts such as the Twin Jets dash.
function CharacterService.allowBurst(player: Player, studs: number)
	local l = lives[player]
	if l then
		l.burstAllowance += studs
	end
end

-- Server-driven teleport (Team Launch arrival, resets). Suppresses validation briefly.
function CharacterService.teleport(player: Player, cframe: CFrame)
	local l = lives[player]
	if l and l.character then
		l.character:PivotTo(cframe)
		l.lastValidPos = cframe.Position
		l.suppressValidationUntil = os.clock() + 0.75
	end
end

function CharacterService.stats(player: Player)
	local l = lives[player]
	return l and l.stats or { eliminations = 0, assists = 0, deaths = 0 }
end

function CharacterService.resetStats()
	for _, l in lives do
		l.stats = { eliminations = 0, assists = 0, deaths = 0 }
	end
end

-- Moves every player to staging (Reset). Old lives end; their ids stop matching any delayed callback.
function CharacterService.returnAllToStaging()
	local k = 0
	for _, p in Players:GetPlayers() do
		k += 1
		task.spawn(CharacterService.spawnInStaging, p, k)
	end
end

function CharacterService.clearBarriers()
	for _, b in barriers do
		b:Destroy()
	end
	table.clear(barriers)
end

return CharacterService
