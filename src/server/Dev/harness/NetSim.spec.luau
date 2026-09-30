-- Harness step: set the dev network simulation from Workspace attribute CCNetSim = "latencyMs,jitterMs,lossPct"
-- (one-way latency; "" or "0,0,0" turns it off). Request with CCTestRequest = "harness:NetSim".
return function(t)
	local it, expect = t.it, t.expect
	local S = t.services
	it("sets the network simulation", function()
		local spec = workspace:GetAttribute("CCNetSim") or ""
		local lat, jit, loss = string.match(spec, "^(%d+),(%d+),(%d+)$")
		S.DevGate.set("NetLatencyMs", tonumber(lat) or 0)
		S.DevGate.set("NetJitterMs", tonumber(jit) or 0)
		S.DevGate.set("NetLossPct", tonumber(loss) or 0)
		expect(S.DevGate.get("NetLatencyMs", 0)):toBe(tonumber(lat) or 0)
	end)
end
