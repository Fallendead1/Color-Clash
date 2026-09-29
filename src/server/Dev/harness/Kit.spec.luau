-- Harness step: switch the (single) test player's locked kit to Workspace attribute CCKit and refill.
-- Request with CCTestRequest = "harness:Kit".
return function(t)
	local it, expect = t.it, t.expect
	local S = t.services
	local Players = game:GetService("Players")
	it("switches kit", function()
		local p = Players:GetPlayers()[1]
		expect(S.LoadoutService.devSetKit(p, workspace:GetAttribute("CCKit"))):toBe(true)
		S.LoadoutService.fillTank(p)
		local s = S.CombatService.state(p)
		s.nextReady, s.charging, s.rolling, s.pushing = 0, false, false, false
	end)
end
