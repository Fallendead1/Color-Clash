-- Projectile family: Sprayline and Twin Jets (GDD 07.3). One paid shot = one projectile = at most one damage event.
-- Twin Jets alternate muzzles on the client; each shot's muzzle passes the same plausibility check. Secondary Dash
-- (Twin Jets): 7 studs in 0.18 s, 2.5 s cooldown, 8 paint, not while climbing/gliding/launching, no invulnerability.
-- The dash is performed by the client's physics (it collides with walls); the server validates, charges, and grants
-- a one-window movement allowance so its displacement check accepts it.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Ballistics = require(Shared.Combat.Ballistics)

local Projectile = { Family = "projectile" }

local D

function Projectile.init(deps)
	D = deps
end

local function fire(player: Player, payload, kit, life, s)
	local C = D.combat
	if s.rolling or s.pushing or s.charging then
		return C.reject(player, payload, "busy")
	end
	if not C.gateAndSpend(player, payload, s, kit.Cadence, kit.Cost) then
		return
	end
	C.markOffense(player, s)
	local dir = Ballistics.spread(vector.create(payload.d.X, payload.d.Y, payload.d.Z), kit.SpreadDegrees or 0, life.lifeId, payload.s)
	local d3 = Vector3.new(dir.X, dir.Y, dir.Z)
	C.spawnProjectile({
		owner = player,
		team = life.team,
		attackId = C.newAttackId(player),
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
	D.diagnostics.count("ShotAccepted." .. kit.Id)
	C.cue(player, { k = "Shot", u = player.UserId, w = kit.Id, o = payload.o, d = d3, tm = life.team })
end

local function dash(player: Player, payload, kit, life, s)
	local C = D.combat
	local cfg = kit.Dash
	if not cfg then
		return C.reject(player, payload, "family")
	end
	if life.climbing or life.glideHeld then
		return C.reject(player, payload, "dashState") -- cannot chain from climb or glide (GDD 07.3)
	end
	if math.abs(payload.d.Y) > 0.2 then
		return C.reject(player, payload, "dashDirection")
	end
	local now = os.clock()
	if now < s.dashReady then
		return C.reject(player, payload, "cooldown")
	end
	if not D.loadout.trySpend(player, cfg.Cost, D.round.matchNow()) then
		return C.reject(player, payload, "dry")
	end
	s.dashReady = now + cfg.Cooldown
	D.character.allowBurst(player, cfg.Distance + 2)
	D.diagnostics.count("Dash.accepted")
	C.cue(player, { k = "Dash", u = player.UserId, d = payload.d })
end

function Projectile.handle(player: Player, payload, kit, life, s)
	local a = payload.a
	if a == "Fire" then
		return fire(player, payload, kit, life, s)
	elseif a == "Dash" or (a == "SecStart" and kit.Dash) then
		return dash(player, payload, kit, life, s)
	elseif a == "SecStop" then
		return
	end
	return D.combat.reject(player, payload, "action")
end

return Projectile
