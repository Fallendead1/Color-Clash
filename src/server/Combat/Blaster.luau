-- Popshot (GDD 07.3). Projectile speed 80, gravity 24, 56-stud limit; bursts on the first blocking collision or at
-- range expiry. A direct victim takes 70 total and never also takes splash; other enemies take 40 within 3 studs of
-- the burst falling linearly to 20 at 8 studs, 0 beyond; every splash target needs blast line of sight. Paint radius
-- 6 on eligible visible surfaces. Slow cadence and travel are intentional weaknesses.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Ballistics = require(Shared.Combat.Ballistics)
local GameConfig = require(Shared.Config.GameConfig)

local Blaster = { Family = "blaster" }

local D

function Blaster.init(deps)
	D = deps
end

-- Burst at `pos` (with surface `normal` when it hit geometry). `direct` is the directly hit victim record or nil.
function Blaster.burst(player: Player?, teamId: number, kit, pos: Vector3, normal: Vector3, direct, attackId: string)
	local C = D.combat
	if direct then
		C.damageVictim(direct, kit.DirectDamage, player, attackId, kit.Id)
	end
	local center = pos + normal * 0.3
	for _, v in C.victimsFor(teamId) do
		if not direct or v.key ~= direct.key then
			local dist = math.max(0, Ballistics.pointCapsuleDistance(vector.create(pos.X, pos.Y, pos.Z), vector.create(v.feet.X, v.feet.Y, v.feet.Z), GameConfig.Combat.CapsuleHeight, GameConfig.Combat.CapsuleRadius))
			local dmg = Ballistics.falloff(dist, kit.SplashInnerRadius, kit.SplashInnerDamage, kit.SplashOuterRadius, kit.SplashOuterDamage)
			if dmg > 0 and C.lineOfSight(center, C.victimCenter(v), teamId) then
				C.damageVictim(v, dmg, player, attackId, kit.Id)
			end
		end
	end
	D.paint.paintSphere(pos, kit.BurstPaintRadius, teamId, { origin = center, player = player, creditable = true })
	C.cue(nil, { k = "Burst", o = pos, r = kit.BurstPaintRadius, tm = teamId })
end

function Blaster.handle(player: Player, payload, kit, life, s)
	local C = D.combat
	if payload.a ~= "Fire" then
		if payload.a == "SecStart" or payload.a == "SecStop" then
			return
		end
		return C.reject(player, payload, "action")
	end
	if not C.gateAndSpend(player, payload, s, kit.Cadence, kit.Cost) then
		return
	end
	C.markOffense(player, s)
	local attackId = C.newAttackId(player)
	local dir = Vector3.new(payload.d.X, payload.d.Y, payload.d.Z)
	local teamId = life.team
	C.spawnProjectile({
		owner = player,
		team = teamId,
		attackId = attackId,
		weapon = kit.Id,
		origin = payload.o,
		velocity = dir * kit.ProjectileSpeed,
		gravity = kit.Gravity,
		range = kit.Range,
		radius = 0.35,
		onImpact = function(p, kind, worldHit, victim)
			if kind == "victim" then
				Blaster.burst(player, teamId, kit, p.pos, Vector3.new(0, 1, 0), victim, attackId)
			elseif kind == "world" then
				Blaster.burst(player, teamId, kit, worldHit.Position, worldHit.Normal, nil, attackId)
			end
			return true
		end,
		onExpire = function(p)
			Blaster.burst(player, teamId, kit, p.pos, Vector3.new(0, 1, 0), nil, attackId)
		end,
	})
	D.diagnostics.count("ShotAccepted." .. kit.Id)
	C.cue(player, { k = "Shot", u = player.UserId, w = kit.Id, o = payload.o, d = dir, tm = teamId })
end

return Blaster
