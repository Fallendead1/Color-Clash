-- PAINT-01..05, PAINT-10 (pure parts), NET-01/02 (encoding), invariants. Runs under Lune and Studio.
return function(t)
	local Surface = t.require("Paint/Surface")
	local PaintGrid = t.require("Paint/PaintGrid")
	local describe, it, expect = t.describe, t.it, t.expect

	local UP, RIGHT, LOOK = vector.create(0, 1, 0), vector.create(1, 0, 0), vector.create(0, 0, -1)

	local function floor(id, cx, cz, sx, sz, props)
		return Surface.fromBox(id, vector.create(cx, -0.5, cz), vector.create(sx, 1, sz), RIGHT, UP, LOOK, "Top", props or {
			Scoreable = true,
			Climbable = false,
			Kind = "Floor",
		})
	end

	local function checkInvariant(grid)
		local rc = grid:recount()
		expect(grid.totals[0]):toBe(rc[0])
		expect(grid.totals[1]):toBe(rc[1])
		expect(grid.totals[2]):toBe(rc[2])
		expect(grid.totals[0] + grid.totals[1] + grid.totals[2]):toBe(grid.totalScoringArea)
	end

	describe("Surface", function()
		it("builds a right-handed top face with integer sizes", function()
			local d = floor("f", 0, 0, 20, 10)
			local ok, err = Surface.validate(d)
			expect(ok):toBe(true)
			expect(err):toBe(nil)
			expect(d.SizeU):toBe(20)
			expect(d.SizeV):toBe(10)
			expect(vector.dot(vector.cross(d.U, d.V), d.Normal)):toNear(1)
			-- every cell centre lies on the top plane y = 0 and inside the box footprint
			local c = Surface.cellCenter(d, 0, 0)
			expect(c.Y):toNear(0)
			expect(math.abs(c.X)):toBeAtMost(10)
			expect(math.abs(c.Z)):toBeAtMost(5)
		end)

		it("rejects scoreable walls, ceilings and bad bases", function()
			local wall = Surface.fromBox("w", vector.create(0, 4, 0), vector.create(10, 8, 1), RIGHT, UP, LOOK, "Front", {
				Scoreable = true,
				Climbable = true,
				Kind = "Wall",
			})
			expect((Surface.validate(wall))):toBe(false)
			local ceiling = floor("c", 0, 0, 4, 4)
			ceiling.Normal = -ceiling.Normal
			ceiling.V = -ceiling.V
			expect((Surface.validate(ceiling))):toBe(false)
		end)

		it("maps a rotated ramp with its own local grid (PAINT-05)", function()
			local ang = math.rad(25)
			local up = vector.create(0, math.cos(ang), -math.sin(ang))
			local look = vector.create(0, -math.sin(ang), -math.cos(ang))
			local ramp = Surface.fromBox("ramp", vector.create(0, 2, 0), vector.create(8, 1, 12), RIGHT, up, look, "Top", {
				Scoreable = true,
				Climbable = false,
				Kind = "Ramp",
			})
			expect((Surface.validate(ramp))):toBe(true)
			expect(ramp.Normal.Y):toNear(math.cos(ang), 1e-6)
			-- a point on the ramp surface maps into its grid and back
			local c = Surface.cellCenter(ramp, 3, 7)
			local i, j = Surface.locate(ramp, c, 0.1)
			expect(i):toBe(3)
			expect(j):toBe(7)
		end)
	end)

	describe("PaintGrid", function()
		it("paints a known 10x10 region exactly (PAINT-01)", function()
			local g = PaintGrid.new({ floor("f", 0, 0, 40, 40) })
			expect(g.totalScoringArea):toBe(1600)
			local p = g.patches[1]
			local changed = 0
			for j = 5, 14 do
				for i = 5, 14 do
					if g:setCell(p, i, j, 1) ~= nil then
						changed += 1
					end
				end
			end
			expect(changed):toBe(100)
			expect(g.totals[1]):toBe(100)
			expect(g.totals[0]):toBe(1500)
			checkInvariant(g)
		end)

		it("repainting with the same team changes nothing (PAINT-02)", function()
			local g = PaintGrid.new({ floor("f", 0, 0, 40, 40) })
			local r1 = g:stampSphere(vector.create(0, 0, 0), 4, 1)
			local r2 = g:stampSphere(vector.create(0, 0, 0), 4, 1)
			expect(r1.changed):toBeGreaterThan(40)
			expect(r2.changed):toBe(0)
			expect(r2.scoreableConverted):toBe(0)
			checkInvariant(g)
		end)

		it("opponent repaint transfers exactly (PAINT-03)", function()
			local g = PaintGrid.new({ floor("f", 0, 0, 40, 40) })
			local p = g.patches[1]
			for j = 0, 9 do
				for i = 0, 9 do
					g:setCell(p, i, j, 1)
				end
			end
			local moved = 0
			for j = 0, 4 do
				for i = 0, 9 do
					if g:setCell(p, i, j, 2) == 1 then
						moved += 1
					end
				end
			end
			expect(moved):toBe(50)
			expect(g.totals[1]):toBe(50)
			expect(g.totals[2]):toBe(50)
			checkInvariant(g)
		end)

		it("sphere stamp paints only cells within radius", function()
			local g = PaintGrid.new({ floor("f", 0, 0, 40, 40) })
			local r = g:stampSphere(vector.create(0.3, 0, -0.2), 2, 1, { collect = true })
			expect(r.changed):toBeGreaterThan(8)
			expect(r.changed):toBeAtMost(16)
			for _, c in r.changes do
				local i, j = Surface.cellCoords(g.patches[1].def, c.cell)
				local center = Surface.cellCenter(g.patches[1].def, i, j)
				expect(vector.magnitude(center - vector.create(0.3, 0, -0.2))):toBeAtMost(2)
			end
		end)

		it("walls change ownership but never score (PAINT-04)", function()
			local wall = Surface.fromBox("wall", vector.create(0, 4, -5), vector.create(10, 8, 1), RIGHT, UP, LOOK, "Back", {
				Scoreable = false,
				Climbable = true,
				Kind = "Wall",
			})
			local g = PaintGrid.new({ floor("f", 0, 0, 20, 8), wall })
			local before = g.totals[1]
			local r = g:stampSphere(vector.create(0, 4, -4.5), 2, 1, { collect = true })
			expect(r.changed):toBeGreaterThan(0)
			expect(r.scoreableConverted):toBe(0)
			expect(g.totals[1]):toBe(before)
			expect(g.patches[2].counts[1]):toBe(r.changed)
			checkInvariant(g)
		end)

		it("masked cells and non-scoring base never change score (PAINT-04)", function()
			local f = floor("f", 0, 0, 10, 10)
			local mask = buffer.create(100)
			buffer.fill(mask, 0, 1)
			for k = 0, 9 do
				buffer.writeu8(mask, k, 0) -- first row illegal
			end
			f.Mask = mask
			local base = floor("base", 30, 0, 8, 8, { Scoreable = false, Climbable = false, Kind = "Base", InitialOwner = 1 })
			local g = PaintGrid.new({ f, base })
			expect(g.totalScoringArea):toBe(90)
			expect(g.totals[1]):toBe(0)
			g:stampSphere(vector.create(0, 0, 0), 20, 2)
			expect(g.totals[2]):toBe(90)
			local p = g.patches[1]
			for k = 0, 9 do
				expect(buffer.readu8(p.owner, k)):toBe(0)
			end
			-- base starts in its team colour, is outside scoring and stays outside scoring when repainted
			g:stampSphere(vector.create(30, 0, 0), 3, 2)
			expect(g.totals[2]):toBe(90)
			checkInvariant(g)
		end)

		it("does not paint through a thin wall with occlusion (PAINT-06)", function()
			-- Floor spans both sides of a wall at z = 0. A blast at z = -1 must not reach z > 0.
			local g = PaintGrid.new({ floor("f", 0, 0, 20, 20) })
			local function blocked(from, to)
				-- wall plane z = 0 blocks segments that cross it (height up to 8)
				if (from.Z < 0) ~= (to.Z < 0) then
					return false
				end
				return true
			end
			local r = g:stampSphere(vector.create(0, 0.2, -1), 6, 1, { isVisible = blocked, origin = vector.create(0, 0.5, -1), collect = true })
			expect(r.changed):toBeGreaterThan(0)
			for _, c in r.changes do
				local i, j = Surface.cellCoords(g.patches[1].def, c.cell)
				expect(Surface.cellCenter(g.patches[1].def, i, j).Z):toBeLessThan(0)
			end
		end)

		it("does not paint the back of a face or a parallel face behind the origin (PAINT-05/07)", function()
			local front = Surface.fromBox("front", vector.create(0, 4, 0), vector.create(10, 8, 0.5), RIGHT, UP, LOOK, "Back", {
				Scoreable = false,
				Climbable = true,
				Kind = "Wall",
			}) -- faces +Z at z = 0.25
			local backFace = Surface.fromBox("back", vector.create(0, 4, 0), vector.create(10, 8, 0.5), RIGHT, UP, LOOK, "Front", {
				Scoreable = false,
				Climbable = true,
				Kind = "Wall",
			}) -- faces -Z at z = -0.25
			local g = PaintGrid.new({ front, backFace })
			g:stampSphere(vector.create(0, 4, 0.4), 2, 1, { origin = vector.create(0, 4, 0.6) })
			expect(g.patches[1].counts[1]):toBeGreaterThan(0)
			expect(g.patches[2].counts[1]):toBe(0)
		end)

		it("paints an adjacent visible face near an edge (PAINT-07)", function()
			-- floor and a wall rising from its edge at z = -5 facing +Z; blast near the corner paints both
			local wall = Surface.fromBox("wall", vector.create(0, 4, -5.5), vector.create(10, 8, 1), RIGHT, UP, LOOK, "Back", {
				Scoreable = false,
				Climbable = true,
				Kind = "Wall",
			})
			local g = PaintGrid.new({ floor("f", 0, 0, 10, 10), wall })
			g:stampSphere(vector.create(0, 0.5, -4.5), 3, 2, { origin = vector.create(0, 0.8, -4.2) })
			expect(g.patches[1].counts[2]):toBeGreaterThan(0)
			expect(g.patches[2].counts[2]):toBeGreaterThan(0)
		end)

		it("rect stamp paints a forward footprint on floors only", function()
			local g = PaintGrid.new({ floor("f", 0, 0, 40, 40) })
			local r = g:stampRect(vector.create(0, 0, -7), vector.create(0, 0, -1), 14, 8, 3, 1)
			expect(r.changed):toBe(14 * 8)
			checkInvariant(g)
		end)

		it("frozen grid ignores late paint (PAINT-10)", function()
			local g = PaintGrid.new({ floor("f", 0, 0, 20, 20) })
			g:stampSphere(vector.create(0, 0, 0), 3, 1)
			local before = g.totals[1]
			g:freeze()
			local r = g:stampSphere(vector.create(5, 0, 5), 3, 2)
			expect(r.changed):toBe(0)
			expect(g.totals[1]):toBe(before)
			expect(g.totals[2]):toBe(0)
		end)

		it("rejects duplicate surface ids and over-budget maps (MAP-02)", function()
			expect(function()
				PaintGrid.new({ floor("x", 0, 0, 4, 4), floor("x", 10, 0, 4, 4) })
			end):toThrow("duplicate SurfaceId")
			expect(function()
				PaintGrid.new({ floor("x", 0, 0, 100, 100) }, { MaxScoringCells = 5000 })
			end):toThrow("exceeds budget")
		end)

		it("reset restores initial ownership and bumps versions (PAINT-11)", function()
			local g = PaintGrid.new({ floor("f", 0, 0, 20, 20) })
			g:stampSphere(vector.create(0, 0, 0), 5, 1)
			local v = g.chunkVersion[1]
			g:reset()
			expect(g.totals[1]):toBe(0)
			expect(g.totals[0]):toBe(400)
			expect(g.chunkVersion[1]):toBeGreaterThan(v)
			expect(g.dirtyCount):toBe(0)
		end)
	end)

	describe("PaintGrid sync encoding", function()
		local function pair()
			local defs = { floor("f", 0, 0, 40, 24), floor("g", 60, 0, 17, 33) }
			return PaintGrid.new(defs), PaintGrid.new(defs)
		end

		it("snapshot reproduces the server exactly (NET-01)", function()
			local server, client = pair()
			server:stampSphere(vector.create(3, 0, 2), 6, 1)
			server:stampSphere(vector.create(60, 0, 5), 7, 2)
			server:flushDelta()
			local snap = server:encodeChunks()
			client:applyEncoded(snap)
			expect(client:hash()):toBe(server:hash())
			expect(client.totals[1]):toBe(server.totals[1])
			expect(client.totals[2]):toBe(server.totals[2])
		end)

		it("ignores stale and duplicated chunk versions (NET-02)", function()
			local server, client = pair()
			server:stampSphere(vector.create(0, 0, 0), 4, 1)
			local d1 = server:flushDelta()
			server:stampSphere(vector.create(0, 0, 0), 4, 2)
			local d2 = server:flushDelta()
			assert(d1 and d2)
			-- deliver out of order: newer first, then the stale one, then a duplicate
			client:applyEncoded(d2)
			local _, appliedStale = client:applyEncoded(d1)
			local _, appliedDup = client:applyEncoded(d2)
			expect(appliedStale):toBe(0)
			expect(appliedDup):toBe(0)
			expect(client:hash()):toBe(server:hash())
		end)

		it("snapshot at sequence S plus later deltas converges (NET-01 replay)", function()
			local server, client = pair()
			server:stampSphere(vector.create(5, 0, 5), 5, 1)
			server:flushDelta()
			local snap = server:encodeChunks()
			server:stampSphere(vector.create(6, 0, 5), 5, 2)
			local later = server:flushDelta()
			assert(later)
			-- the client receives the later delta before the snapshot (buffering order) — still converges
			client:applyEncoded(later)
			client:applyEncoded(snap)
			expect(client:hash()):toBe(server:hash())
		end)

		it("rejects malformed payload lengths (SEC-05)", function()
			local _, client = pair()
			local bad = buffer.create(10)
			buffer.writeu16(bad, 4, 3)
			expect(function()
				client:applyEncoded(bad)
			end):toThrow("malformed")
		end)

		it("full snapshot of a max-budget map fits the 160 KiB target", function()
			-- 50,000 scoring cells + 16,000 wall cells in large patches
			local defs = {}
			for k = 1, 5 do
				table.insert(defs, floor("s" .. k, k * 120, 0, 100, 100))
			end
			for k = 1, 4 do
				table.insert(defs, Surface.fromBox("w" .. k, vector.create(k * 120, 10, 200), vector.create(100, 40, 1), RIGHT, UP, LOOK, "Back", {
					Scoreable = false,
					Climbable = false,
					Kind = "Wall",
				}))
			end
			local g = PaintGrid.new(defs, { MaxScoringCells = 50000, MaxWallCells = 16000 })
			expect(g.totalScoringArea):toBe(50000)
			expect(g.totalWallCells):toBe(16000)
			local snap = g:encodeChunks()
			expect(buffer.len(snap)):toBeAtMost(160 * 1024)
		end)
	end)
end
