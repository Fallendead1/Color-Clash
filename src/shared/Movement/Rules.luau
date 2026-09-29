--!strict
-- Pure movement-speed and paint-refill decisions (GDD 05.1, 05.3). The server uses these for validation and the
-- authoritative tank; the client uses the same functions for prediction.

local Rules = {}

-- Own/Neutral/Enemy: a legal paint cell. Base: own protected-base floor. Inert: walkable but not paintable (grating,
-- decor floors) — it is not neutral turf, so no refill and no glide. None: no floor found (airborne).
export type Ground = "Own" | "Neutral" | "Enemy" | "None" | "Base" | "Inert"

export type MoveState = "Standing" | "Airborne" | "Gliding" | "Climbing" | "WeaponSecondary" | "LaunchChannel" | "Launching" | "Eliminated"

export type Activity = {
	firing: boolean, -- a light weapon attack happened recently
	charging: boolean,
	rolling: boolean,
	pushing: boolean,
	glideHeld: boolean,
	weaponFireSpeed: number?,
}

-- Target horizontal speed. Enemy-floor restriction overrides every weapon bonus (GDD 05.1).
function Rules.speed(cfg: any, state: MoveState, ground: Ground, act: Activity): number
	if state == "Eliminated" or state == "LaunchChannel" or state == "Launching" then
		return 0
	end
	if state == "Climbing" then
		return cfg.ClimbSpeed
	end
	if ground == "Enemy" then
		return cfg.EnemyPaintSpeed
	end
	if act.charging then
		return cfg.ChargingSpeed
	end
	if act.rolling then
		return cfg.RollingSpeed
	end
	if act.pushing then
		return cfg.BrushPushSpeed
	end
	if act.glideHeld and not act.firing then
		if ground == "Own" or ground == "Base" then
			return cfg.GlideSpeed
		elseif ground == "Neutral" or ground == "Inert" then
			return cfg.NeutralCrouchSpeed
		end
	end
	if act.firing then
		return act.weaponFireSpeed or cfg.FiringLightSpeed
	end
	return cfg.WalkSpeed
end

-- Whether powered glide is active (own paint only) — also the condition for glide refill.
function Rules.isGliding(ground: Ground, act: Activity): boolean
	return act.glideHeld and not act.firing and (ground == "Own" or ground == "Base")
end

-- Refill rate (units/second) given the situation and seconds since the last paint-consuming action.
-- Returns rate, conditionName.
function Rules.refill(tankCfg: any, state: MoveState, ground: Ground, act: Activity, sinceLastUse: number, inOwnBase: boolean): (number, string)
	if state == "Eliminated" or state == "Launching" then
		return 0, "none"
	end
	if act.charging or act.rolling or act.pushing then
		return 0, "busy"
	end
	if inOwnBase and not act.firing then
		return tankCfg.Refill.ProtectedBase.Rate, "base"
	end
	if state == "Climbing" then
		local r = tankCfg.Refill.OwnClimb
		return if sinceLastUse >= r.Delay then r.Rate else 0, "climb"
	end
	if state == "Airborne" or ground == "None" then
		return 0, "airborne"
	end
	if ground == "Enemy" then
		return 0, "enemy"
	end
	if ground == "Inert" then
		return 0, "inert"
	end
	if ground == "Own" or ground == "Base" then
		if Rules.isGliding(ground, act) then
			local r = tankCfg.Refill.OwnGlide
			return if sinceLastUse >= r.Delay then r.Rate else 0, "glide"
		end
		local r = tankCfg.Refill.OwnStanding
		return if sinceLastUse >= r.Delay then r.Rate else 0, "own"
	end
	local r = tankCfg.Refill.NeutralStanding
	return if sinceLastUse >= r.Delay then r.Rate else 0, "neutral"
end

-- Boundary hysteresis: the reported ground only switches after the new value has persisted for `hold` seconds.
export type Hysteresis = { current: Ground, pending: Ground?, since: number }

function Rules.newHysteresis(initial: Ground): Hysteresis
	return { current = initial, pending = nil, since = 0 }
end

function Rules.updateGround(h: Hysteresis, sample: Ground, now: number, hold: number): Ground
	if sample == h.current then
		h.pending = nil
		return h.current
	end
	-- Entering enemy paint applies immediately so hysteresis can never grant free movement across enemy territory.
	if sample == "Enemy" then
		h.current = sample
		h.pending = nil
		return h.current
	end
	if h.pending ~= sample then
		h.pending = sample
		h.since = now
	elseif now - h.since >= hold then
		h.current = sample
		h.pending = nil
	end
	return h.current
end

return Rules
