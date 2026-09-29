-- PAINT-08 / PERF-01 client side. Start this spec FIRST, then run the server perf spec "PaintStress".
-- 1. Baseline: 3 s of frame times before any stress paint exists.
-- 2. Waits for the worst-case (alternating) delta, measures time to fully render, frame times while rendering and
--    in steady state, renderer per-frame work, part count and memory; then checks sampled cells for correctness.
-- Environment caveat: Studio on the development desktop with server + client + editor in one process.
-- Not evidence for mobile hardware.
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local C = t.services
	local Surface = t.require("Paint/Surface")
	local Stats = game:GetService("Stats")
	local RunService = game:GetService("RunService")
	local player = game.Players.LocalPlayer

	local function waitFor(pred, timeout)
		local t0 = os.clock()
		while not pred() do
			if os.clock() - t0 > timeout then
				return false
			end
			task.wait()
		end
		return true
	end

	local function p95(list)
		local s = table.clone(list)
		table.sort(s)
		return s[math.max(1, math.ceil(#s * 0.95))] or 0
	end

	local function sample(seconds)
		local frames = {}
		local conn = RunService.RenderStepped:Connect(function(dt)
			table.insert(frames, dt * 1000)
		end)
		task.wait(seconds)
		conn:Disconnect()
		return frames
	end

	local function r2(x)
		return math.floor(x * 100) / 100
	end

	describe("Native renderer at map budget, alternating worst case", function()
		local P = C.PaintClient
		local R = P.renderer()

		it("baseline frames before stress paint", function()
			workspace:SetAttribute("CCTestServerPaintHash", nil)
			local frames = sample(3)
			player:SetAttribute("CCBaselineFrameP95", r2(p95(frames)))
			player:SetAttribute("CCBaselineParts", R:Stats().activeParts)
			player:SetAttribute("CCBaselineMemoryMb", math.floor(Stats:GetTotalMemoryUsageMb()))
			R:ResetStats() -- renderer work samples cover everything the server sends from here on
			player:SetAttribute("CCStressClientReady", true)
			expect(#frames):toBeGreaterThan(30)
		end)

		it("renders the worst case and records costs", function()
			-- wait for the server's alternating delta to be applied to the mirror
			expect(waitFor(function()
				local target = workspace:GetAttribute("CCTestServerPaintHash")
				return target ~= nil and P.grid() ~= nil and P.grid():hash() == target
			end, 90)):toBe(true)
			local t0 = os.clock()
			local frames = {}
			local conn = RunService.RenderStepped:Connect(function(dt)
				table.insert(frames, dt * 1000)
			end)
			expect(waitFor(function()
				return R:Stats().queued == 0
			end, 120)):toBe(true)
			conn:Disconnect()
			local renderSeconds = os.clock() - t0
			local steady = sample(3)
			local st = R:Stats()
			local worst = 0
			for _, f in frames do
				worst = math.max(worst, f)
			end
			player:SetAttribute("CCStressRenderSeconds", r2(renderSeconds))
			player:SetAttribute("CCStressRenderFrames", #frames)
			player:SetAttribute("CCStressRenderFrameP95", r2(p95(frames)))
			player:SetAttribute("CCStressRenderFrameMax", r2(worst))
			player:SetAttribute("CCStressRendererMsMax", r2(st.frameMsMax))
			player:SetAttribute("CCStressRendererP95", r2(R:WorkP95()))
			player:SetAttribute("CCStressParts", st.activeParts)
			player:SetAttribute("CCStressSteadyP95", r2(p95(steady)))
			player:SetAttribute("CCStressMemoryMb", math.floor(Stats:GetTotalMemoryUsageMb()))
			expect(st.activeParts):toBeGreaterThan(0)
		end)

		it("sampled cells render the authoritative owner (every 7th legal cell)", function()
			local g = P.grid()
			local checked, mismatches, n = 0, 0, 0
			for pi, patch in g.patches do
				local def = patch.def
				for j = 0, def.SizeV - 1 do
					for i = 0, def.SizeU - 1 do
						n += 1
						local k = j * def.SizeU + i
						if n % 7 == 0 and Surface.isLegal(def, k) then
							checked += 1
							if R:RenderedOwnerAt(pi, i, j) ~= buffer.readu8(patch.owner, k) then
								mismatches += 1
							end
						end
					end
				end
			end
			player:SetAttribute("CCStressChecked", checked)
			expect(checked):toBeGreaterThan(9000)
			expect(mismatches):toBe(0)
		end)
	end)
end
