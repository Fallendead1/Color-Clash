-- Harness step: publish server-side network/security counters as JSON in Workspace attribute CCNetAudit
-- (handler errors, rate-limit drops, accepted/rejected attacks, hits, hash agreement, frame time, send rate).
-- Request with CCTestRequest = "harness:NetAudit".
return function(t)
	local it = t.it
	local S = t.services
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	it("publishes the audit", function()
		local D = S.DiagnosticsService
		local out = { handlerErrors = 0, rateLimited = {}, accepted = 0, rejected = {}, dropped = D.getCount("NetSim.dropped") }
		for name, n in D.counters() do
			if string.find(name, "^RemoteHandlerError") then
				out.handlerErrors += n
			end
			local r = string.match(name, "^RemoteRateLimited%.(.+)$")
			if r then
				out.rateLimited[r] = n
			end
			if string.find(name, "^ShotAccepted%.") then
				out.accepted += n
			end
			local j = string.match(name, "^ShotRejected%.(.+)$")
			if j then
				out.rejected[j] = n
			end
		end
		out.hits = D.getCount("Hit.applied")
		out.hashMismatch = D.getCount("event.PaintHashMismatch")
		local p = Players:GetPlayers()[1]
		local grid = S.PaintService.grid()
		out.serverHash = if grid then grid:hash() else nil -- compare with the client's CCClientHash after idle
		local f = D.percentiles("server.frameMs")
		out.frameMs = f and { p50 = math.floor(f.p50 * 10) / 10, p95 = math.floor(f.p95 * 10) / 10, max = math.floor(f.max * 10) / 10 } or nil
		out.sendKbps = math.floor(game:GetService("Stats").DataSendKbps * 10) / 10
		out.rtt = p and p:GetAttribute("CCRtt")
		workspace:SetAttribute("CCNetAudit", HttpService:JSONEncode(out))
	end)
end
