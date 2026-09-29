-- COMBAT-06 / COMBAT-10 credit rules (pure) and prediction preview parity.
return function(t)
	local Credit = t.require("Combat/Credit")
	local GameConfig = t.require("Config/GameConfig")
	local PaintGrid = t.require("Paint/PaintGrid")
	local Surface = t.require("Paint/Surface")
	local describe, it, expect = t.describe, t.it, t.expect
	local C = GameConfig.Combat

	local function enemyOf(victimTeam)
		return function(a)
			return a.team ~= victimTeam
		end
	end

	describe("Elimination credit", function()
		local A = { name = "A", team = 1 }
		local B = { name = "B", team = 1 }
		local F = { name = "F", team = 2 } -- same team as the victim

		it("credits the final damaging enemy once; assist needs >= 20 within 5 s (COMBAT-06)", function()
			local log = {
				{ attacker = B, amount = 24, t = 10, weapon = "sprayline" },
				{ attacker = A, amount = 24, t = 11, weapon = "sprayline" },
				{ attacker = A, amount = 60, t = 12, weapon = "sprayline" },
			}
			local credited, weapon, assists = Credit.resolve(log, 12, A, "sprayline", enemyOf(2), C)
			expect(credited):toBe(A)
			expect(weapon):toBe("sprayline")
			expect(#assists):toBe(1)
			expect(assists[1]):toBe(B)
		end)

		it("no assist below 20 damage or outside the 5 s window", function()
			local log = {
				{ attacker = B, amount = 19, t = 11 },
				{ attacker = A, amount = 100, t = 12 },
			}
			local _, _, assists = Credit.resolve(log, 12, A, nil, enemyOf(2), C)
			expect(#assists):toBe(0)
			local log2 = {
				{ attacker = B, amount = 50, t = 6.9 },
				{ attacker = A, amount = 100, t = 12 },
			}
			local _, _, assists2 = Credit.resolve(log2, 12, A, nil, enemyOf(2), C)
			expect(#assists2):toBe(0)
		end)

		it("environmental elimination credits the recent enemy hit within 5 s (COMBAT-10)", function()
			local log = { { attacker = A, amount = 24, t = 10, weapon = "popshot" } }
			local credited, weapon = Credit.resolve(log, 14.5, nil, nil, enemyOf(2), C)
			expect(credited):toBe(A)
			expect(weapon):toBe("popshot")
			local none = Credit.resolve(log, 15.1, nil, nil, enemyOf(2), C)
			expect(none):toBe(nil)
		end)

		it("friendly keys are never credited", function()
			local log = { { attacker = F, amount = 50, t = 10 } }
			local credited = Credit.resolve(log, 11, nil, nil, enemyOf(2), C)
			expect(credited):toBe(nil)
		end)
	end)

	describe("Prediction preview parity", function()
		it("previewSphere returns exactly the cells stampSphere changes", function()
			local def = Surface.fromBox("f", vector.create(0, -0.5, 0), vector.create(30, 1, 30), vector.create(1, 0, 0), vector.create(0, 1, 0), vector.create(0, 0, -1), "Top", {
				Scoreable = true,
				Climbable = false,
				Kind = "Floor",
			})
			local g = PaintGrid.new({ def })
			g:stampSphere(vector.create(2, 0, 2), 3, 2)
			local preview = g:previewSphere(vector.create(1, 0, 1), 3.5, 1)
			local before = g:hash()
			expect(g:hash()):toBe(before) -- preview does not mutate
			local r = g:stampSphere(vector.create(1, 0, 1), 3.5, 1, { collect = true })
			expect(#preview):toBe(r.changed)
			local set = {}
			for _, c in r.changes do
				local i, j = Surface.cellCoords(def, c.cell)
				set[i .. "," .. j] = true
			end
			for _, p in preview do
				expect(set[p.i .. "," .. p.j]):toBe(true)
			end
		end)
	end)
end
