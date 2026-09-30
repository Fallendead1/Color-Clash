-- MAP-01 (pure part): the tactical projection is built from the same grid, so it shows exactly the scoreable
-- surfaces and their ownership; walls and base floors never appear; stacked layers are detected. Launch target
-- selection lists only living teammates plus Base. Runs under Lune and Studio.
return function(t)
	local Surface = t.require("Paint/Surface")
	local PaintGrid = t.require("Paint/PaintGrid")
	local TacticalMap = t.require("Paint/TacticalMap")
	local describe, it, expect = t.describe, t.it, t.expect

	local UP, RIGHT, LOOK = vector.create(0, 1, 0), vector.create(1, 0, 0), vector.create(0, 0, -1)
	local function box(id, cx, cy, cz, sx, sz, props)
		return Surface.fromBox(id, vector.create(cx, cy - 0.5, cz), vector.create(sx, 1, sz), RIGHT, UP, LOOK, "Top", props)
	end
	local FLOOR = { Scoreable = true, Climbable = false, Kind = "Floor" }

	describe("TacticalMap", function()
		it("projects exactly the scoring cells and their owners", function()
			local wall = Surface.fromBox("w", vector.create(0, 4, 12), vector.create(20, 8, 1), RIGHT, UP, LOOK, "Front", {
				Scoreable = false,
				Climbable = true,
				Kind = "Wall",
			})
			local base = box("b", 40, 0, 0, 10, 10, { Scoreable = false, Climbable = false, Kind = "Base", InitialOwner = 1 })
			local grid = PaintGrid.new({ box("f1", 0, 0, 0, 20, 20, FLOOR), box("f2", 0, 6, 30, 10, 10, FLOOR), wall, base })
			grid:stampSphere(vector.create(0, 0, 0), 5, 1)
			grid:stampSphere(vector.create(0, 6, 30), 3, 2)
			grid:stampSphere(vector.create(0, 4, 11.5), 3, 2) -- wall paint: never on the map
			local proj = TacticalMap.project(grid, 2)
			expect(proj.scoringCells):toBe(grid.totalScoringArea)
			expect(proj.totals[0]):toBe(grid.totals[0])
			expect(proj.totals[1]):toBe(grid.totals[1])
			expect(proj.totals[2]):toBe(grid.totals[2])
			expect(proj.stackedPixels):toBe(0)
			-- the painted centre of f1 reads as team 1
			local px = math.floor((0 - proj.minX) / 2)
			local pz = math.floor((0 - proj.minZ) / 2)
			expect(TacticalMap.pixelOwner(proj, px, pz)):toBe(1)
			-- the base floor (x 35..45) is outside the scoring projection
			expect(proj.minX + proj.w * proj.pixel <= 35):toBe(true)
		end)

		it("reports a hidden second layer", function()
			local grid = PaintGrid.new({ box("lo", 0, 0, 0, 10, 10, FLOOR), box("hi", 0, 10, 0, 10, 10, FLOOR) })
			local proj = TacticalMap.project(grid, 2)
			expect(proj.stackedPixels > 0):toBe(true)
		end)

		it("offers Base plus living teammates only", function()
			local list = TacticalMap.launchTargets(1, 1, {
				{ id = 1, team = 1, alive = true, name = "self" },
				{ id = 2, team = 1, alive = true, name = "zed" },
				{ id = 3, team = 1, alive = false, name = "dead" },
				{ id = 4, team = 2, alive = true, name = "enemy" },
				{ id = 5, team = 1, alive = true, name = "amy" },
			})
			expect(#list):toBe(3)
			expect(list[1].key):toBe("Base")
			expect(list[2].key):toBe(5)
			expect(list[3].key):toBe(2)
			expect(#TacticalMap.launchTargets(1, 0, {})):toBe(1)
		end)
	end)
end
