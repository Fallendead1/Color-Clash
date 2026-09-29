-- Harness step (not a test of its own): start a long live solo-practice match on the fixture and prepare paint
-- areas for the client Phase 03 specs. Request with CCTestRequest = "harness:MatchSetup".
-- Published layout (Workspace attribute CCHarnessLayout, JSON): team, own/neutral/enemy strip centres.
return function(t)
	local it, expect = t.it, t.expect
	local S = t.services
	local H = require(S.Dev.MatchHarness)
	local HttpService = game:GetService("HttpService")

	it("starts the match and paints the test areas", function()
		local p, team = H.startSolo(S, 1800)
		S.CharacterService.onOffensiveAction(p)
		-- floor strips at z -30..-22: own x -30..-4, neutral x -4..4, enemy x 4..12
		H.paintFloor(S, -30, -4, -30, -22, team)
		H.paintFloor(S, -4, 4, -30, -22, 0)
		H.paintFloor(S, 4, 12, -30, -22, 3 - team)
		-- climbable walls: south face of the platform own (mantle target), west face own (blocked ledge)
		H.paintSurface(S, "platform_climb_south", team)
		H.paintSurface(S, "platform_climb_west", team)
		-- the north face of the free-standing paint wall: lower half own, upper half enemy (loss of paint)
		local grid = S.PaintService.grid()
		local patch = grid:getPatch("paint_wall_north")
		for j = 0, patch.def.SizeV - 1 do
			for i = 0, patch.def.SizeU - 1 do
				grid:setCell(patch, i, j, if j < 4 then team else 3 - team)
			end
		end
		-- the area in front of the paint wall own so gliding into it is possible
		H.paintFloor(S, -8, 8, -19, -12, team)
		H.paintFloor(S, -8, 8, 6, 14, team)
		S.PaintService.flush()
		workspace:SetAttribute("CCHarnessLayout", HttpService:JSONEncode({ team = team }))
		expect(S.RoundService.state()):toBe("Live")
	end)
end
