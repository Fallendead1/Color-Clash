-- PERF-01 companion: a realistic heavy pattern on stress_lab — thousands of overlapping weapon-sized splats from
-- both teams until the floor is ~90% claimed — to size typical renderer part counts (the checkerboard is the
-- adversarial bound). Pair with the client spec "PerfPaintStress" (start it first).
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local S = t.services
	local MapLoader = require(game.ServerScriptService.Server.Map.MapLoader)
	local StressLab = require(S.Dev.fixtures.StressLab)

	describe("Realistic heavy paint on stress_lab (fixture)", function()
		it("paints overlapping splats and flushes in 10 Hz-sized batches", function()
			S.MapService.unload()
			local model = StressLab.build()
			model.Parent = workspace.ColorClashArena
			local desc = MapLoader.load(model, true)
			S.PaintService.setMap(desc, 9003)
			local grid = S.PaintService.grid()
			S.PaintService.syncAll()
			task.wait(3)
			local rng = Random.new(12345)
			local splats = 0
			local maxBytes = 0
			local t0 = os.clock()
			while (grid.totals[1] + grid.totals[2]) < grid.totalScoringArea * 0.9 and splats < 20000 do
				for _ = 1, 40 do -- ~ a burst of shots between two 10 Hz flushes
					local x = rng:NextNumber(-250, 250)
					local z = rng:NextNumber(-50, 50)
					local r = rng:NextNumber(1.5, 6)
					local team = if rng:NextNumber() < 0.5 then 1 else 2
					grid:stampSphere(vector.create(x, 300, z), r, team, nil)
					splats += 1
				end
				local buf = grid:flushDelta()
				if buf then
					maxBytes = math.max(maxBytes, buffer.len(buf))
					S.NetService.fireAll("Paint", "delta", 9003, desc.mapVersion, buf)
				end
				task.wait()
			end
			workspace:SetAttribute("CCRealisticSplats", splats)
			workspace:SetAttribute("CCRealisticSeconds", math.floor((os.clock() - t0) * 10) / 10)
			workspace:SetAttribute("CCRealisticMaxDeltaBytes", maxBytes)
			workspace:SetAttribute("CCTestServerPaintHash", grid:hash())
			expect(grid.totals[1] + grid.totals[2]):toBeGreaterThan(grid.totalScoringArea * 0.89)
		end)
	end)
end
