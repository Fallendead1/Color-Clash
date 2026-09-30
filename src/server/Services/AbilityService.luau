-- Gadgets, ultimates and Team Launch (GDD 08, 11.3). Server-owned: the client only asks to use a kit's gadget or
-- ultimate (with its aim) or to launch toward a teammate id / "Base"; the server decides everything else.
--
-- Throwables (Splash Can, Color Burst capsule, Paintstorm beacon): swept ballistic flight that ignores character
-- bodies, collides with blocking world geometry or an ENEMY Paint Screen (own screens are ignored), sticks at the
-- first impact until its fuse expires, then resolves. Fuses and storms run on the match clock (frozen during
-- VacancyPause). Everything is cancelled at round end; delayed work checks match and life ids.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Abilities = require(Shared.Config.Abilities)
local Ballistics = require(Shared.Combat.Ballistics)
local Validate = require(Shared.Protocol.Validate)

local DevGate = require(script.Parent.Parent.DevGate)

local AbilityService = {}

local CB = GameConfig.Combat
local LAUNCH = GameConfig.Launch

local net, diagnostics, character, loadout, paint, round, combat
local paused = false
local matchDesc = nil
local throwables: { any } = {}
local storms: { any } = {}
local screens: { [Player]: any } = {}
local screenById: { [string]: any } = {}
local screenCounter = 0
local stormTickAt: { [any]: number } = {} -- per target: match-clock time of its last storm tick
local perPlayer: { [Player]: any } = {}
local folders: { [number]: Folder } = {}

local function now(): number
	return round.matchNow()
end

local function pstate(player: Player)
	local s = perPlayer[player]
	if not s then
		s = {
			lastGadget = -math.huge,
			prep = nil, -- { kind, cancel = bool }
			launch = nil, -- { phase = "channel"|"transit", ... }
			launchReady = -math.huge,
			lastDamaged = -math.huge,
		}
		perPlayer[player] = s
	end
	return s
end

---------------------------------------------------------------------------------------------------------------
-- Lifecycle hooks (called by CombatService)
---------------------------------------------------------------------------------------------------------------

function AbilityService.onLifeStarted(player: Player, _life)
	local s = pstate(player)
	s.prep = nil
	s.launch = nil
	s.lastDamaged = -math.huge
end

function AbilityService.onDamaged(player: Player)
	local s = pstate(player)
	s.lastDamaged = now()
	if s.launch and s.launch.phase == "channel" then
		AbilityService.cancelLaunch(player, "damaged") -- damage interrupts the channel (ABIL-08)
	end
end

function AbilityService.onEliminated(player: Player)
	local s = pstate(player)
	if s.prep then
		s.prep.cancel = true -- elimination during preparation cancels the throw without refund (GDD 08.3)
	end
	if s.launch then
		AbilityService.cancelLaunch(player, "eliminated")
	end
end

function AbilityService.setPaused(value: boolean)
	paused = value
end

local function destroyScreen(sc, reason: string)
	if sc.dead then
		return
	end
	sc.dead = true
	if sc.part then
		sc.part:Destroy() -- no invisible blocker survives destruction (ABIL-03)
	end
	screenById[sc.id] = nil
	if screens[sc.owner] == sc then
		screens[sc.owner] = nil
	end
	diagnostics.count("Screen.removed." .. reason)
end

function AbilityService.prepareMatch(desc, _matchId: number)
	matchDesc = desc
	table.clear(throwables)
	table.clear(storms)
	table.clear(stormTickAt)
	for _, sc in screenById do
		destroyScreen(sc, "reset")
	end
	local arena = desc.model.Parent
	for teamId = 1, 2 do
		local name = "Screens" .. (if teamId == 1 then "A" else "B")
		local f = arena:FindFirstChild(name) or Instance.new("Folder")
		f.Name = name
		f.Parent = arena
		folders[teamId] = f
	end
	-- screen folders now exist: include the enemy folder in combat and paint visibility filters
	combat.rebuildParams()
	paint.rebuildRaycastParams()
end

function AbilityService.endRound()
	table.clear(throwables)
	table.clear(storms)
	table.clear(stormTickAt)
	for _, sc in screenById do
		destroyScreen(sc, "roundEnd")
	end
	for player, s in perPlayer do
		if s.prep then
			s.prep.cancel = true
		end
		if s.launch then
			AbilityService.cancelLaunch(player, "roundEnd")
		end
	end
end

function AbilityService.reset()
	AbilityService.endRound()
	for _, f in folders do
		f:Destroy()
	end
	table.clear(folders)
	matchDesc = nil
	paused = false
end

---------------------------------------------------------------------------------------------------------------
-- Screens
---------------------------------------------------------------------------------------------------------------

function AbilityService.screenForPart(part: Instance)
	local id = part:GetAttribute("CCScreenId")
	return id and screenById[id]
end

-- Damage to a Paint Screen. The hit that destroys it is consumed by it (no pass-through).
function AbilityService.damageScreen(sc, amount: number, _owner: Player?): string
	if sc.dead then
		return "dead"
	end
	sc.health -= amount
	if sc.part then
		sc.part:SetAttribute("Health", math.max(0, sc.health))
	end
	if sc.health <= 0 then
		destroyScreen(sc, "destroyed")
	end
	return "applied"
end

local function placeScreen(player: Player, payload, life, s, g)
	local root = life.root
	local look = Vector3.new(payload.d.X, 0, payload.d.Z)
	if look.Magnitude < 1e-3 then
		return combat.reject(player, payload, "screenDirection")
	end
	look = look.Unit
	-- legal floor roughly 6 studs ahead
	local ahead = root.Position + look * g.ForwardDistance
	local floorHit = Workspace:Raycast(ahead + Vector3.new(0, 3, 0), Vector3.new(0, -12, 0), combat.plainParams())
	if not floorHit or floorHit.Normal.Y < 0.7 then
		return combat.reject(player, payload, "screenNoFloor")
	end
	local base = floorHit.Position
	local cf = CFrame.lookAt(base + Vector3.new(0, g.Height / 2 + 0.05, 0), base + Vector3.new(0, g.Height / 2 + 0.05, 0) + look)
	-- reject inside protected bases or inside geometry BEFORE charging any cost (ABIL-02)
	if combat.inAnyBase(base + Vector3.new(0, 1, 0)) or combat.inAnyBase(cf.Position) then
		return combat.reject(player, payload, "screenInBase")
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = matchDesc.raycastInclude
	local blocking = Workspace:GetPartBoundsInBox(cf, Vector3.new(g.Width - 0.5, g.Height - 0.4, g.Thickness), overlap)
	if #blocking > 0 then
		return combat.reject(player, payload, "screenBlocked")
	end
	if now() - s.lastGadget < g.MinInterval then
		return combat.reject(player, payload, "gadgetInterval")
	end
	if not loadout.trySpend(player, g.Cost, now()) then
		return combat.reject(player, payload, "dry")
	end
	s.lastGadget = now()
	AbilityService._makeScreen(player, life.team, cf, g)
	character.onOffensiveAction(player)
	diagnostics.count("Gadget.screen")
end

function AbilityService._makeScreen(player: Player, teamId: number, cf: CFrame, g)
	local old = screens[player]
	if old then
		destroyScreen(old, "replaced") -- one active screen per owner; a legal replacement removes the old one
	end
	screenCounter += 1
	local id = "screen" .. screenCounter
	local part = Instance.new("Part")
	part.Name = "PaintScreen"
	part.Anchored = true
	part.CanCollide = false -- characters pass through; it blocks shots and blast visibility only
	part.CanQuery = true
	part.CanTouch = false
	part.Size = Vector3.new(g.Width, g.Height, g.Thickness)
	part.CFrame = cf
	part.Transparency = 0.35
	part.Material = Enum.Material.ForceField
	part.Color = if teamId == 1 then Color3.fromRGB(255, 138, 0) else Color3.fromRGB(0, 150, 255)
	part:SetAttribute("CCScreenId", id)
	part:SetAttribute("CCTeam", teamId)
	part:SetAttribute("Health", g.Health)
	part.Parent = folders[teamId]
	local sc = { id = id, owner = player, team = teamId, part = part, health = g.Health, expires = now() + g.Lifetime, dead = false }
	screens[player] = sc
	screenById[id] = sc
	return sc
end

-- Tests/dev only: place a screen for an arbitrary team (solo tests need an ENEMY screen). Refused outside dev mode.
function AbilityService.devPlaceScreen(owner: Player, teamId: number, cf: CFrame)
	if not DevGate.enabled() or not folders[teamId] then
		return nil
	end
	return AbilityService._makeScreen(owner, teamId, cf, Abilities.Gadgets.paint_screen)
end

---------------------------------------------------------------------------------------------------------------
-- Throwables
---------------------------------------------------------------------------------------------------------------

local function throwableParams(teamId: number): RaycastParams
	return combat.worldParamsFor(teamId) -- world geometry + ENEMY screens; bodies are never in this list
end

local function spawnThrowable(player: Player, life, payload, spec)
	local dir = Vector3.new(payload.d.X, payload.d.Y, payload.d.Z)
	local t = {
		owner = player,
		team = life.team,
		kind = spec.kind,
		def = spec.def,
		pos = payload.o,
		vel = dir * spec.def.ThrowSpeed + Vector3.new(0, spec.def.ThrowUpSpeed, 0),
		stuck = false,
		normal = Vector3.yAxis,
		fuseAt = now() + spec.def.Fuse,
		expireAt = now() + (spec.def.MaxLifetime or 6),
		attackId = combat.newAttackId(player),
		matchId = round.matchId(),
		floorContact = false,
	}
	if #throwables >= CB.MaxActiveThrowables then
		diagnostics.event("ThrowableCapReached", { active = #throwables })
		return nil
	end
	table.insert(throwables, t)
	combat.cue(nil, { k = "Throw", id = t.attackId, kind = t.kind, o = t.pos, v = t.vel, g = spec.def.Gravity, fuse = spec.def.Fuse, tm = t.team })
	return t
end

-- Blast with line-of-sight falloff; no self/friendly damage; one application per victim (same attack id).
local function blast(t, innerR: number, innerD: number, outerR: number, outerD: number, paintR: number, creditable: boolean)
	local pos = t.pos
	local center = pos + t.normal * 0.3
	for _, v in combat.victimsFor(t.team) do
		local dist = math.max(0, Ballistics.pointCapsuleDistance(vector.create(pos.X, pos.Y, pos.Z), vector.create(v.feet.X, v.feet.Y, v.feet.Z), CB.CapsuleHeight, CB.CapsuleRadius))
		local dmg = Ballistics.falloff(dist, innerR, innerD, outerR, outerD)
		if dmg > 0 and combat.lineOfSight(center, combat.victimCenter(v), t.team) then
			combat.damageVictim(v, dmg, t.owner, t.attackId, t.def.Id)
		end
	end
	for _, sc in screenById do
		if sc.team ~= t.team and not sc.dead then
			local lp = sc.part.CFrame:PointToObjectSpace(center)
			local h = sc.part.Size / 2
			local closest = sc.part.CFrame:PointToWorldSpace(Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z)))
			local dmg = Ballistics.falloff((closest - center).Magnitude, innerR, innerD, outerR, outerD)
			if dmg > 0 then
				combat.hitScreen(sc, dmg, t.owner, t.attackId, t.def.Id)
			end
		end
	end
	paint.paintSphere(pos, paintR, t.team, { origin = center, player = t.owner, creditable = creditable })
	combat.cue(nil, { k = "Burst", o = pos, r = paintR, tm = t.team })
end

local function resolve(t)
	if t.kind == "splash_can" then
		local d = t.def
		blast(t, d.InnerRadius, d.InnerDamage, d.OuterRadius, d.OuterDamage, d.PaintRadius, true)
		diagnostics.count("Gadget.canExploded")
	elseif t.kind == "color_burst" then
		local d = t.def
		blast(t, d.InnerRadius, d.InnerDamage, d.OuterRadius, d.OuterDamage, d.PaintRadius, false) -- ultimate paint: no meter
		diagnostics.count("Ultimate.burstExploded")
	elseif t.kind == "paintstorm" then
		if t.stuck and t.normal.Y > 0.7 and not t.onScreen and #storms < CB.MaxActiveStorms then
			table.insert(storms, {
				owner = t.owner,
				team = t.team,
				center = t.pos,
				def = t.def,
				endsAt = now() + t.def.Duration,
				nextTick = now(),
				attackBase = t.attackId,
				ticks = 0,
			})
			combat.cue(nil, { k = "Storm", o = t.pos, r = t.def.Radius, dur = t.def.Duration, tm = t.team })
			diagnostics.count("Ultimate.stormStarted")
		else
			combat.cue(nil, { k = "Fizzle", o = t.pos, tm = t.team }) -- no legal supporting floor: explicit cue
			diagnostics.count("Ultimate.stormFizzled")
		end
	end
end

local function stepThrowables(dt: number)
	local mNow = now()
	local k = 1
	while k <= #throwables do
		local t = throwables[k]
		local done = false
		if t.matchId ~= round.matchId() then
			done = true
		elseif t.onScreen and t.onScreen.dead then
			-- the enemy screen it stuck to is gone: resume falling from here
			t.onScreen = nil
			t.stuck = false
			t.vel = Vector3.zero
		elseif not t.stuck then
			local np, nv = Ballistics.step(vector.create(t.pos.X, t.pos.Y, t.pos.Z), vector.create(t.vel.X, t.vel.Y, t.vel.Z), t.def.Gravity, dt)
			local b = Vector3.new(np.X, np.Y, np.Z)
			local seg = b - t.pos
			local hit = if seg.Magnitude > 1e-4 then Workspace:Raycast(t.pos, seg, throwableParams(t.team)) else nil
			local tBase = combat.baseCrossing(t.pos, b)
			if tBase and (not hit or (hit.Position - t.pos).Magnitude / seg.Magnitude > tBase) then
				-- a throwable never enters a protected base: it stops at the boundary and resolves there
				t.pos = t.pos + seg * math.max(0, tBase - 0.01)
				t.stuck = true
				t.normal = Vector3.yAxis
			elseif hit then
				t.pos = hit.Position
				t.normal = hit.Normal
				t.stuck = true -- sticks at the first blocking impact until the fuse expires
				local sc = AbilityService.screenForPart(hit.Instance)
				t.onScreen = sc
			else
				t.pos = b
				t.vel = Vector3.new(nv.X, nv.Y, nv.Z)
			end
		end
		if not done and (mNow >= t.fuseAt or mNow >= t.expireAt) then
			if round.acceptsImpactAt(Workspace:GetServerTimeNow()) then
				resolve(t)
			end
			done = true
		end
		if done then
			throwables[k] = throwables[#throwables]
			throwables[#throwables] = nil
		else
			k += 1
		end
	end
end

-- Storm tick: rain rays from above; overhead geometry blocks paint and damage (GDD 08.3, ABIL-06).
local rainParams = RaycastParams.new()
rainParams.FilterType = Enum.RaycastFilterType.Include
local function stepStorms()
	if #storms == 0 or not matchDesc then
		return
	end
	rainParams.FilterDescendantsInstances = matchDesc.raycastInclude
	local mNow = now()
	local k = 1
	while k <= #storms do
		local st = storms[k]
		if mNow >= st.endsAt or not round.isCombatLive() then
			storms[k] = storms[#storms]
			storms[#storms] = nil
			continue
		end
		if mNow >= st.nextTick then
			st.nextTick += st.def.TickInterval
			st.ticks += 1
			local d = st.def
			local top = st.center.Y + d.RainHeight
			local spacing = d.RainSampleSpacing
			for x = -d.Radius, d.Radius, spacing do
				for z = -d.Radius, d.Radius, spacing do
					if x * x + z * z <= d.Radius * d.Radius then
						local from = Vector3.new(st.center.X + x, top, st.center.Z + z)
						local hit = Workspace:Raycast(from, Vector3.new(0, -(d.RainHeight + 12), 0), rainParams)
						if hit and hit.Normal.Y > 0.5 then
							-- only the first surface a ray meets is painted: never through a roof
							paint.paintSphere(hit.Position, spacing * 0.75, st.team, {
								origin = hit.Position + Vector3.new(0, 0.5, 0),
								player = st.owner,
								creditable = false, -- ultimate paint grants no meter
								minNormalY = 0.5,
							})
						end
					end
				end
			end
			-- damage: one tick per target per interval, across overlapping storms (no multiplication)
			for _, v in combat.victimsFor(st.team) do
				local flat = Vector3.new(v.feet.X - st.center.X, 0, v.feet.Z - st.center.Z)
				if flat.Magnitude <= d.Radius and math.abs(v.feet.Y - st.center.Y) < d.RainHeight then
					local head = v.feet + Vector3.new(0, CB.CapsuleHeight, 0)
					local cover = Workspace:Raycast(Vector3.new(head.X, top, head.Z), Vector3.new(0, head.Y - top + 0.1, 0), rainParams)
					if not cover then
						local last = stormTickAt[v.key]
						if last == nil or mNow - last >= d.TickInterval - 1e-3 then
							stormTickAt[v.key] = mNow
							combat.damageVictim(v, d.TickDamage, st.owner, st.attackBase .. ":t" .. st.ticks, d.Id)
						end
					end
				end
			end
		end
		k += 1
	end
end

---------------------------------------------------------------------------------------------------------------
-- Gadget / ultimate actions
---------------------------------------------------------------------------------------------------------------

-- Preparation window: nothing is charged until release; elimination/round end cancel (gadgets: no cost).
local function prepare(player: Player, life, seconds: number, onRelease: () -> ())
	local s = pstate(player)
	local prep = { cancel = false }
	s.prep = prep
	local lifeId, matchId = life.lifeId, round.matchId()
	task.delay(seconds, function()
		if s.prep == prep then
			s.prep = nil
		end
		local l = character.life(player)
		if prep.cancel or not l or l.lifeId ~= lifeId or not l.alive or round.matchId() ~= matchId or not round.isCombatLive() then
			diagnostics.count("Prep.cancelled")
			return
		end
		onRelease()
	end)
end

-- Called by CombatService for every validated action before dispatch. Returns a rejection reason or nil.
local ATTACKS = { Fire = true, ChargeStart = true, ChargeRelease = true, SecStart = true, Dash = true, Gadget = true, Ultimate = true }
local WEAPON_LOCKED = { Fire = true, ChargeStart = true, ChargeRelease = true, SecStart = true, Dash = true }
function AbilityService.gate(player: Player, action: string): string?
	local s = perPlayer[player]
	if not s then
		return nil
	end
	local L = s.launch
	if L and L.phase == "transit" then
		return "launching" -- no firing in transit
	end
	if L and L.phase == "channel" and ATTACKS[action] then
		AbilityService.cancelLaunch(player, "attacked") -- another attack cancels the channel; the attack proceeds
	end
	if s.prep and WEAPON_LOCKED[action] then
		return "preparing" -- only the short throw preparation locks weapon firing
	end
	return nil
end

function AbilityService.handleAction(player: Player, payload, life, _combatState)
	local kit = loadout.kit(player)
	local s = pstate(player)
	if s.prep then
		return combat.reject(player, payload, "preparing")
	end
	if payload.a == "Gadget" then
		local g = Abilities.Gadgets[kit.Gadget]
		if g.Kind == "screen" then
			return placeScreen(player, payload, life, s, g)
		end
		-- Splash Can: one active per owner, 0.75 s between releases, paint checked now, charged at release
		for _, t in throwables do
			if t.owner == player and t.kind == "splash_can" then
				return combat.reject(player, payload, "canActive")
			end
		end
		if now() - s.lastGadget < g.MinInterval then
			return combat.reject(player, payload, "gadgetInterval")
		end
		if loadout.paint(player) + 1e-6 < g.Cost then
			return combat.reject(player, payload, "dry")
		end
		local aim = payload
		prepare(player, life, g.Prep, function()
			if not loadout.trySpend(player, g.Cost, now()) then
				diagnostics.count("Gadget.dryAtRelease")
				return
			end
			s.lastGadget = now()
			character.onOffensiveAction(player)
			local l = character.life(player)
			spawnThrowable(player, l, { o = l.root.Position + Vector3.new(0, 1.3, 0), d = aim.d }, { kind = "splash_can", def = g })
			diagnostics.count("Gadget.canThrown")
		end)
		return
	elseif payload.a == "Ultimate" then
		local u = Abilities.Ultimates[kit.Ultimate]
		if not loadout.spendUltimate(player) then
			return combat.reject(player, payload, "ultimateNotReady") -- a full meter is spent atomically, or nothing
		end
		character.onOffensiveAction(player)
		diagnostics.count("Ultimate.activated." .. u.Id)
		combat.cue(player, { k = "UltPrep", u = player.UserId, kind = u.Id, tm = life.team })
		local aim = payload
		prepare(player, life, u.Prep, function()
			local l = character.life(player)
			spawnThrowable(player, l, { o = l.root.Position + Vector3.new(0, 1.3, 0), d = aim.d }, { kind = u.Id, def = u })
		end)
		return
	end
	return combat.reject(player, payload, "action")
end

---------------------------------------------------------------------------------------------------------------
-- Team Launch (GDD 08.4)
---------------------------------------------------------------------------------------------------------------

local function sendLaunchState(player: Player, st: string, extra)
	if st == "rejected" then
		diagnostics.count("Launch.rejected." .. tostring(extra and extra.reason))
	end
	local msg = { k = "Launch", state = st }
	for k, v in extra or {} do
		msg[k] = v
	end
	net.fire(player, "ActionResult", msg)
end

-- A clear landing floor near `center`: floor below, standing clearance, not inside an enemy base or OOB.
local function findLanding(center: Vector3, teamId: number): Vector3?
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = matchDesc.raycastInclude
	local offsets = { Vector3.zero }
	for ring = 1, 2 do
		for k = 0, 7 do
			local a = k * math.pi / 4
			table.insert(offsets, Vector3.new(math.cos(a), 0, math.sin(a)) * (ring * LAUNCH.LandingSearchRadius / 2))
		end
	end
	for _, off in offsets do
		local probe = center + off
		local hit = Workspace:Raycast(probe + Vector3.new(0, 4, 0), Vector3.new(0, -10, 0), combat.plainParams())
		if hit and hit.Normal.Y > 0.7 then
			local spot = hit.Position
			local enemyBase = combat.inAnyBase(spot + Vector3.new(0, 1, 0))
			if (enemyBase == nil or enemyBase == teamId) and not character.inVolume(spot, "OutOfBounds") then
				local blocking = Workspace:GetPartBoundsInBox(CFrame.new(spot + Vector3.new(0, 3.1, 0)), Vector3.new(2.6, 5.4, 2.6), overlap)
				if #blocking == 0 then
					return spot
				end
			end
		end
	end
	return nil
end
AbilityService.findLanding = findLanding

local function clearAt(spot: Vector3): boolean
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = matchDesc.raycastInclude
	return #Workspace:GetPartBoundsInBox(CFrame.new(spot + Vector3.new(0, 3.1, 0)), Vector3.new(2.6, 5.4, 2.6), overlap) == 0
end

-- A validated friendly spawn: clear of geometry, preferring one without a teammate on it.
local function safeSpawn(teamId: number, avoid: Vector3?): Vector3?
	local list = matchDesc.spawns[teamId] or {}
	local preferred = character.pickSpawn(teamId, nil)
	if preferred and clearAt(preferred.Position) and not (avoid and (preferred.Position - avoid).Magnitude < 1) then
		return preferred.Position
	end
	for _, cf in list do
		if clearAt(cf.Position) and not (avoid and (cf.Position - avoid).Magnitude < 1) then
			return cf.Position
		end
	end
	return nil
end

function AbilityService.cancelLaunch(player: Player, reason: string)
	local s = pstate(player)
	local L = s.launch
	if not L then
		return
	end
	s.launch = nil
	local life = character.life(player)
	if life then
		life.launching = false
		if life.root and life.root.Anchored and L.phase == "transit" then
			life.root.Anchored = false
		end
	end
	diagnostics.count("Launch.cancel." .. reason)
	sendLaunchState(player, "cancelled", { reason = reason })
end

function AbilityService.requestLaunch(player: Player, payload)
	if type(payload) ~= "table" or not Validate.shape(payload, { target = true }, 1) then
		return sendLaunchState(player, "rejected", { reason = "invalid" })
	end
	local targetKey = payload.target
	if not (targetKey == "Base" or Validate.integer(targetKey, -1e12, 1e12)) then
		return sendLaunchState(player, "rejected", { reason = "invalid" })
	end
	if not round.isCombatLive() then
		return sendLaunchState(player, "rejected", { reason = "inactive" })
	end
	local life = character.life(player)
	local s = pstate(player)
	if not life or not life.alive or not life.inMatch or not life.root then
		return sendLaunchState(player, "rejected", { reason = "notAlive" })
	end
	if s.launch then
		return sendLaunchState(player, "rejected", { reason = "alreadyLaunching" })
	end
	if now() < s.launchReady then
		return sendLaunchState(player, "rejected", { reason = "cooldown" })
	end
	local act = combat.activity(player)
	if act.firing or act.charging or act.rolling or act.pushing or s.prep then
		return sendLaunchState(player, "rejected", { reason = "attacking" })
	end
	if now() - s.lastDamaged < LAUNCH.RecentDamageBlockSeconds then
		return sendLaunchState(player, "rejected", { reason = "recentlyDamaged" })
	end
	local ground = life.ground
	local targetPlayer: Player? = nil
	if targetKey == "Base" then
		if ground == "Enemy" or ground == "None" then
			return sendLaunchState(player, "rejected", { reason = "illegalFloor" })
		end
	else
		if ground ~= "Own" and ground ~= "Base" then
			return sendLaunchState(player, "rejected", { reason = "notOnOwnPaint" })
		end
		targetPlayer = Players:GetPlayerByUserId(targetKey)
		local tl = targetPlayer and character.life(targetPlayer)
		if not targetPlayer or targetPlayer == player or not tl or not tl.alive or not tl.inMatch or tl.team ~= life.team then
			return sendLaunchState(player, "rejected", { reason = "badTarget" }) -- cross-team / dead / self (SEC-02)
		end
	end
	s.launch = { phase = "channel", target = targetKey, targetPlayer = targetPlayer, startPos = life.root.Position, departAt = now() + LAUNCH.ChannelSeconds, lifeId = life.lifeId }
	sendLaunchState(player, "channel", { departAt = s.launch.departAt })
	diagnostics.count("Launch.channelStarted")
end

local function stepLaunches()
	local mNow = now()
	for player, s in perPlayer do
		local L = s.launch
		if L then
			local life = character.life(player)
			if not life or not life.alive or life.lifeId ~= L.lifeId then
				AbilityService.cancelLaunch(player, "eliminated")
			elseif L.phase == "channel" then
				if (life.root.Position - L.startPos).Magnitude > LAUNCH.ChannelMaxMove then
					AbilityService.cancelLaunch(player, "moved") -- movement over 1 stud cancels (ABIL-08)
				elseif combat.activity(player).firing then
					AbilityService.cancelLaunch(player, "attacked")
				elseif mNow >= L.departAt then
					local landing
					if L.target == "Base" then
						landing = safeSpawn(life.team, nil)
					else
						local tl = L.targetPlayer and character.life(L.targetPlayer)
						if not tl or not tl.alive or not tl.root then
							AbilityService.cancelLaunch(player, "targetGone") -- before departure: no cooldown
							continue
						end
						landing = findLanding(tl.root.Position - Vector3.new(0, 3, 0), life.team)
					end
					if not landing then
						AbilityService.cancelLaunch(player, "noLanding") -- before departure: no cooldown
						continue
					end
					-- depart: frozen destination, invulnerable transit, cooldown starts now
					L.phase = "transit"
					L.landing = landing
					L.arriveAt = mNow + LAUNCH.TransitSeconds
					s.launchReady = mNow + LAUNCH.CooldownSeconds
					life.launching = true
					life.root.Anchored = true
					combat.cue(nil, { k = "LaunchMarker", o = landing, tm = life.team, dur = LAUNCH.TransitSeconds })
					sendLaunchState(player, "transit", { arriveAt = L.arriveAt })
					diagnostics.count("Launch.departed")
				end
			elseif L.phase == "transit" and mNow >= L.arriveAt then
				local landing = L.landing
				-- the frozen destination may have become invalid in transit: fall back to a friendly spawn
				local enemyBase = combat.inAnyBase(landing + Vector3.new(0, 1, 0))
				if not clearAt(landing) or (enemyBase ~= nil and enemyBase ~= life.team) then
					landing = safeSpawn(life.team, landing) or landing -- the cooldown is retained
					diagnostics.count("Launch.fallbackToSpawn")
				end
				life.root.Anchored = false
				character.teleport(player, CFrame.new(landing + Vector3.new(0, 3.1, 0)) * life.root.CFrame.Rotation)
				life.launching = false
				life.landingProtectUntil = mNow + LAUNCH.LandingProtectionSeconds
				s.launch = nil
				sendLaunchState(player, "arrived", {})
				diagnostics.count("Launch.arrived")
			end
		end
	end
end

-- Tests/dev only: clear the launch cooldown. Refused outside dev mode.
function AbilityService.devResetCooldown(player: Player): boolean
	if not DevGate.enabled() then
		return false
	end
	pstate(player).launchReady = -math.huge
	return true
end

function AbilityService.launchState(player: Player)
	local s = perPlayer[player]
	return s and s.launch
end

---------------------------------------------------------------------------------------------------------------
-- Service wiring
---------------------------------------------------------------------------------------------------------------

function AbilityService:Init(ctx)
	net = ctx.services.NetService
	diagnostics = ctx.services.DiagnosticsService
	character = ctx.services.CharacterService
	loadout = ctx.services.LoadoutService
	paint = ctx.services.PaintService
	round = ctx.services.RoundService
	combat = ctx.services.CombatService
end

function AbilityService:Start()
	net.on("Launch", GameConfig.Net.LaunchRequestsPerSecond, AbilityService.requestLaunch)
	Players.PlayerRemoving:Connect(function(p)
		perPlayer[p] = nil
		local sc = screens[p]
		if sc then
			destroyScreen(sc, "ownerLeft")
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		if paused or not round.isCombatLive() then
			return
		end
		stepThrowables(dt)
		stepStorms()
		stepLaunches()
		local mNow = now()
		for _, sc in screenById do
			if mNow >= sc.expires then
				destroyScreen(sc, "expired")
			end
		end
	end)
end

-- Tests: counts of active entities.
function AbilityService.counts()
	local n = 0
	for _ in screenById do
		n += 1
	end
	return { throwables = #throwables, storms = #storms, screens = n }
end

return AbilityService
