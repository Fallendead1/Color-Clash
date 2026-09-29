-- Harness step: live solo match with practice target 1 at (10,100,-4) damageable by anyone, player tank full.
-- Request with CCTestRequest = "harness:CombatSetup". Then place the player with harness:Place.
return function(t)
	local it, expect = t.it, t.expect
	local S = t.services
	local H = require(S.Dev.MatchHarness)
	it("prepares combat", function()
		local p = H.startSolo(S, 1800)
		S.CharacterService.onOffensiveAction(p)
		S.LoadoutService.fillTank(p)
		local tg = S.CombatService.targets()[1]
		tg.feet = Vector3.new(10, 100, -4)
		tg.part.CFrame = CFrame.new(10, 102.75, -4) * CFrame.Angles(0, 0, math.rad(90))
		tg.health = 100
		tg.alive = true
		tg.part:SetAttribute("Health", 100)
		S.CombatService.setTargetTeam(1, "Any")
		expect(S.RoundService.state()):toBe("Live")
	end)
end
