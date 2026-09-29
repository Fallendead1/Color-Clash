-- Engine paint tests on the paint_lab FIXTURE with real collision geometry and real raycast occlusion.
-- PAINT-01, 02, 03, 04, 05, 06, 07 (engine level). Leaves the fixture loaded with a known pattern and publishes the
-- authoritative hash in Workspace attribute CCTestServerPaintHash for the client render comparison (PAINT-08/NET-01).
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local S = t.services
	local Shared = game.ReplicatedStorage.Shared
	local Surface = require(Shared.Paint.Surface)

	local Y = 100

	local function owner(grid, surfaceId, x, z, yOverride)
		local patch = grid:getPatch(surfaceId)
		local p = vector.create(x, yOverride or Y, z)
		local i, j = Surface.locate(patch.def, p, 0.6)
		if not i then
			return nil
		end
		return buffer.readu8(patch.owner, j * patch.def.SizeU + i)
	end

	local function check(grid)
		local rc = grid:recount()
		expect(grid.totals[1]):toBe(rc[1])
		expect(grid.totals[2]):toBe(rc[2])
		expect(grid.totals[0] + grid.totals[1] + grid.totals[2]):toBe(grid.totalScoringArea)
	end

	describe("Paint on fixture geometry", function()
		local grid

		it("loads the fixture outside a round", function()
			expect(S.RoundService.state()):toBe("Waiting")
			local desc, errors = S.MapService.loadNext()
			expect(#errors):toBe(0)
			expect(desc.isFixture):toBe(true)
			S.PaintService.setMap(desc, 9001)
			grid = S.PaintService.grid()
			expect(grid.totalScoringArea):toBe(5264)
		end)

		it("PAINT-01 exact 10x10 region via rect stamp", function()
			local r = S.PaintService.paintRect(Vector3.new(-20, Y, 0), Vector3.new(0, 0, -1), 10, 10, 1, { origin = Vector3.new(-20, Y + 3, 0) })
			expect(r.changed):toBe(100)
			expect(grid.totals[1]):toBe(100)
			check(grid)
		end)

		it("PAINT-02 same-team repaint changes nothing", function()
			local r = S.PaintService.paintRect(Vector3.new(-20, Y, 0), Vector3.new(0, 0, -1), 10, 10, 1, { origin = Vector3.new(-20, Y + 3, 0) })
			expect(r.changed):toBe(0)
			expect(grid.totals[1]):toBe(100)
		end)

		it("PAINT-03 opponent repaints half exactly", function()
			local r = S.PaintService.paintRect(Vector3.new(-20, Y, 2.5), Vector3.new(0, 0, -1), 5, 10, 2, { origin = Vector3.new(-20, Y + 3, 2.5) })
			expect(r.changed):toBe(50)
			expect(grid.totals[1]):toBe(50)
			expect(grid.totals[2]):toBe(50)
			check(grid)
		end)

		it("PAINT-06 a blast beside the thin cover does not paint the far side", function()
			-- thin_cover: x 15.75..16.25, z -14..-6, 7 high
			local r = S.PaintService.paintSphere(Vector3.new(14.5, Y + 0.3, -10), 5, 1, { origin = Vector3.new(14.5, Y + 1, -10) })
			expect(r.changed):toBeGreaterThan(20)
			for x = 16.5, 19.5, 1 do
				for z = -13.5, -6.5, 1 do
					expect(owner(grid, "floor_center", x, z)):toBe(0)
				end
			end
			expect(owner(grid, "floor_center", 14.5, -10)):toBe(1)
			check(grid)
		end)

		it("PAINT-06/07 a blast north of the double-faced wall paints its north face only", function()
			-- wall core z -20.8..-19.2 plus faces at z -19.0 (north, +Z) and -21.0 (south, -Z)
			local r = S.PaintService.paintSphere(Vector3.new(0, Y + 1, -18), 4, 2, { origin = Vector3.new(0, Y + 1.5, -18) })
			expect(r.changed):toBeGreaterThan(10)
			expect(grid:getPatch("paint_wall_north").counts[2]):toBeGreaterThan(0)
			expect(grid:getPatch("paint_wall_south").counts[2]):toBe(0)
			for x = -2.5, 2.5, 1 do
				expect(owner(grid, "floor_center", x, -21.5)):toBe(0) -- floor south of the wall
			end
			expect(owner(grid, "floor_center", 0.5, -18.5)):toBe(2)
			check(grid)
		end)

		it("PAINT-05 paints the rotated ramp on its own grid and not the masked floor under it", function()
			local ramp = grid:getPatch("ramp_east")
			local c = Surface.cellCenter(ramp.def, 6, 4)
			local center = Vector3.new(c.X, c.Y, c.Z)
			local n = Vector3.new(ramp.def.Normal.X, ramp.def.Normal.Y, ramp.def.Normal.Z)
			local r = S.PaintService.paintSphere(center + n * 0.2, 2, 1, { origin = center + n * 1.5, player = nil })
			expect(r.changed):toBeGreaterThan(5)
			expect(ramp.counts[1]):toBeGreaterThan(5)
			-- floor cells under the ramp are masked: never owned
			local floor = grid:getPatch("floor_center")
			for x = 6.5, 17.5, 1 do
				for z = 16.5, 23.5, 1 do
					local i, j = Surface.locate(floor.def, vector.create(x, Y, z), 0.6)
					local k = j * floor.def.SizeU + i
					expect(Surface.isLegal(floor.def, k)):toBe(false)
					expect(buffer.readu8(floor.owner, k)):toBe(0)
				end
			end
			check(grid)
		end)

		it("PAINT-04 walls and the protected base change ownership without score", function()
			local before1, before2 = grid.totals[1], grid.totals[2]
			local wallBefore = grid:getPatch("platform_climb_south").counts[1]
			S.PaintService.paintSphere(Vector3.new(0, Y + 2.5, 13.7), 2, 1, { origin = Vector3.new(0, Y + 2.5, 12) })
			expect(grid:getPatch("platform_climb_south").counts[1]):toBeGreaterThan(wallBefore)
			S.PaintService.paintSphere(Vector3.new(40, Y + 0.2, 0), 3, 1, { origin = Vector3.new(40, Y + 1, 0) })
			expect(grid:getPatch("base_B").counts[1]):toBeGreaterThan(0)
			expect(grid.totals[1]):toBe(before1)
			expect(grid.totals[2]):toBe(before2)
			check(grid)
		end)

		it("no painting through a roof onto floor beneath (canopy)", function()
			local floorBefore = grid.totals[1]
			S.PaintService.paintSphere(Vector3.new(-16, Y + 11.2, 18), 3, 1, { origin = Vector3.new(-16, Y + 12, 18) })
			expect(grid.totals[1]):toBe(floorBefore)
		end)

		it("flushes and publishes the authoritative hash for the client comparison", function()
			S.PaintService.syncAll()
			S.PaintService.flush()
			workspace:SetAttribute("CCTestServerPaintHash", grid:hash())
			workspace:SetAttribute("CCTestServerTotals", string.format("%d/%d/%d", grid.totals[0], grid.totals[1], grid.totals[2]))
			expect(grid.dirtyCount):toBe(0)
		end)
	end)
end
