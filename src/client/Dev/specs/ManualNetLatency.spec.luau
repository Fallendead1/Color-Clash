-- NET-05/06/08 (real client, real remotes, dev network simulation set by harness:NetSim). Kit sprayline, placed at
-- "0,100,-4,1,0" facing practice target 1 at (10,100,-4). Sends 15 legal shots 0.3 s apart through the real Action
-- remote, forces one paint resync mid-burst (NET-08), waits for quiet, and publishes: sent / rejected (by reason) /
-- hits seen / measured app RTT / client paint hash (compare with the server hash in harness:NetAudit).
return function(t)
	local it, expect = t.it, t.expect
	local C = t.services
	local player = game.Players.LocalPlayer
	local HttpService = game:GetService("HttpService")

	it("fires through the simulated network and converges", function()
		local remotes = require(game.ReplicatedStorage.Shared.Protocol.Net).getClientRemotes(5)
		local rejects, hits = {}, 0
		local c1 = remotes.ActionResult.OnClientEvent:Connect(function(msg)
			if type(msg) == "table" and msg.k == "Action" and msg.ok == false then
				rejects[msg.reason or "?"] = (rejects[msg.reason or "?"] or 0) + 1
			end
		end)
		local c2 = remotes.DamageResult.OnClientEvent:Connect(function(msg)
			if type(msg) == "table" and msg.k == "Hit" and msg.ok then
				hits += 1
			end
		end)
		local root = player.Character.HumanoidRootPart
		local target = Vector3.new(10, 102.75, -4)
		for k = 1, 15 do
			local o = root.Position + Vector3.new(0, 1.1, 0)
			C.WeaponController.sendForTests("Fire", o, (target - o).Unit)
			if k == 8 then
				-- NET-08: a resync request while shots are in flight
				remotes.PaintResync:FireServer({ m = player:GetAttribute("CCMatchId"), v = C.PaintClient.mapVersion() })
			end
			task.wait(0.3)
		end
		task.wait(3.5) -- quiet period: deltas and the resync settle, pings refresh
		c1:Disconnect()
		c2:Disconnect()
		local rejectCount = 0
		for _, n in rejects do
			rejectCount += n
		end
		local grid = C.PaintClient.grid()
		player:SetAttribute("CCClientHash", grid and grid:hash() or -1)
		player:SetAttribute("CCNetDiag", HttpService:JSONEncode({ sent = 15, rejects = rejects, hits = hits, rtt = player:GetAttribute("CCRtt") }))
		expect(rejectCount):toBe(0) -- hits depend on the random team (practice targets are team B); reported only
	end)
end
