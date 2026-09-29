-- Linecaster (GDD 07.3, 06.2). The server measures charge time itself (ChargeStart receipt -> ChargeRelease receipt);
-- a client cannot forge a duration. Start needs >= 20 paint. Release before 0.15 s cancels with no cost; otherwise
-- 20 paint and damage 35 + 75 * factor over 0.15..1.10 s. 0.35 s recovery between shots. Glide, climb, elimination and
-- panel entry cancel (no stored charge). Hitscan 120 studs; current static walls always block; victim hitboxes may
-- be rewound by at most 150 ms (bounded by measured latency). Paints a 2-wide trace on visible floor within 6 studs
-- below the valid beam. Held aim updates relay a line-of-sight-clipped warning to other clients.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Ballistics = require(Shared.Combat.Ballistics)
local GameConfig = require(Shared.Config.GameConfig)
local Validate = require(Shared.Protocol.Validate)

local Charger = { Family = "charger" }

local D
local lastAimRelay: { [Player]: number } = {}

function Charger.init(deps)
	D = deps
end

-- Latency-bounded rewind (never more than 150 ms; never an arbitrary client timestamp).
local function rewindFor(player: Player): number
	local ok, ping = pcall(function()
		return player:GetNetworkPing()
	end)
	local oneWay = if ok and type(ping) == "number" then ping / 2 else 0
	return math.clamp(oneWay, 0, GameConfig.Combat.MaxRewindSeconds)
end
Charger.rewindFor = rewindFor

local function release(player: Player, payload, kit, life, s)
	local C = D.combat
	if not s.charging then
		return C.reject(player, payload, "notCharging")
	end
	local held = os.clock() - s.chargeStart
	s.charging = false
	C.cue(player, { k = "ChargeEnd", u = player.UserId })
	local damage, factor = Ballistics.chargeDamage(held, kit.MinCharge, kit.FullCharge, kit.BaseDamage, kit.ChargeDamage)
	if not damage then
		D.diagnostics.count("Charge.earlyRelease") -- cancels without firing or cost
		return
	end
	if not C.gateAndSpend(player, payload, s, kit.Recovery, kit.Cost) then
		return
	end
	C.markOffense(player, s)
	local origin = payload.o
	local dir = Vector3.new(payload.d.X, payload.d.Y, payload.d.Z)
	local range = kit.Range
	local endPoint = origin + dir * range
	-- static walls (and enemy screens) with the CURRENT world; base boundaries also stop the beam
	local worldHit = Workspace:Raycast(origin, dir * range, C.worldParamsFor(life.team))
	local tWorld = if worldHit then (worldHit.Position - origin).Magnitude / range else 1
	local tBase = C.baseCrossing(origin, endPoint)
	local tEnd = math.min(tWorld, tBase or 1)
	local rewind = rewindFor(player)
	local best, tBest = nil, nil
	for _, v in C.victimsFor(life.team, rewind) do
		local tv = Ballistics.sweepCapsule(vector.create(origin.X, origin.Y, origin.Z), vector.create(endPoint.X, endPoint.Y, endPoint.Z), 0.1, vector.create(v.feet.X, v.feet.Y, v.feet.Z), GameConfig.Combat.CapsuleHeight, GameConfig.Combat.CapsuleRadius)
		if tv and tv <= tEnd and (tBest == nil or tv < tBest) then
			best, tBest = v, tv
		end
	end
	local attackId = C.newAttackId(player)
	if best and D.round.acceptsImpactAt(Workspace:GetServerTimeNow()) then
		C.damageVictim(best, damage, player, attackId, kit.Id)
		tEnd = tBest
	end
	-- 2-wide ground trace below the valid beam segment (independently visible floor within 6 studs)
	local beamLen = range * tEnd
	local step = 1.0
	local k = step
	while k <= beamLen do
		C.drip(origin + dir * k, kit.TracePaintWidth / 2, life.team, player)
		k += step
	end
	D.diagnostics.count("ShotAccepted." .. kit.Id)
	D.diagnostics.event("ChargeFired", { player = player.UserId, held = math.floor(held * 100) / 100, factor = math.floor(factor * 100) / 100, damage = math.floor(damage), rewind = math.floor(rewind * 1000) })
	C.cue(player, { k = "Beam", u = player.UserId, o = origin, e = origin + dir * beamLen, tm = life.team })
end

function Charger.handle(player: Player, payload, kit, life, s)
	local C = D.combat
	local a = payload.a
	if a == "ChargeStart" or a == "Fire" then
		if s.charging then
			return
		end
		if life.glideHeld then
			return C.reject(player, payload, "gliding")
		end
		if D.loadout.paint(player) + 1e-6 < kit.Cost then
			return C.reject(player, payload, "dry") -- a charge begins only with at least 20 paint
		end
		s.charging = true
		s.chargeStart = os.clock()
		C.cue(player, { k = "ChargeStart", u = player.UserId, o = payload.o, d = payload.d, tm = life.team })
		return
	elseif a == "ChargeRelease" then
		return release(player, payload, kit, life, s)
	elseif a == "ChargeCancel" then
		if s.charging then
			s.charging = false
			D.diagnostics.count("Charge.cancelled")
			C.cue(player, { k = "ChargeEnd", u = player.UserId })
		end
		return
	elseif a == "SecStart" or a == "SecStop" then
		return -- focus view is presentation only
	end
	return C.reject(player, payload, "action")
end

-- Held aim updates (unreliable, rate-limited) relay the aim warning to others while charging.
function Charger.onHeldAim(player: Player, payload)
	local s = D.combat.state(player)
	if not s.charging or type(payload) ~= "table" or not Validate.unitVector(payload.d) or not Validate.vector(payload.o, 100000) then
		return
	end
	local now = os.clock()
	if lastAimRelay[player] and now - lastAimRelay[player] < 1 / 15 then
		return
	end
	lastAimRelay[player] = now
	local life = D.character.life(player)
	if not life or not life.root or (payload.o - life.root.Position).Magnitude > GameConfig.Combat.MuzzleTolerance + 2 then
		return
	end
	D.combat.cue(player, { k = "Aim", u = player.UserId, o = payload.o, d = payload.d, tm = life.team })
end

local _ = Players
return Charger
