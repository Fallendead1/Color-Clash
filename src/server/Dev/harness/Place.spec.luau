-- Harness step: legitimately place the player's character (server teleport) at Workspace attribute CCPlaceTarget
-- "x,y,z,lx,lz" (position and horizontal look direction). Request with CCTestRequest = "harness:Place".
-- Also supports CCPlaceAction = "eliminate" to eliminate the player environmentally (MOVE-07 driver).
return function(t)
	local it, expect = t.it, t.expect
	local S = t.services
	local H = require(S.Dev.MatchHarness)
	local Players = game:GetService("Players")

	it("places or eliminates the player", function()
		local p = Players:GetPlayers()[1]
		local action = workspace:GetAttribute("CCPlaceAction")
		workspace:SetAttribute("CCPlaceAction", nil)
		if action == "eliminate" then
			S.CharacterService.eliminate(p, nil, nil)
			expect(S.CharacterService.isAlive(p)):toBe(false)
			return
		end
		local spec = workspace:GetAttribute("CCPlaceTarget")
		local x, y, z, lx, lz = string.match(spec, "([%-%d%.]+),([%-%d%.]+),([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)")
		H.place(S, p, Vector3.new(tonumber(x), tonumber(y), tonumber(z)), Vector3.new(tonumber(lx), 0, tonumber(lz)))
		expect(S.CharacterService.isAlive(p)):toBe(true)
	end)
end
