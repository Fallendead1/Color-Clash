-- PAINT-08 / PERF-01 server side: load stress_lab (max budget), write the worst-case alternating (checkerboard)
-- pattern over every legal cell, flush to clients and publish the hash. Measures load and flush costs.
-- Run manually (heavy): CCTestRequest = "engine:PaintStress". Follow with the client spec "PaintStress".
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local S = t.services
	local MapLoader = require(game.ServerScriptService.Server.Map.MapLoader)
	local StressLab = require(S.Dev.fixtures.StressLab)

	describe("Paint stress at map budget (fixture)", function()
		local grid
		it("loads stress_lab and validates masks within budget", function()
			S.MapService.unload()
			local model = StressLab.build()
			model.Parent = workspace.ColorClashArena
			local t0 = os.clock()
			local desc, errors = MapLoader.load(model, true)
			local loadMs = (os.clock() - t0) * 1000
			expect(#errors):toBe(0)
			S.PaintService.setMap(desc, 9002)
			grid = S.PaintService.grid()
			workspace:SetAttribute("CCStressLoadMs", math.floor(loadMs))
			workspace:SetAttribute("CCStressCells", grid.totalScoringArea + grid.totalWallCells)
			expect(grid.totalScoringArea):toBeAtMost(50000)
			expect(grid.totalScoringArea):toBeGreaterThan(49900)
			expect(grid.totalWallCells):toBe(16000)
		end)

		it("writes the alternating worst case and flushes one bounded delta", function()
			S.PaintService.syncAll()
			task.wait(3) -- let the client apply the (empty) snapshot first
			local t0 = os.clock()
			for _, patch in grid.patches do
				local def = patch.def
				for j = 0, def.SizeV - 1 do
					for i = 0, def.SizeU - 1 do
						grid:setCell(patch, i, j, if (i + j) % 2 == 0 then 1 else 2)
					end
				end
			end
			local writeMs = (os.clock() - t0) * 1000
			local t1 = os.clock()
			local buf = grid:flushDelta()
			local flushMs = (os.clock() - t1) * 1000
			expect(buf ~= nil):toBe(true)
			-- send the delta with the correct match/map tags (PaintService.flush would do the same)
			local desc = S.MapService.current()
			S.NetService.fireAll("Paint", "delta", 9002, desc and desc.mapVersion or 1, buf)
			workspace:SetAttribute("CCStressDeltaBytes", buffer.len(buf))
			workspace:SetAttribute("CCStressWriteMs", math.floor(writeMs))
			workspace:SetAttribute("CCStressFlushMs", math.floor(flushMs * 10) / 10)
			workspace:SetAttribute("CCTestServerPaintHash", grid:hash())
			workspace:SetAttribute("CCTestServerTotals", string.format("%d/%d/%d", grid.totals[0], grid.totals[1], grid.totals[2]))
			expect(buffer.len(buf)):toBeAtMost(40 * 1024)
			local rc = grid:recount()
			expect(rc[1] + rc[2]):toBe(grid.totalScoringArea)
		end)
	end)
end
