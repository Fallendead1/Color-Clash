-- Accepted actions, projectile simulation, hits, damage and attribution (GDD 06, 07, 08, 11.3 CombatService, 11.4).
--
-- Action protocol (reliable "Action" remote, client -> server). Every message is sequenced per life:
--   { m = matchId, l = lifeId, s = sequence, a = action, t = client estimate of server time, o = muzzle, d = aim }
--   actions: Fire | SecStart | SecStop | Dash | ChargeStart | ChargeRelease | ChargeCancel | Gadget | Ultimate
-- Held weapons send one Fire per legal attack (never per frame). Continuous actions (roll/push/charge) use
-- start/stop messages; the server measures elapsed time and movement itself. The client never sends damage,
-- targets, charge durations or paint amounts.
--
-- Validation is cheapest-first: shape/types/finite -> match/life/sequence -> timestamp window -> muzzle plausibility
-- -> state (climbing, base) -> family rules (cadence, windups, cooldowns) -> atomic paint cost.
-- Weapon families live in ServerScriptService.Server.Combat.*; this module is the shared core.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Validate = require(Shared.Protocol.Validate)
local Ballistics = require(Shared.Combat.Ballistics)

local MapLoader = require(script.Parent.Parent.Map.MapLoader)
local CombatFolder = script.Parent.Parent.Combat

local CombatService = {}

local CB = GameConfig.Combat
local PROJECTILE_RADIUS = 0.15
local SUBSTEP = 1 / 60
local POSE_SECONDS = 1.0

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
local plainParams = RaycastParams.new()
local families: { [string]: any } = {}
local abilities = nil -- AbilityService (gadgets/ultimates/launch) wired in Init when present
local poses: { [Player]: { { t: number, p: Vector3 } } } = {}

local ALLOWED = { m = true, l = true, s = true, a = true, t = true, o = true, d = true }
local ACTIONS = {
	Fire = true,
	SecStart = true,
	SecStop = true,
	Dash = true,
	ChargeStart = true,
	ChargeRelease = true,
	ChargeCancel = true,
	Gadget = true,
	Ultimate = true,
}
-- Actions that attack: rejected from inside a protected base and they remove the spawn shield.
local OFFENSIVE = { Fire = true, ChargeRelease = true, Gadget = true, Ultimate = true }

---------------------------------------------------------------------------------------------------------------
-- Per-player combat state
---------------------------------------------------------------------------------------------------------------

function CombatService.state(player: Player)
	local s = players[player]
	if not s then
		s = {
			life = -1,
			lastSeq = -1,
			nextReady = 0,
			firingUntil = 0,
			charging = false,
			chargeStart = 0,
			rolling = false,
			pushing = false,
			trailLast = nil,
			trailHits = {},
			stationaryPainted = false,
			dashReady = 0,
			lastDryCue = 0,
			muzzleToggle = false,
			pending = {}, -- windup tasks (cancelled by life id checks)
		}
		players[player] = s
	end
	return s
end
local state = CombatService.state

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

local function clearContinuous(s)
	s.charging = false
	s.rolling = false
	s.pushing = false
	s.trailLast = nil
	s.stationaryPainted = false
	table.clear(s.trailHits)
end

function CombatService.onLifeStarted(player: Player, life)
	local s = state(player)
	s.life = life.lifeId
	s.lastSeq = -1
	s.nextReady = 0
	s.firingUntil = 0
	s.dashReady = 0
	clearContinuous(s)
	poses[player] = {}
	if abilities then
		abilities.onLifeStarted(player, life)
	end
end

function CombatService.onDamaged(player: Player)
	if abilities then
		abilities.onDamaged(player)
	end
end

function CombatService.onEliminated(player: Player)
	local s = players[player]
	if s then
		clearContinuous(s)
		s.firingUntil = 0
	end
	if abilities then
		abilities.onEliminated(player)
	end
end

-- Glide or climb cancels stored charge and continuous weapon actions (GDD 07.3).
function CombatService.onGlideOrClimb(player: Player)
	local s = players[player]
	if s then
		if s.charging then
			diagnostics.count("Charge.cancelledByMovement")
		end
		s.charging = false
	end
end

function CombatService.stopContinuous(player: Player, what: string)
	local s = players[player]
	if not s then
		return
	end
	if what == "roll" then
		s.rolling = false
	elseif what == "push" then
		s.pushing = false
	end
	s.trailLast = nil
	net.fire(player, "ActionResult", { k = "Stop", what = what, paint = loadout.paint(player) })
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
	plainParams.FilterType = Enum.RaycastFilterType.Include
	plainParams.FilterDescendantsInstances = matchDesc.raycastInclude
end
CombatService.rebuildParams = rebuildParams

function CombatService.worldParamsFor(teamId: number): RaycastParams
	return worldParams[teamId] or plainParams
end

function CombatService.plainParams(): RaycastParams
	return plainParams
end

function CombatService.prepareMatch(desc, matchId: number)
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
	if abilities then
		abilities.prepareMatch(desc, matchId)
	end
end

function CombatService.matchDesc()
	return matchDesc
end

function CombatService.setPaused(value: boolean)
	paused = value
	if abilities then
		abilities.setPaused(value)
	end
end

function CombatService.isPaused(): boolean
	return paused
end

-- Round end: cancel every combat entity; nothing in flight may affect the frozen result (GDD 03.4).
function CombatService.endRound()
	local cancelled = #projectiles
	table.clear(projectiles)
	for _, s in players do
		clearContinuous(s)
		s.firingUntil = 0
		table.clear(s.pending)
	end
	if cancelled > 0 then
		diagnostics.count("Projectile.cancelledAtEnd", cancelled)
	end
	if abilities then
		abilities.endRound()
	end
end

function CombatService.reset()
	CombatService.endRound()
	table.clear(attackHits)
	table.clear(attackExpiry)
	table.clear(targets)
	table.clear(poses)
	matchDesc = nil
	paused = false
	if abilities then
		abilities.reset()
	end
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

function CombatService.newAttackId(player: Player?): string
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
CombatService.markHit = markHit

-- Applies `amount` from `owner` to a victim record once per attack id. Returns the outcome string.
function CombatService.damageVictim(victim, amount: number, owner: Player?, attackId: string, weaponId: string): string
	if amount <= 0 then
		return "none"
	end
	if not markHit(attackId, victim.key) then
		diagnostics.count("Damage.duplicateSuppressed")
		return "duplicate"
	end
	local outcome
	if victim.kind == "player" then
		outcome = character.applyDamage(victim.player, amount, owner, weaponId)
	elseif victim.kind == "screen" then
		outcome = if abilities then abilities.damageScreen(victim.screen, amount, owner) else "none"
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
	diagnostics.count("Hit." .. (if victim.kind == "screen" then "screen" else outcome))
	if owner and owner.Parent == Players and victim.kind ~= "screen" then
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
local damageVictim = CombatService.damageVictim

-- A direct hit on an enemy Paint Screen (one application per attack id, like any victim).
function CombatService.hitScreen(sc, amount: number, owner: Player?, attackId: string, weaponId: string)
	diagnostics.count("Shot.blockedByScreen")
	if amount > 0 then
		damageVictim({ kind = "screen", screen = sc, key = sc.part }, amount, owner, attackId, weaponId)
	end
end

-- Feet position of a victim at `rewindSeconds` ago (players only; capped history; GDD 06.2).
local function feetAt(p: Player, life, rewindSeconds: number): Vector3
	local root = life.root
	local feetOffset = life.humanoid.HipHeight + root.Size.Y / 2
	if rewindSeconds <= 0 then
		return root.Position - Vector3.new(0, feetOffset, 0)
	end
	local hist = poses[p]
	if not hist or #hist == 0 then
		return root.Position - Vector3.new(0, feetOffset, 0)
	end
	local want = os.clock() - rewindSeconds
	local best = hist[#hist]
	for k = #hist, 1, -1 do
		best = hist[k]
		if hist[k].t <= want then
			break
		end
	end
	return best.p - Vector3.new(0, feetOffset, 0)
end

-- Candidate victims for an attacker of `ownerTeam`: living enemy match players, practice targets not on the attacker's
-- team. `rewind` (seconds, capped by the caller) is used by the precision hitscan only.
function CombatService.victimsFor(ownerTeam: number, rewind: number?): { any }
	local list = {}
	for _, p in Players:GetPlayers() do
		local life = character.life(p)
		if life and life.alive and life.inMatch and life.team ~= ownerTeam and life.root and life.humanoid then
			local feet = feetAt(p, life, rewind or 0)
			table.insert(list, { kind = "player", player = p, key = p, feet = feet, team = life.team })
		end
	end
	for _, tg in targets do
		if tg.alive and tg.team ~= ownerTeam then
			table.insert(list, { kind = "target", target = tg, key = tg.key, feet = tg.feet, team = tg.team })
		end
	end
	return list
end
local victimsFor = CombatService.victimsFor

---------------------------------------------------------------------------------------------------------------
-- Protected-base boundaries and line of sight
---------------------------------------------------------------------------------------------------------------

function CombatService.inAnyBase(p: Vector3): number?
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
local inAnyBase = CombatService.inAnyBase

-- Returns the fraction along [a,b] where the segment first crosses a base boundary, or nil.
function CombatService.baseCrossing(a: Vector3, b: Vector3): number?
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
local baseCrossing = CombatService.baseCrossing

-- Clear line from `from` to `to` for an attacker of `teamId`: no world geometry, no enemy Paint Screen, no base
-- boundary in between (blasts, fans, roll contact and splash all use this; GDD 06.1, 06.4, 08.1).
function CombatService.lineOfSight(from: Vector3, to: Vector3, teamId: number): boolean
	local dir = to - from
	if dir.Magnitude < 1e-3 then
		return true
	end
	if baseCrossing(from, to) then
		return false
	end
	local hit = Workspace:Raycast(from, dir, worldParams[teamId] or plainParams)
	return hit == nil
end

function CombatService.victimCenter(v): Vector3
	return v.feet + Vector3.new(0, CB.CapsuleHeight / 2, 0)
end

---------------------------------------------------------------------------------------------------------------
-- Paint helpers
---------------------------------------------------------------------------------------------------------------

function CombatService.paintImpact(pos: Vector3, normal: Vector3, radius: number, teamId: number, owner: Player?, creditable: boolean?)
	paint.paintSphere(pos, radius, teamId, { origin = pos + normal * 0.3, player = owner, creditable = creditable ~= false })
end
local paintImpact = CombatService.paintImpact

-- A drip paints only the first visible floor directly below (never through a roof; GDD 07.1, 07.3).
function CombatService.drip(pos: Vector3, radius: number, teamId: number, owner: Player?, creditable: boolean?)
	local hit = Workspace:Raycast(pos, Vector3.new(0, -CB.DripMaxDepth, 0), plainParams)
	if hit and hit.Normal.Y > 0.5 then
		paint.paintSphere(hit.Position, radius, teamId, {
			origin = hit.Position + Vector3.new(0, 0.3, 0),
			player = owner,
			creditable = creditable ~= false,
			minNormalY = 0.5,
		})
	end
end
local drip = CombatService.drip

---------------------------------------------------------------------------------------------------------------
-- Projectiles (swept; never Touched)
---------------------------------------------------------------------------------------------------------------

-- spec: owner, team, attackId, weapon, origin, velocity, gravity, range, damage?, screenDamage?, paintRadius?, dripRadius?,
--       dripSpacing?, onImpact?(p, kind, worldHit, victim), onExpire?(p), ignoreVictims?, radius?
function CombatService.spawnProjectile(spec)
	if #projectiles >= CB.MaxActiveProjectiles then
		-- a safety net only: reaching it in legal play is a failed test (GDD 14.3)
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
		screenDamage = spec.screenDamage, -- damage to an enemy Paint Screen when it differs from `damage`
		paintRadius = spec.paintRadius,
		dripRadius = spec.dripRadius,
		dripSpacing = spec.dripSpacing,
		nextDrip = spec.dripSpacing,
		onImpact = spec.onImpact,
		onExpire = spec.onExpire,
		ignoreVictims = spec.ignoreVictims,
		radius = spec.radius or PROJECTILE_RADIUS,
		lifetime = spec.lifetime or math.huge,
		age = 0,
	}
	table.insert(projectiles, p)
	return p
end

local function stepProjectile(p, dt: number): boolean
	p.age += dt
	local nextPos, nextVel = Ballistics.step(vector.create(p.pos.X, p.pos.Y, p.pos.Z), vector.create(p.vel.X, p.vel.Y, p.vel.Z), p.gravity, dt)
	local a = p.pos
	local b = Vector3.new(nextPos.X, nextPos.Y, nextPos.Z)
	local seg = b - a
	local segLen = seg.Magnitude
	local remaining = p.range - p.traveled
	local expire = p.age >= p.lifetime
	if segLen > remaining then
		b = a + seg.Unit * remaining
		seg = b - a
		segLen = remaining
		expire = true
	end
	if segLen < 1e-4 then
		if p.onExpire and round.acceptsImpactAt(Workspace:GetServerTimeNow()) then
			p.onExpire(p)
		end
		return true
	end
	local tBase = baseCrossing(a, b)
	local worldHit = Workspace:Raycast(a, seg, worldParams[p.team] or plainParams)
	local tWorld = if worldHit then (worldHit.Position - a).Magnitude / segLen else nil
	local bestVictim, tVictim = nil, nil
	if not p.ignoreVictims then
		for _, v in victimsFor(p.team) do
			local tv = Ballistics.sweepCapsule(vector.create(a.X, a.Y, a.Z), vector.create(b.X, b.Y, b.Z), p.radius, vector.create(v.feet.X, v.feet.Y, v.feet.Z), CB.CapsuleHeight, CB.CapsuleRadius)
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
		if expire then
			if p.onExpire and round.acceptsImpactAt(Workspace:GetServerTimeNow()) then
				p.onExpire(p)
			end
			return true
		end
		return false
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
	if kind == "world" and abilities then
		-- an enemy Paint Screen absorbs the shot: it takes the hit and the shot is consumed (GDD 08.1, ABIL-03)
		local sc = abilities.screenForPart(worldHit.Instance)
		if sc then
			CombatService.hitScreen(sc, p.screenDamage or p.damage or 0, p.owner, p.attackId, p.weapon)
			return true
		end
	end
	if p.onImpact then
		return p.onImpact(p, kind, if kind == "world" then worldHit else nil, bestVictim) ~= false
	end
	if kind == "victim" then
		damageVictim(bestVictim, p.damage, p.owner, p.attackId, p.weapon)
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

local function samplePoses()
	local now = os.clock()
	for _, p in Players:GetPlayers() do
		local life = character.life(p)
		if life and life.alive and life.root then
			local hist = poses[p]
			if not hist then
				hist = {}
				poses[p] = hist
			end
			table.insert(hist, { t = now, p = life.root.Position })
			while #hist > 0 and now - hist[1].t > POSE_SECONDS do
				table.remove(hist, 1)
			end
		end
	end
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
-- Action validation and dispatch
---------------------------------------------------------------------------------------------------------------

function CombatService.reject(player: Player, payload: any, reason: string)
	diagnostics.count("ShotRejected." .. reason)
	local s = if type(payload) == "table" and Validate.integer(payload.s, 0, 1e9) then payload.s else nil
	net.fire(player, "ActionResult", { k = "Action", ok = false, s = s, a = if type(payload) == "table" then payload.a else nil, reason = reason, paint = loadout.paint(player) })
end
local reject = CombatService.reject

-- Estimated legal muzzle from the server's view of the character (lagged by latency; tolerance covers it).
local function muzzleEstimate(life): Vector3
	return life.root.Position + Vector3.new(0, 1.1, 0)
end

-- Shared bookkeeping for an accepted attack.
function CombatService.markOffense(player: Player, s)
	s.firingUntil = os.clock() + 0.25
	character.onOffensiveAction(player)
end

-- Cadence then atomic cost. Returns true when accepted (state updated); otherwise rejects and returns false.
function CombatService.gateAndSpend(player: Player, payload, s, cadence: number, cost: number): boolean
	local now = os.clock()
	local ok, nextReady = Validate.cadenceAccept(s.nextReady, now, cadence, 0.06)
	if not ok then
		reject(player, payload, "cadence")
		return false
	end
	if cost > 0 and not loadout.trySpend(player, cost, round.matchNow()) then
		if now - s.lastDryCue > GameConfig.Tank.DryCueMinInterval then
			s.lastDryCue = now
			reject(player, payload, "dry")
		else
			diagnostics.count("ShotRejected.dry")
		end
		return false
	end
	s.nextReady = nextReady
	return true
end

-- Other clients draw disposable cues for this attack (never used for gameplay truth).
function CombatService.cue(owner: Player?, msg)
	for _, other in Players:GetPlayers() do
		if other ~= owner then
			net.fire(other, "Effect", msg)
		end
	end
end

function CombatService.handleAction(player: Player, payload: any)
	-- 1. shape and types (cheap, before any other work)
	if type(payload) ~= "table" or not Validate.oneOf(payload.a, ACTIONS) then
		diagnostics.count("ShotRejected.shape")
		return
	end
	if not Validate.shape(payload, ALLOWED, GameConfig.Net.MaxPayloadKeys) then
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
	s.lastSeq = payload.s
	-- 3. timing: the client time estimate must be recent and not in the future
	local serverNow = Workspace:GetServerTimeNow()
	if payload.t > serverNow + CB.MaxFutureSkew or payload.t < serverNow - CB.MaxAimAge then
		return reject(player, payload, "timestamp")
	end
	-- 4. muzzle plausibility
	if (payload.o - muzzleEstimate(life)).Magnitude > CB.MuzzleTolerance then
		return reject(player, payload, "origin")
	end
	-- 5. state
	local a = payload.a
	if life.climbing and a ~= "SecStop" and a ~= "ChargeCancel" then
		return reject(player, payload, "climbing")
	end
	if OFFENSIVE[a] and inAnyBase(payload.o) then
		return reject(player, payload, "base") -- players must leave the protected base to attack (GDD 06.4)
	end
	-- 6. ability state: launch transit blocks everything, a throw preparation locks weapon firing, and an attack
	-- during a launch channel cancels the channel (GDD 08.3, 08.4)
	if abilities then
		local blocked = abilities.gate(player, a)
		if blocked then
			return reject(player, payload, blocked)
		end
	end
	-- 7. dispatch
	if a == "Gadget" or a == "Ultimate" then
		if not abilities then
			return reject(player, payload, "unavailable")
		end
		return abilities.handleAction(player, payload, life, s)
	end
	local kit = loadout.kit(player)
	local family = families[kit.Family]
	if not family then
		return reject(player, payload, "family")
	end
	return family.handle(player, payload, kit, life, s)
end

function CombatService:Init(ctx)
	net = ctx.services.NetService
	diagnostics = ctx.services.DiagnosticsService
	character = ctx.services.CharacterService
	loadout = ctx.services.LoadoutService
	paint = ctx.services.PaintService
	round = ctx.services.RoundService
	team = ctx.services.TeamService
	abilities = ctx.services.AbilityService
	local deps = {
		net = net,
		diagnostics = diagnostics,
		character = character,
		loadout = loadout,
		paint = paint,
		round = round,
		team = team,
		combat = CombatService,
		abilities = abilities,
	}
	for _, m in CombatFolder:GetChildren() do
		if m:IsA("ModuleScript") then
			local fam = require(m)
			if type(fam) == "table" and fam.Family then -- helpers (e.g. Trail) are not families
				fam.init(deps)
				families[fam.Family] = fam
			end
		end
	end
end

function CombatService.family(name: string)
	return families[name]
end

function CombatService:Start()
	net.on("Action", GameConfig.Net.ActionRequestsPerSecond, CombatService.handleAction)
	net.on("HeldAim", GameConfig.Net.HeldAimUpdatesPerSecond, function(player, payload)
		local fam = families.charger
		if fam and fam.onHeldAim then
			fam.onHeldAim(player, payload)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		players[p] = nil
		poses[p] = nil
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		samplePoses()
		stepAll(dt)
		if not paused and round.isCombatLive() then
			for _, fam in families do
				if fam.tick then
					fam.tick(dt, players)
				end
			end
		end
		acc += dt
		if acc >= 0.25 then
			acc = 0
			tickTargets()
		end
	end)
end

return CombatService
