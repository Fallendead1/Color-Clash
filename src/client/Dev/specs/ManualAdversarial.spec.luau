-- SEC-05/06/08 through the REAL remotes from a real client: malformed payloads for every client->server remote, then
-- request floods. The server must stay healthy (harness:NetAudit afterwards: 0 handler errors, rate-limit counts).
-- Publishes the client's own view (sends that the engine refused to serialize) in CCAdversarialDiag.
return function(t)
	local it, expect = t.it, t.expect
	local player = game.Players.LocalPlayer
	local HttpService = game:GetService("HttpService")

	it("sends garbage and floods", function()
		local Net = require(game.ReplicatedStorage.Shared.Protocol.Net)
		local remotes = Net.getClientRemotes(5)
		local wide = {}
		for k = 1, 300 do
			wide["k" .. k] = k
		end
		local deep = {}
		local cur = deep
		for _ = 1, 30 do
			cur.n = {}
			cur = cur.n
		end
		local garbage = {
			false,
			0 / 0,
			math.huge,
			-1e308,
			string.rep("x", 20000),
			wide,
			deep,
			Vector3.new(0 / 0, 1, 1),
			workspace,
			{ m = 0 / 0, l = "x", s = -1, a = "Fire", t = math.huge, o = Vector3.new(1e9, 0, 0), d = Vector3.new(0, 0, 0) },
			{ target = CFrame.new(1, 2, 3) },
			{ target = "Base", cf = CFrame.new() },
			{ cash = 1e9, ultimate = 100, loadout = "golden_gun" },
			{ k = "Milestone", name = string.rep("y", 5000) },
			{ ready = "yes" },
			"golden_gun",
		}
		local serializeErrors = 0
		local sent = 0
		for name, kind in Net.Remotes do
			local r = remotes[name]
			if (r:IsA("RemoteEvent") or r:IsA("UnreliableRemoteEvent")) and name ~= "ActionResult" then
				for k = 0, #garbage do
					local ok = pcall(function()
						r:FireServer(garbage[k]) -- k = 0 sends nil
					end)
					if ok then
						sent += 1
					else
						serializeErrors += 1
					end
				end
			end
			local _ = kind
		end
		task.wait(1)
		-- floods (well-formed and not): fire, ready, equip, resync, launch, settings, client events
		for k = 1, 300 do
			remotes.Action:FireServer({ m = player:GetAttribute("CCMatchId") or 0, l = player:GetAttribute("CCLifeId") or 0, s = 5000000 + k, a = "Fire", t = workspace:GetServerTimeNow(), o = Vector3.zero, d = Vector3.new(1, 0, 0) })
		end
		for k = 1, 100 do
			remotes.Ready:FireServer({ ready = k % 2 == 0 })
			remotes.SelectLoadout:FireServer("sprayline")
			remotes.PaintResync:FireServer({ m = 1, v = 1 })
			remotes.Launch:FireServer({ target = "Base" })
			remotes.SettingsPatch:FireServer({ sensitivity = 1 })
			remotes.ClientEvent:FireServer({ k = "Active" })
		end
		task.wait(2)
		remotes.Ready:FireServer({ ready = false })
		player:SetAttribute("CCAdversarialDiag", HttpService:JSONEncode({ sent = sent, refusedByEngine = serializeErrors }))
		expect(sent > 0):toBe(true)
	end)
end
