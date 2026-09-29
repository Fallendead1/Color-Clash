-- Shared continuous-trail logic for the Lane Roller roll and the Street Sweeper push (GDD 07.3, 10.3).
-- Samples the character's authoritative root every server step, paints a strip along the travelled path (spacing
-- tied to the footprint so low FPS leaves no gaps), drains paint by server-measured time while moving, and never
-- paints across a teleport/correction (abnormally large step -> skipped + diagnostic, SEC-09).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local Trail = {}

-- Advances one trail. Returns the horizontal distance moved this step (0 when stationary/teleported).
-- cfg: { Width, CostPerSecond, MaxSpeed }, kind: "roll" | "push"
function Trail.step(D, player: Player, s, life, cfg, dt: number, kind: string): number
	local root = life.root
	if not root then
		return 0
	end
	local pos = root.Position
	local feet = pos - Vector3.new(0, life.humanoid.HipHeight + root.Size.Y / 2, 0)
	local last = s.trailLast
	s.trailLast = feet
	if not last then
		return 0
	end
	local flat = Vector3.new(feet.X - last.X, 0, feet.Z - last.Z)
	local dist = flat.Magnitude
	local maxStep = GameConfig.Paint.MaxTrailStepPerSecond * math.max(dt, 1 / 60) * 1.5 + 0.5
	if dist > maxStep then
		D.diagnostics.event("TrailTeleportSkipped", { player = player.UserId, kind = kind, dist = math.floor(dist) })
		return 0
	end
	local teamId = life.team
	if dist < 0.05 then
		-- stationary: paint only the contact area once, no drain (GDD 07.3)
		if not s.stationaryPainted then
			s.stationaryPainted = true
			local look = root.CFrame.LookVector
			local fwd = Vector3.new(look.X, 0, look.Z)
			if fwd.Magnitude > 1e-3 then
				D.paint.paintRect(feet + fwd.Unit * 1.5, fwd, 2, cfg.Width, teamId, { origin = feet + Vector3.new(0, 2, 0), player = player, creditable = true })
			end
		end
		return 0
	end
	s.stationaryPainted = false
	-- drain by server time while moving; an empty tank ends the action cleanly (never negative)
	local want = cfg.CostPerSecond * dt
	local got = D.loadout.drain(player, want, D.round.matchNow())
	if got + 1e-6 < want then
		D.combat.stopContinuous(player, kind)
		return 0
	end
	local fwd = flat.Unit
	local mid = (last + feet) / 2 + fwd * 1.0
	D.paint.paintRect(mid, fwd, dist + 2.0, cfg.Width, teamId, { origin = mid + Vector3.new(0, 2, 0), player = player, creditable = true })
	return dist
end

return Trail
