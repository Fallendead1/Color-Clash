-- Engine: boot and staging (FLOW-01, UI-01 server side, SEC-01 dev gate). Runs inside the live server VM.
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local S = t.services
	local Players = game:GetService("Players")

	describe("Boot", function()
		it("starts every service exactly once", function()
			expect(game.ServerScriptService:GetAttribute("ColorClashServerStarted")):toBe(true)
			expect(game.ServerScriptService:GetAttribute("ColorClashServices")):toBe(11)
			local net = game.ReplicatedStorage:FindFirstChild("ColorClashNet")
			expect(net ~= nil):toBe(true)
			local names = {}
			for _, r in net:GetChildren() do
				expect(names[r.Name]):toBe(nil) -- no duplicated remotes
				names[r.Name] = true
			end
			expect(Players.CharacterAutoLoads):toBe(false)
		end)

		it("dev gate is on in Studio with the Dev folder", function()
			expect(S.DevGate.enabled()):toBe(true)
		end)

		it("SEC-01: without the Dev folder (production layout) the gate refuses every override", function()
			-- A copy of DevGate in a folder that has no Dev sibling behaves exactly like the production build.
			local folder = Instance.new("Folder")
			local gate = game.ServerScriptService.Server.DevGate:Clone()
			gate.Parent = folder
			local G = require(gate)
			expect(G.enabled()):toBe(false)
			expect(G.set("MinimumReady", 1)):toBe(false)
			expect(G.get("MinimumReady", 4)):toBe(4)
			expect(G.devFolder()):toBe(nil)
			folder:Destroy()
		end)

		it("SEC-01: no remote offers development or cheat controls", function()
			for _, r in game.ReplicatedStorage.ColorClashNet:GetChildren() do
				local n = string.lower(r.Name)
				expect(string.find(n, "dev") == nil and string.find(n, "test") == nil and string.find(n, "give") == nil and string.find(n, "setwinner") == nil and string.find(n, "teleport") == nil):toBe(true)
			end
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
			for _ = 1, 6 do
				table.insert(samples, root.Position)
				task.wait(0.5)
			end
			local staging = S.MapService.stagingCFrame(1).Position
			for _, pos in samples do
				expect(pos.Y):toBeGreaterThan(staging.Y - 5)
				expect((Vector3.new(pos.X, 0, pos.Z) - Vector3.new(staging.X, 0, staging.Z)).Magnitude):toBeLessThan(25)
			end
		end)
	end)
end
