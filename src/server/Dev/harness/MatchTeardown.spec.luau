-- Harness step: end the dev match and clear overrides. Request with CCTestRequest = "harness:MatchTeardown".
return function(t)
	local it, expect = t.it, t.expect
	local S = t.services
	local H = require(S.Dev.MatchHarness)
	it("ends the match", function()
		H.stop(S)
		workspace:SetAttribute("CCHarnessLayout", nil)
		expect(S.RoundService.state()):toBe("Waiting")
	end)
end
