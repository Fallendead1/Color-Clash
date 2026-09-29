-- Engine: boot and staging (FLOW-01, UI-01 server side, SEC-01 dev gate). Runs inside the live server VM.
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local S = t.services
	local Players = game:GetService("Players")

	describe("Boot", function()
		it("starts every service exactly once", function()
			expect(game.ServerScriptService:GetAttribute("ColorClashServerStarted")):toBe(true)
			expect(game.ServerScriptService:GetAttribute("ColorClashServices")):toBe(10)
			local net = game.ReplicatedStorage:FindFirstChild("ColorClashNet")
			expect(net ~= nil):toBe(true)
			local names = {}
			for _, r in net:GetChildren() do
				expect(names[r.Name]):toBe(nil) -- no duplicated remotes
				names[r.Name] = true
			end
			expect(Players.CharacterAutoLoads):toBe(false)
		end)

		it("dev gate is on in Studio with the Dev folder and refuses nothing here", function()
			expect(S.DevGate.enabled()):toBe(true)
		end)
	end)

	describe("Staging (FLOW-01)", function()
		it("a lone player waits in staging without a fake match", function()
			expect(S.RoundService.state()):toBe("Waiting")
			expect(S.RoundService.matchId()):toBe(0)
			local p = Players:GetPlayers()[1]
			expect(p ~= nil):toBe(true)
			expect(p:GetAttribute("CCParticipating")):toBe(false)
		end)

		it("spawns on the staging platform and stays there", function()
			local p = Players:GetPlayers()[1]
			local life = S.CharacterService.spawnInStaging(p, 1)
			expect(life ~= nil):toBe(true)
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			expect(root ~= nil):toBe(true)
			local samples = {}
			for k = 1, 6 do
				table.insert(samples, root.Position)
				task.wait(0.5)
			end
			local staging = S.MapService.stagingCFrame(1).Position
			for k, pos in samples do
				expect(pos.Y):toBeGreaterThan(staging.Y - 5)
				expect((Vector3.new(pos.X, 0, pos.Z) - Vector3.new(staging.X, 0, staging.Z)).Magnitude):toBeLessThan(25)
			end
		end)
	end)
end
