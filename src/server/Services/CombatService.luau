-- Accepted actions, projectile simulation, hits, damage and attribution (GDD 06, 07, 11.3 CombatService, 11.4).
--
-- Action protocol (reliable "Action" remote, client -> server), one message per legal shot for held weapons:
--   { m = matchId, l = lifeId, s = sequence, a = "Fire", t = client estimate of server time, o = muzzle, d = aim }
-- The client never sends damage, targets, charge durations or paint amounts. Validation is cheapest-first:
-- shape/types/finite -> round/life/sequence -> timing -> muzzle plausibility -> state -> cadence -> atomic paint cost.
-- Only rejections are answered (ActionResult); accepted shots are visible through paint/resource/hit messages.
--
-- Projectiles are server-simulated with swept collision (segment raycast vs world + segment/capsule vs targets),
-- never Touched. One damage result per victim per attack id. Impacts count only strictly before RoundEndTime.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Weapons = require(Shared.Config.Weapons)
local Validate = require(Shared.Protocol.Validate)
local Ballistics = require(Shared.Combat.Ballistics)

local MapLoader = require(script.Parent.Parent.Map.MapLoader)

local CombatService = {}

local CB = GameConfig.Combat
local PROJECTILE_RADIUS = 0.15
local SUBSTEP = 1 / 60

local net, diagnostics, character, loadout, paint, round, team
local paused = false
local matchDesc = nil
local projectiles: { any } = {}
local attackHits: { [string]: { [any]: boolean } } = {}
local attackExpiry: { [string]: number } = {}
local attackCounter = 0
local players: { [Player]: any } = {}
local targets: { any } = {}
local worldParams = { [1] = RaycastParams.new(), [2] = RaycastParams.new() }
local downParams = RaycastParams.new()

local ALLOWED_FIRE = { m = true, l = true, s = true, a = true, t = true, o = true, d = true }
local ACTIONS = { Fire = true }

---------------------------------------------------------------------------------------------------------------
-- Per-player combat state
---------------------------------------------------------------------------------------------------------------

local function state(player: Player)
	local s = players[player]
	if not s then
		s = {
			life = -1,
			lastSeq = -1,
			nextReady = 0,
			firingUntil = 0,
			charging = false,
			rolling = false,
			pushing = false,
			lastDryCue = 0,
		}
		players[player] = s
	end
	return s
end

function CombatService.activity(player: Player)
	local s = players[player]
	if not s then
		return { firing = false, charging = false, rolling = false, pushing = false }
	end
	return {
		firing = os.clock() < s.firingUntil,
		charging = s.charging,
		rolling = s.rolling,
		pushing = s.pushing,
	}
end

function CombatService.onLifeStarted(player: Player, life)
	local s = state(player)
	s.life = life.lifeId
	s.lastSeq = -1
	s.nextReady = 0
	s.firingUntil = 0
	s.charging, s.rolling, s.pushing = false, false, false
end

function CombatService.onDamaged(_player: Player) end

function CombatService.onEliminated(player: Player)
	local s = players[player]
	if s then
		s.charging, s.rolling, s.pushing = false, false, false
		s.firingUntil = 0
	end
end

function CombatService.onGlideOrClimb(player: Player)
	local s = players[player]
	if s then
		s.charging = false -- glide/climb cancels stored charge (GDD 07.3)
	end
end

---------------------------------------------------------------------------------------------------------------
-- Match lifecycle
---------------------------------------------------------------------------------------------------------------

local function rebuildParams()
	if not matchDesc then
		return
	end
	local arena = matchDesc.model.Parent
	for teamId = 1, 2 do
		local list = table.clone(matchDesc.raycastInclude)
		local enemyScreens = arena and arena:FindFirstChild("Screens" .. (if teamId == 1 then "B" else "A"))
		if enemyScreens then
			table.insert(list, enemyScreens)
		end
		worldParams[teamId].FilterType = Enum.RaycastFilterType.Include
		worldParams[teamId].FilterDescendantsInstances = list
	end
	downParams.FilterType = Enum.RaycastFilterType.Include
	downParams.FilterDescendantsInstances = matchDesc.raycastInclude
end
CombatService.rebuildParams = rebuildParams

function CombatService.prepareMatch(desc, _matchId: number)
	matchDesc = desc
	table.clear(projectiles)
	table.clear(attackHits)
	table.clear(attackExpiry)
	table.clear(targets)
	rebuildParams()
	local markers = desc.model:FindFirstChild("Markers")
	local folder = markers and markers:FindFirstChild("PracticeTargets")
	if folder then
		for _, part in folder:GetChildren() do
			if part:IsA("BasePart") then
				local teamKey = part:GetAttribute("TargetTeam")
				table.insert(targets, {
					part = part,
					feet = part:GetAttribute("Feet") or (part.Position - Vector3.new(0, 2.75, 0)),
					team = if teamKey == "A" then 1 elseif teamKey == "B" then 2 else 0,
					health = 100,
					alive = true,
					respawnAt = nil,
					key = part,
				})
				part:SetAttribute("Health", 100)
			end
		end
	end
end

function CombatService.setPaused(value: boolean)
	paused = value
end

function CombatService.isPaused(): boolean
	return paused
end

-- Round end: cancel every combat entity; nothing in flight may affect the frozen result (GDD 03.4).
function CombatService.endRound()
	local cancelled = #projectiles
	table.clear(projectiles)
	for _, s in players do
		s.charging, s.rolling, s.pushing = false, false, false
		s.firingUntil = 0
	end
	if cancelled > 0 then
		diagnostics.count("Projectile.cancelledAtEnd", cancelled)
	end
end

function CombatService.reset()
	CombatService.endRound()
	table.clear(attackHits)
	table.clear(attackExpiry)
	table.clear(targets)
	matchDesc = nil
	paused = false
end

-- Test/dev: set a practice target's team ("A", "B" or "Any").
function CombatService.setTargetTeam(index: number, key: string)
	local tg = targets[index]
	if tg then
		tg.team = if key == "A" then 1 elseif key == "B" then 2 else 0
	end
end

function CombatService.targets()
	return targets
end

function CombatService.projectileCount(): number
	return #projectiles
end

---------------------------------------------------------------------------------------------------------------
-- Damage (single path, per-attack dedupe)
---------------------------------------------------------------------------------------------------------------

local function newAttackId(player: Player?): string
	attackCounter += 1
	return (if player then tostring(player.UserId) else "env") .. ":" .. attackCounter
end

local function markHit(attackId: string, key: any): boolean
	local set = attackHits[attackId]
	if not set then
		set = {}
		attackHits[attackId] = set
		attackExpiry[attackId] = os.clock() + 10
	end
	if set[key] then
		return false
	end
	set[key] = true
	return true
end

-- Applies `amount` from `owner` to a victim record once per attack id. Returns the outcome string.
local function damageVictim(victim, amount: number, owner: Player?, attackId: string, weaponId: string): string
	if not markHit(attackId, victim.key) then
		diagnostics.count("Damage.duplicateSuppressed")
		return "duplicate"
	end
	local outcome
	if victim.kind == "player" then
		outcome = character.applyDamage(victim.player, amount, owner, weaponId)
	else
		if not victim.target.alive then
			return "dead"
		end
		victim.target.health = math.max(0, victim.target.health - amount)
		victim.target.part:SetAttribute("Health", victim.target.health)
		if victim.target.health <= 0 then
			victim.target.alive = false
			victim.target.respawnAt = os.clock() + GameConfig.Match.RespawnSeconds
			victim.target.part.Transparency = 0.8
		end
		outcome = "applied"
	end
	if owner and owner.Parent == Players then
		net.fire(owner, "DamageResult", {
			k = if outcome == "shielded" then "Shielded" else "Hit",
			v = if victim.kind == "player" then victim.player.UserId else victim.target.part.Name,
			n = amount,
			a = attackId,
			ok = outcome == "applied",
		})
	end
	return outcome
end
CombatService.damageVictim = damageVictim

-- Candidate victims for an attacker of `ownerTeam`: living enemy match players outside their protected base, and
-- practice targets that are not on the attacker's team.
local function victimsFor(ownerTeam: number): { any }
	local list = {}
	for _, p in Players:GetPlayers() do
		local life = character.life(p)
		if life and life.alive and life.inMatch and life.team ~= ownerTeam and life.root and life.humanoid then
			local root = life.root
			local feetY = root.Position.Y - life.humanoid.HipHeight - root.Size.Y / 2
			table.insert(list, { kind = "player", player = p, key = p, feet = Vector3.new(root.Position.X, feetY, root.Position.Z), team = life.team })
		end
	end
	for _, tg in targets do
		if tg.alive and tg.team ~= ownerTeam then
			table.insert(list, { kind = "target", target = tg, key = tg.key, feet = tg.feet, team = tg.team })
		end
	end
	return list
end
CombatService.victimsFor = victimsFor

---------------------------------------------------------------------------------------------------------------
-- Protected-base boundaries: shots never cross a base boundary in either direction (GDD 06.4)
---------------------------------------------------------------------------------------------------------------

local function inAnyBase(p: Vector3): number?
	if not matchDesc then
		return nil
	end
	for teamId, vol in matchDesc.baseVolumes do
		if MapLoader.pointInVolume(vol, p) then
			return teamId
		end
	end
	return nil
end

-- Returns the fraction along [a,b] where the segment first crosses a base boundary, or nil.
local function baseCrossing(a: Vector3, b: Vector3): number?
	local sa = inAnyBase(a)
	local sb = inAnyBase(b)
	if sa == sb then
		return nil
	end
	local lo, hi = 0, 1
	for _ = 1, 10 do
		local mid = (lo + hi) / 2
		if inAnyBase(a:Lerp(b, mid)) == sa then
			lo = mid
		else
			hi = mid
		end
	end
	return lo
end

---------------------------------------------------------------------------------------------------------------
-- Projectiles
---------------------------------------------------------------------------------------------------------------

local function paintImpact(pos: Vector3, normal: Vector3, radius: number, teamId: number, owner: Player?)
	paint.paintSphere(pos, radius, teamId, { origin = pos + normal * 0.3, player = owner, creditable = true })
end

-- A drip paints only the first visible floor directly below (never through a roof; GDD 07.1, 07.3).
local function drip(pos: Vector3, radius: number, teamId: number, owner: Player?)
	local hit = Workspace:Raycast(pos, Vector3.new(0, -CB.DripMaxDepth, 0), downParams)
	if hit and hit.Normal.Y > 0.5 then
		paint.paintSphere(hit.Position, radius, teamId, { origin = hit.Position + Vector3.new(0, 0.3, 0), player = owner, creditable = true, minNormalY = 0.5 })
	end
end

function CombatService.spawnProjectile(spec)
	if #projectiles >= CB.MaxActiveProjectiles then
		-- the cap is a safety net: log the overload; the shot's cost was already charged, so this is a test failure
		diagnostics.event("ProjectileCapReached", { active = #projectiles })
		return nil
	end
	local p = {
		owner = spec.owner,
		team = spec.team,
		attackId = spec.attackId,
		weapon = spec.weapon,
		pos = spec.origin,
		vel = spec.velocity,
		gravity = spec.gravity,
		traveled = 0,
		range = spec.range,
		damage = spec.damage,
		paintRadius = spec.paintRadius,
		dripRadius = spec.dripRadius,
		dripSpacing = spec.dripSpacing,
		nextDrip = spec.dripSpacing,
		onImpact = spec.onImpact, -- optional custom impact (blasters/lobbers)
	}
	table.insert(projectiles, p)
	return p
end

-- Advances one projectile by dt. Returns true when it is finished.
local function stepProjectile(p, dt: number): boolean
	local nextPos, nextVel = Ballistics.step(vector.create(p.pos.X, p.pos.Y, p.pos.Z), vector.create(p.vel.X, p.vel.Y, p.vel.Z), p.gravity, dt)
	local a = p.pos
	local b = Vector3.new(nextPos.X, nextPos.Y, nextPos.Z)
	local seg = b - a
	local segLen = seg.Magnitude
	local remaining = p.range - p.traveled
	local expire = false
	if segLen > remaining then
		b = a + seg.Unit * remaining
		seg = b - a
		segLen = remaining
		expire = true
	end
	if segLen < 1e-4 then
		return true
	end
	-- earliest of: base boundary, world hit, victim hit
	local tBase = baseCrossing(a, b)
	local worldHit = Workspace:Raycast(a, seg, worldParams[p.team] or worldParams[1])
	local tWorld = if worldHit then (worldHit.Position - a).Magnitude / segLen else nil
	local bestVictim, tVictim = nil, nil
	if p.damage and p.damage > 0 then
		for _, v in victimsFor(p.team) do
			local tv = Ballistics.sweepCapsule(vector.create(a.X, a.Y, a.Z), vector.create(b.X, b.Y, b.Z), PROJECTILE_RADIUS, vector.create(v.feet.X, v.feet.Y, v.feet.Z), CB.CapsuleHeight, CB.CapsuleRadius)
			if tv and (tVictim == nil or tv < tVictim) then
				bestVictim, tVictim = v, tv
			end
		end
	end
	local tEnd = 1
	local kind = nil
	if tBase and tBase < tEnd then
		tEnd, kind = tBase, "base"
	end
	if tWorld and tWorld < tEnd then
		tEnd, kind = tWorld, "world"
	end
	if tVictim and tVictim <= tEnd then
		tEnd, kind = tVictim, "victim"
	end
	-- trail drips along the travelled part of the segment (spacing tied to the footprint, so low FPS leaves no gaps)
	if p.dripSpacing then
		local travelledHere = segLen * tEnd
		while p.nextDrip <= p.traveled + travelledHere do
			local f = (p.nextDrip - p.traveled) / segLen
			drip(a + seg * f, p.dripRadius, p.team, p.owner)
			p.nextDrip += p.dripSpacing
		end
	end
	p.traveled += segLen * tEnd
	p.pos = a + seg * tEnd
	p.vel = Vector3.new(nextVel.X, nextVel.Y, nextVel.Z)
	if kind == nil then
		return expire
	end
	-- impacts only count strictly before the authoritative deadline (GDD 03.4)
	if not round.acceptsImpactAt(Workspace:GetServerTimeNow()) then
		diagnostics.count("Impact.afterDeadline")
		return true
	end
	if kind == "base" then
		diagnostics.count("Shot.blockedByBase")
		return true
	end
	if p.onImpact then
		p.onImpact(p, kind, if kind == "world" then worldHit else nil, bestVictim)
		return true
	end
	if kind == "victim" then
		damageVictim(bestVictim, p.damage, p.owner, p.attackId, p.weapon)
		-- drips under a character impact may paint the supporting floor within 6 studs
		drip(p.pos, p.paintRadius, p.team, p.owner)
	elseif kind == "world" then
		paintImpact(worldHit.Position, worldHit.Normal, p.paintRadius, p.team, p.owner)
	end
	return true
end

local function stepAll(dt: number)
	if paused or #projectiles == 0 then
		return
	end
	local t0 = os.clock()
	local steps = math.max(1, math.ceil(dt / SUBSTEP))
	local h = dt / steps
	for _ = 1, steps do
		local k = 1
		while k <= #projectiles do
			if stepProjectile(projectiles[k], h) then
				projectiles[k] = projectiles[#projectiles]
				projectiles[#projectiles] = nil
			else
				k += 1
			end
		end
	end
	diagnostics.time("combat.projectiles", (os.clock() - t0) * 1000)
end

local function tickTargets()
	local now = os.clock()
	for _, tg in targets do
		if not tg.alive and tg.respawnAt and now >= tg.respawnAt then
			tg.alive = true
			tg.health = 100
			tg.respawnAt = nil
			tg.part.Transparency = 0
			tg.part:SetAttribute("Health", 100)
		end
	end
	for id, exp in attackExpiry do
		if now > exp then
			attackExpiry[id] = nil
			attackHits[id] = nil
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Action validation
---------------------------------------------------------------------------------------------------------------

local function reject(player: Player, payload: any, reason: string)
	diagnostics.count("ShotRejected." .. reason)
	local s = if type(payload) == "table" and Validate.integer(payload.s, 0, 1e9) then payload.s else nil
	net.fire(player, "ActionResult", { k = "Action", ok = false, s = s, reason = reason, paint = loadout.paint(player) })
end

-- Estimated legal muzzle from the server's view of the character (lagged by latency; tolerance covers it).
local function muzzleEstimate(life): Vector3
	return life.root.Position + Vector3.new(0, 1.1, 0)
end

function CombatService.handleAction(player: Player, payload: any)
	-- 1. shape and types (cheap, before any other work)
	if type(payload) ~= "table" or not Validate.oneOf(payload.a, ACTIONS) then
		diagnostics.count("ShotRejected.shape")
		return
	end
	if not Validate.shape(payload, ALLOWED_FIRE, GameConfig.Net.MaxPayloadKeys) then
		return reject(player, payload, "shape")
	end
	if not (Validate.integer(payload.m, 0, 1e9) and Validate.integer(payload.l, 0, 1e9) and Validate.integer(payload.s, 0, 1e9) and Validate.number(payload.t, 0, 1e12) and Validate.vector(payload.o, 100000) and Validate.unitVector(payload.d)) then
		return reject(player, payload, "invalid")
	end
	-- 2. round, life and sequence
	if payload.m ~= round.matchId() or not round.isCombatLive() then
		return reject(player, payload, "inactive")
	end
	local life = character.life(player)
	if not life or not life.alive or not life.inMatch or payload.l ~= life.lifeId or not life.root then
		return reject(player, payload, "life")
	end
	local s = state(player)
	if s.life ~= life.lifeId then
		CombatService.onLifeStarted(player, life)
	end
	if payload.s <= s.lastSeq then
		return reject(player, payload, "sequence") -- duplicate or replayed (COMBAT-02, SEC-07)
	end
	-- 3. timing: client time estimate must be recent and not in the future
	local serverNow = Workspace:GetServerTimeNow()
	if payload.t > serverNow + CB.MaxFutureSkew or payload.t < serverNow - CB.MaxAimAge then
		return reject(player, payload, "timestamp")
	end
	-- 4. muzzle plausibility
	if (payload.o - muzzleEstimate(life)).Magnitude > CB.MuzzleTolerance then
		return reject(player, payload, "origin")
	end
	-- 5. state
	if life.climbing then
		return reject(player, payload, "climbing")
	end
	if inAnyBase(payload.o) then
		return reject(player, payload, "base") -- players must leave the protected base to attack (GDD 06.4)
	end
	local kit = loadout.kit(player)
	if kit.Family ~= "projectile" then
		return reject(player, payload, "family") -- other families arrive in Phase 05
	end
	-- 6. cadence (server-measured) then 7. atomic paint cost
	local now = os.clock()
	local ok, nextReady = Validate.cadenceAccept(s.nextReady, now, kit.Cadence, 0.06)
	if not ok then
		return reject(player, payload, "cadence")
	end
	if not loadout.trySpend(player, kit.Cost, round.matchNow()) then
		s.lastSeq = payload.s
		if now - s.lastDryCue > GameConfig.Tank.DryCueMinInterval then
			s.lastDryCue = now
			return reject(player, payload, "dry")
		end
		diagnostics.count("ShotRejected.dry")
		return
	end
	s.nextReady = nextReady
	s.lastSeq = payload.s
	s.firingUntil = now + 0.25
	character.onOffensiveAction(player)
	-- accepted: deterministic spread shared with client prediction
	local dir = Ballistics.spread(vector.create(payload.d.X, payload.d.Y, payload.d.Z), kit.SpreadDegrees or 0, life.lifeId, payload.s)
	local d3 = Vector3.new(dir.X, dir.Y, dir.Z)
	local attackId = newAttackId(player)
	CombatService.spawnProjectile({
		owner = player,
		team = life.team,
		attackId = attackId,
		weapon = kit.Id,
		origin = payload.o,
		velocity = d3 * kit.ProjectileSpeed,
		gravity = kit.Gravity,
		range = kit.Range,
		damage = kit.Damage,
		paintRadius = kit.ImpactPaintRadius,
		dripRadius = kit.TrailDripRadius,
		dripSpacing = kit.TrailSampleSpacing,
	})
	diagnostics.count("ShotAccepted." .. kit.Id)
	-- disposable cue so other clients can draw the shot (never used for gameplay truth)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			net.fire(other, "Effect", { k = "Shot", u = player.UserId, w = kit.Id, o = payload.o, d = d3, tm = life.team })
		end
	end
end

function CombatService:Init(ctx)
	net = ctx.services.NetService
	diagnostics = ctx.services.DiagnosticsService
	character = ctx.services.CharacterService
	loadout = ctx.services.LoadoutService
	paint = ctx.services.PaintService
	round = ctx.services.RoundService
	team = ctx.services.TeamService
end

function CombatService:Start()
	net.on("Action", GameConfig.Net.ActionRequestsPerSecond, CombatService.handleAction)
	Players.PlayerRemoving:Connect(function(p)
		players[p] = nil
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		stepAll(dt)
		acc += dt
		if acc >= 0.25 then
			acc = 0
			tickTargets()
		end
	end)
	local _ = team
	local _w = Weapons
end

return CombatService
