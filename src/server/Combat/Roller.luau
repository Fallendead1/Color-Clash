-- Lane Roller (GDD 07.3). Primary flick: 0.18 s windup inside a 0.80 s cycle; 70° forward fan; 65 within 10 studs,
-- 40 out to 22; one hit per victim; paints a clipped 14 x 8 forward footprint. Secondary roll (held): an 8-wide strip
-- at up to 12 studs/s, 12 paint/s while moving; contact 60 damage at most once per victim per 0.65 s, swept body test
-- with line of sight, only while actually moving (a planted roller is not a damage wall). Primary exits rolling;
-- rolling resumes only with a fresh Secondary hold after the attack lock.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Ballistics = require(Shared.Combat.Ballistics)

local Trail = require(script.Parent.Trail)

local Roller = { Family = "roller" }

local D

function Roller.init(deps)
	D = deps
end

local function flatForward(v: Vector3): Vector3?
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 then
		return nil
	end
	return f.Unit
end

local function flick(player: Player, payload, kit, life, s)
	local C = D.combat
	s.rolling = false -- Primary exits rolling
	s.trailLast = nil
	if not C.gateAndSpend(player, payload, s, kit.Cadence, kit.Cost) then
		return
	end
	C.markOffense(player, s)
	local fwd = flatForward(payload.d)
	if not fwd then
		return
	end
	local attackId = C.newAttackId(player)
	local lifeId = life.lifeId
	local matchId = D.round.matchId()
	D.diagnostics.count("ShotAccepted." .. kit.Id)
	C.cue(player, { k = "Flick", u = player.UserId, d = fwd, tm = life.team })
	task.delay(kit.Windup, function()
		-- delayed callbacks verify match and life ids before acting (GDD 03.6)
		local l = D.character.life(player)
		if not l or l.lifeId ~= lifeId or not l.alive or D.round.matchId() ~= matchId or not D.round.isCombatLive() then
			return
		end
		local root = l.root
		local origin = root.Position
		local eye = origin + Vector3.new(0, 1.2, 0)
		for _, v in C.victimsFor(l.team) do
			local center = C.victimCenter(v)
			if Ballistics.inFan(vector.create(origin.X, origin.Y, origin.Z), vector.create(fwd.X, fwd.Y, fwd.Z), vector.create(center.X, center.Y, center.Z), kit.Range, kit.FanDegrees) and math.abs(center.Y - origin.Y) < 6 then
				if C.lineOfSight(eye, center, l.team) then
					local dist = (Vector3.new(center.X, 0, center.Z) - Vector3.new(origin.X, 0, origin.Z)).Magnitude
					C.damageVictim(v, if dist <= kit.CloseRange then kit.CloseDamage else kit.FarDamage, player, attackId, kit.Id)
				end
			end
		end
		local feet = origin - Vector3.new(0, l.humanoid.HipHeight + root.Size.Y / 2, 0)
		D.paint.paintRect(feet + fwd * (kit.FlickPaintLength / 2), fwd, kit.FlickPaintLength, kit.FlickPaintWidth, l.team, {
			origin = eye,
			player = player,
			creditable = true,
		})
	end)
end

function Roller.handle(player: Player, payload, kit, life, s)
	local a = payload.a
	if a == "Fire" then
		return flick(player, payload, kit, life, s)
	elseif a == "SecStart" then
		if os.clock() + 0.06 < s.nextReady then
			return D.combat.reject(player, payload, "attackLock") -- rolling resumes only after the flick cycle
		end
		if D.loadout.paint(player) <= 0 then
			return D.combat.reject(player, payload, "dry")
		end
		s.rolling = true
		s.trailLast = nil
		s.stationaryPainted = false
		table.clear(s.trailHits)
		return
	elseif a == "SecStop" then
		s.rolling = false
		s.trailLast = nil
		return
	end
	return D.combat.reject(player, payload, "action")
end

-- Continuous roll: strip paint + contact damage (called every server step while the round is live).
function Roller.tick(dt: number, players)
	local C = D.combat
	for player, s in players do
		if s.rolling then
			local life = D.character.life(player)
			if not life or not life.alive or life.lifeId ~= s.life or life.climbing then
				s.rolling = false
				s.trailLast = nil
			elseif D.loadout.kit(player).Family == "roller" then
				local kit = D.loadout.kit(player)
				local last = s.trailLast
				local moved = Trail.step(D, player, s, life, kit.Roll, dt, "roll")
				if moved > 0 and last then
					local root = life.root
					local feet = s.trailLast
					local fwd = Vector3.new(feet.X - last.X, 0, feet.Z - last.Z).Unit
					local side = Vector3.new(-fwd.Z, 0, fwd.X)
					local now = os.clock()
					for _, v in C.victimsFor(life.team) do
						local rel = v.feet - feet
						local along = rel:Dot(fwd)
						-- swept body test: the victim's capsule overlaps the roller band swept this step
						if along > -(moved + 1.4) and along < 2.5 + 1.4 and math.abs(rel:Dot(side)) < kit.Roll.Width / 2 + 1.4 and math.abs(rel.Y) < 3 then
							local lastHit = s.trailHits[v.key]
							if (lastHit == nil or now - lastHit >= kit.Roll.PerTargetCooldown) and C.lineOfSight(root.Position, C.victimCenter(v), life.team) then
								s.trailHits[v.key] = now
								C.damageVictim(v, kit.Roll.ContactDamage, player, C.newAttackId(player), kit.Id)
								C.markOffense(player, s)
							end
						end
					end
				end
			end
		end
	end
end

return Roller
