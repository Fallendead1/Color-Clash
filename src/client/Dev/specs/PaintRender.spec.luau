-- Client engine tests for the native renderer and the paint mirror (run after the server PaintEngine spec).
-- NET-01 (snapshot + deltas converge to the server hash), PAINT-08 (rendered ownership == authoritative ownership at
-- every legal cell of the fixture), PAINT-09 (palette switch), PAINT-12 (denied prediction removed).
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local C = t.services
	local Surface = t.require("Paint/Surface")

	local function waitFor(pred, timeout)
		local t0 = os.clock()
		while not pred() do
			if os.clock() - t0 > timeout then
				return false
			end
			task.wait(0.05)
		end
		return true
	end

	describe("Paint mirror and native renderer (fixture)", function()
		local P = C.PaintClient
		local R

		it("mirror converges to the authoritative hash (NET-01)", function()
			local target = workspace:GetAttribute("CCTestServerPaintHash")
			expect(target ~= nil):toBe(true)
			expect(waitFor(function()
				return P.grid() ~= nil and P.isSynced() and P.grid():hash() == target
			end, 10)):toBe(true)
			local totals = workspace:GetAttribute("CCTestServerTotals")
			local g = P.grid()
			expect(string.format("%d/%d/%d", g.totals[0], g.totals[1], g.totals[2])):toBe(totals)
		end)

		it("renders every legal cell with the authoritative owner (PAINT-08, fixture)", function()
			R = P.renderer()
			expect(R ~= nil):toBe(true)
			expect(waitFor(function()
				return R:Stats().queued == 0
			end, 10)):toBe(true)
			local g = P.grid()
			local mismatches, checked, owned = 0, 0, 0
			for pi, patch in g.patches do
				local def = patch.def
				for j = 0, def.SizeV - 1 do
					for i = 0, def.SizeU - 1 do
						local k = j * def.SizeU + i
						if Surface.isLegal(def, k) then
							checked += 1
							local want = buffer.readu8(patch.owner, k)
							if want ~= 0 then
								owned += 1
							end
							if R:RenderedOwnerAt(pi, i, j) ~= want then
								mismatches += 1
							end
						end
					end
				end
			end
			expect(checked):toBe(5264 + 1148)
			expect(owned):toBeGreaterThan(100)
			expect(mismatches):toBe(0)
			local st = R:Stats()
			expect(st.activeParts):toBeGreaterThan(0)
			expect(st.activeParts):toBeLessThan(owned) -- rectangles merge cells
		end)

		it("palette switch recolours paint without touching ownership (PAINT-09)", function()
			local g = P.grid()
			local hash = g:hash()
			local palette = { [1] = Color3.fromRGB(240, 228, 66), [2] = Color3.fromRGB(0, 90, 181) }
			R:SetPalette(palette)
			local wrong = 0
			for _, p in workspace.ColorClashPaint:GetChildren() do
				local o = p:GetAttribute("Owner")
				if p.Color ~= palette[o] then
					wrong += 1
				end
			end
			expect(wrong):toBe(0)
			expect(g:hash()):toBe(hash)
			R:SetPalette({ [1] = Color3.fromRGB(255, 138, 0), [2] = Color3.fromRGB(0, 150, 255) })
		end)

		it("a denied prediction disappears within 0.5 s (PAINT-12)", function()
			local before = R:Stats().activeParts
			R:Predict("test-shot-1", { { patch = 1, i = 2, j = 2 }, { patch = 1, i = 3, j = 2 } }, 1)
			expect(R:Stats().predicted):toBe(2)
			local t0 = os.clock()
			R:ExpireIn("test-shot-1", 0.25) -- denial arrives; removal scheduled inside the 0.5 s tolerance
			expect(waitFor(function()
				return R:Stats().predicted == 0
			end, 1)):toBe(true)
			expect(os.clock() - t0):toBeLessThan(0.5)
			expect(R:Stats().activeParts):toBe(before)
		end)

		it("an unresolved prediction can never persist (expiry)", function()
			R:Predict("test-shot-2", { { patch = 1, i = 5, j = 5 } }, 2)
			expect(waitFor(function()
				return R:Stats().predicted == 0
			end, 3)):toBe(true)
		end)
	end)
end
