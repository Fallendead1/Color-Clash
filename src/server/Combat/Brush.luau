-- Street Sweeper (GDD 07.3). Primary sweep: 0.05 s windup inside a 0.22 s cycle; occlusion-checked forward arc,
-- reach 12; 32 damage, one event per victim per sweep; paints a 10 x 5 forward footprint. Secondary push (held): a
-- 3-wide trail at up to 22 studs/s, 10 paint/s while moving, no contact damage. Primary and push are mutually
-- exclusive; a sweep ends the push and transitions never grant extra attacks (the cadence gate is shared).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Ballistics = require(Shared.Combat.Ballistics)

local Trail = require(script.Parent.Trail)

local Brush = { Family = "brush" }

local D

function Brush.init(deps)
	D = deps
end

local function sweep(player: Player, payload, kit, life, s)
	local C = D.combat
	s.pushing = false
	s.trailLast = nil
	if not C.gateAndSpend(player, payload, s, kit.Cadence, kit.Cost) then
		return
	end
	C.markOffense(player, s)
	local f = Vector3.new(payload.d.X, 0, payload.d.Z)
	if f.Magnitude < 1e-3 then
		return
	end
	local fwd = f.Unit
	local attackId = C.newAttackId(player)
	local lifeId = life.lifeId
	local matchId = D.round.matchId()
	D.diagnostics.count("ShotAccepted." .. kit.Id)
	C.cue(player, { k = "Sweep", u = player.UserId, d = fwd, tm = life.team })
	task.delay(kit.Windup, function()
		local l = D.character.life(player)
		if not l or l.lifeId ~= lifeId or not l.alive or D.round.matchId() ~= matchId or not D.round.isCombatLive() then
			return
		end
		local origin = l.root.Position
		local eye = origin + Vector3.new(0, 1.2, 0)
		for _, v in C.victimsFor(l.team) do
			local center = C.victimCenter(v)
			if Ballistics.inFan(vector.create(origin.X, origin.Y, origin.Z), vector.create(fwd.X, fwd.Y, fwd.Z), vector.create(center.X, center.Y, center.Z), kit.Range, kit.ArcDegrees) and math.abs(center.Y - origin.Y) < 5 then
				if C.lineOfSight(eye, center, l.team) then
					C.damageVictim(v, kit.Damage, player, attackId, kit.Id)
				end
			end
		end
		local feet = origin - Vector3.new(0, l.humanoid.HipHeight + l.root.Size.Y / 2, 0)
		D.paint.paintRect(feet + fwd * (kit.SweepPaintLength / 2), fwd, kit.SweepPaintLength, kit.SweepPaintWidth, l.team, {
			origin = eye,
			player = player,
			creditable = true,
		})
	end)
end

function Brush.handle(player: Player, payload, kit, life, s)
	local a = payload.a
	if a == "Fire" then
		return sweep(player, payload, kit, life, s)
	elseif a == "SecStart" then
		if D.loadout.paint(player) <= 0 then
			return D.combat.reject(player, payload, "dry")
		end
		s.pushing = true
		s.trailLast = nil
		s.stationaryPainted = false
		return
	elseif a == "SecStop" then
		s.pushing = false
		s.trailLast = nil
		return
	end
	return D.combat.reject(player, payload, "action")
end

function Brush.tick(dt: number, players)
	for player, s in players do
		if s.pushing then
			local life = D.character.life(player)
			if not life or not life.alive or life.lifeId ~= s.life or life.climbing then
				s.pushing = false
				s.trailLast = nil
			elseif D.loadout.kit(player).Family == "brush" then
				Trail.step(D, player, s, life, D.loadout.kit(player).Push, dt, "push")
			end
		end
	end
end

return Brush
