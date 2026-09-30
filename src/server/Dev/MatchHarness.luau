-- DEV ONLY: helpers for engine tests that need a live match on the paint_lab fixture with the single Studio client
-- ("solo practice (dev override)" — never reported as a 4v4 or multi-client result).

local Players = game:GetService("Players")

local MatchHarness = {}

function MatchHarness.waitFor(pred: () -> boolean, timeout: number): boolean
	local t0 = os.clock()
	while not pred() do
		if os.clock() - t0 > timeout then
			return false
		end
		task.wait(0.05)
	end
	return true
end

-- Starts (or reuses) a live solo match. Returns the player, their team and the map descriptor.
function MatchHarness.startSolo(S, liveSeconds: number?)
	-- These specs target paint_lab by definition, even when production maps are installed.
	S.DevGate.set("UseFixture", true)
	local p = Players:GetPlayers()[1]
	assert(p, "no player")
	if S.RoundService.state() == "Live" and S.TeamService.isParticipating(p) then
		return p, S.TeamService.teamOf(p), S.RoundService.currentMap()
	end
	S.DevGate.set("MinimumReady", 1)
	S.DevGate.set("AllowEmptyTeam", true)
	S.DevGate.set("CountdownSeconds", 1)
	S.DevGate.set("IntroSeconds", 1)
	S.DevGate.set("LiveSeconds", liveSeconds or 900)
	S.DevGate.set("ResultsSeconds", 2)
	S.DevGate.set("IntermissionSeconds", 1)
	S.RoundService.applyDevSettings()
	S.TeamService.setReadyServer(p, true)
	assert(MatchHarness.waitFor(function()
		return S.RoundService.state() == "Live" and S.TeamService.isParticipating(p)
	end, 20), "match did not go live")
	assert(MatchHarness.waitFor(function()
		return S.CharacterService.isAlive(p) and S.PaintService.isSynced(p)
	end, 10), "player not alive/synced")
	return p, S.TeamService.teamOf(p), S.RoundService.currentMap()
end

-- Ends a dev match quickly (deadline brought forward) and waits for Waiting, then clears overrides.
function MatchHarness.stop(S)
	local p = Players:GetPlayers()[1]
	if p then
		S.TeamService.setReadyServer(p, false)
	end
	S.RoundService.devEndLiveNow()
	MatchHarness.waitFor(function()
		local s = S.RoundService.state()
		return s == "Waiting" or s == "Intermission"
	end, 15)
	S.DevGate.clear()
	S.RoundService.applyDevSettings()
	MatchHarness.waitFor(function()
		return S.RoundService.state() == "Waiting"
	end, 5)
end

-- Moves the player's character (server-driven teleport) standing at `pos` facing `look`.
function MatchHarness.place(S, p: Player, pos: Vector3, look: Vector3?)
	local l = S.CharacterService.life(p)
	assert(l and l.character, "no character")
	local lookAt = pos + (look or Vector3.new(1, 0, 0))
	S.CharacterService.teleport(p, CFrame.lookAt(pos + Vector3.new(0, 3, 0), lookAt + Vector3.new(0, 3, 0)))
	l.root.AssemblyLinearVelocity = Vector3.zero
end

-- Paints an axis-aligned floor rectangle (x0..x1, z0..z1) at floor height y for `team` (0 = neutral).
function MatchHarness.paintFloor(S, x0: number, x1: number, z0: number, z1: number, team: number, y: number?)
	local grid = S.PaintService.grid()
	local Surface = require(game.ReplicatedStorage.Shared.Paint.Surface)
	local changed = 0
	for x = x0 + 0.5, x1 - 0.5, 1 do
		for z = z0 + 0.5, z1 - 0.5, 1 do
			local patch, i, j = grid:locate(vector.create(x, y or 100, z), 0.6, 0.3)
			if patch then
				if grid:setCell(patch, i, j, team) ~= nil then
					changed += 1
				end
			end
		end
	end
	S.PaintService.flush()
	local _ = Surface
	return changed
end

-- Paints every cell of a surface for `team`.
function MatchHarness.paintSurface(S, surfaceId: string, team: number)
	local grid = S.PaintService.grid()
	local patch = grid:getPatch(surfaceId)
	for j = 0, patch.def.SizeV - 1 do
		for i = 0, patch.def.SizeU - 1 do
			grid:setCell(patch, i, j, team)
		end
	end
	S.PaintService.flush()
end

return MatchHarness
