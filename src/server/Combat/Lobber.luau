-- Splash Pot (GDD 07.3). One volley = three visible lobes at -7/0/+7 degrees, velocity aim*80 + 30 up, gravity 98.1,
-- 52-stud trajectory limit, each painting radius 3 at its impact. All three lobes share ONE attack id, so the total
-- direct damage to a victim from a volley is capped at 55 (the first lobe to connect deals it; the others deal 0).
-- Real arcs clear low cover; tall cover blocks them. No damage cone through walls.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Ballistics = require(Shared.Combat.Ballistics)

local Lobber = { Family = "lobber" }

local D

function Lobber.init(deps)
	D = deps
end

function Lobber.handle(player: Player, payload, kit, life, s)
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
	local base = vector.create(payload.d.X, payload.d.Y, payload.d.Z)
	for _, angle in kit.LobeAnglesDegrees do
		local lobe = Ballistics.yaw(base, angle)
		local vel = Vector3.new(lobe.X, lobe.Y, lobe.Z) * kit.LobeSpeed + Vector3.new(0, kit.LobeUpSpeed, 0)
		C.spawnProjectile({
			owner = player,
			team = life.team,
			attackId = attackId,
			weapon = kit.Id,
			origin = payload.o,
			velocity = vel,
			gravity = kit.Gravity,
			range = kit.Range,
			damage = kit.VolleyDamageCap,
			paintRadius = kit.LobePaintRadius,
			radius = 0.35,
			onImpact = function(p, kind, worldHit, victim)
				if kind == "victim" then
					C.damageVictim(victim, kit.VolleyDamageCap, player, attackId, kit.Id) -- shared id: capped at 55 per volley
					C.drip(p.pos, kit.LobePaintRadius, p.team, player)
				elseif kind == "world" then
					C.paintImpact(worldHit.Position, worldHit.Normal, kit.LobePaintRadius, p.team, player)
				end
				return true
			end,
		})
	end
	D.diagnostics.count("ShotAccepted." .. kit.Id)
	C.cue(player, { k = "Volley", u = player.UserId, w = kit.Id, o = payload.o, d = payload.d, tm = life.team })
end

return Lobber
