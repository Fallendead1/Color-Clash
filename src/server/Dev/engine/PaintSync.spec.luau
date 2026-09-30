-- Engine sync tests with the real Studio client in the loop (fixture). Client convergence is verified through the
-- client's hash acknowledgements (PaintSynced h, PaintHash h).
-- NET-01 late-join snapshot, NET-02 gap -> bounded resync, PAINT-10 stale delta after freeze, PAINT-11/NET-03 reset
-- while a snapshot is pending.
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local S = t.services
	local Players = game:GetService("Players")
	local MapCodec = require(game.ReplicatedStorage.Shared.Paint.MapCodec)

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

	describe("Paint sync with the real client (fixture)", function()
		local p = Players:GetPlayers()[1]
		local desc, grid

		it("NET-01 a client joining after paint converges to the authoritative state", function()
			S.DevGate.set("UseFixture", true)
			S.MapService.unload()
			local errors
			desc, errors = S.MapService.loadNext()
			expect(#errors):toBe(0)
			S.PaintService.setMap(desc, 9100)
			grid = S.PaintService.grid()
			-- paint BEFORE the client receives anything (late join)
			for k = 1, 30 do
				S.PaintService.paintSphere(Vector3.new(-30 + k * 2, 100, (k % 5) * 4 - 8), 3, 1 + k % 2, nil)
			end
			S.PaintService.flush()
			S.PaintService.syncPlayer(p)
			-- keep painting while the snapshot is in flight
			for k = 1, 10 do
				S.PaintService.paintSphere(Vector3.new(k * 3, 100, 20 - k), 2, 2, nil)
				S.PaintService.flush()
				task.wait()
			end
			expect(waitFor(function()
				return S.PaintService.isSynced(p)
			end, 10)):toBe(true)
			-- the ack hash reflects the snapshot plus whatever deltas preceded it; give deltas time, then force a resync
			task.wait(1.2)
			S.PaintService.syncPlayer(p)
			expect(waitFor(function()
				return S.PaintService.isSynced(p) and S.PaintService.ackHash(p) == grid:hash()
			end, 10)):toBe(true)
		end)

		it("NET-02 a sequence gap triggers a bounded resync that restores the exact state", function()
			local before = S.DiagnosticsService.getCount("event.PaintResync")
			S.PaintService.paintSphere(Vector3.new(0, 100, 0), 3, 1, nil)
			S.PaintService.flush()
			task.wait(0.3)
			grid.sequence += 3 -- the client will see seq jump by 4 -> gap
			S.PaintService.paintSphere(Vector3.new(4, 100, 4), 3, 2, nil)
			S.PaintService.flush()
			expect(waitFor(function()
				return S.DiagnosticsService.getCount("event.PaintResync") > before
			end, 5)):toBe(true)
			expect(waitFor(function()
				return S.PaintService.isSynced(p) and S.PaintService.ackHash(p) == grid:hash()
			end, 10)):toBe(true)
			-- resyncs are bounded: a second gap right away does not produce a second full snapshot
			grid.sequence += 3
			S.PaintService.paintSphere(Vector3.new(-4, 100, -4), 2, 1, nil)
			S.PaintService.flush()
			task.wait(0.5)
			expect(S.DiagnosticsService.getCount("event.PaintResync") - before):toBe(1)
		end)

		it("freeze includes paint made after the last 10 Hz delta (regression: frozen hash mismatch)", function()
			S.PaintService.setMap(desc, 9099)
			grid = S.PaintService.grid()
			S.PaintService.syncPlayer(p)
			expect(waitFor(function()
				return S.PaintService.isSynced(p)
			end, 8)):toBe(true)
			S.PaintService.paintSphere(Vector3.new(3, 100, 3), 4, 1, nil)
			S.PaintService.flush()
			task.wait(0.3)
			-- paint again and freeze before any flush can send it
			S.PaintService.paintSphere(Vector3.new(3, 100, 3), 2, 2, nil)
			local mismatches = S.DiagnosticsService.getCount("event.PaintHashMismatch")
			S.PaintService.freeze()
			local frozenHash = grid:hash()
			expect(waitFor(function()
				return S.PaintService.frozenAck(p) ~= nil
			end, 5)):toBe(true)
			expect(S.PaintService.frozenAck(p)):toBe(frozenHash)
			expect(S.DiagnosticsService.getCount("event.PaintHashMismatch")):toBe(mismatches)
			-- continue the rest of this spec on a fresh live match grid
			S.PaintService.setMap(desc, 9100)
			grid = S.PaintService.grid()
			S.PaintService.syncPlayer(p)
			expect(waitFor(function()
				return S.PaintService.isSynced(p)
			end, 8)):toBe(true)
		end)

		it("PAINT-10 deltas arriving after the freeze never change the frozen outcome", function()
			task.wait(1.2)
			local mismatches0 = S.DiagnosticsService.getCount("event.PaintHashMismatch")
			S.PaintService.freeze()
			local frozenHash = grid:hash()
			expect(waitFor(function()
				return S.PaintService.frozenAck(p) == frozenHash
			end, 5)):toBe(true)
			-- a forged/late delta for chunk 1 with a much newer version and different ownership
			local fake = buffer.create(6 + 72)
			buffer.writeu32(fake, 0, grid.sequence + 1)
			buffer.writeu16(fake, 4, 1)
			buffer.writeu32(fake, 6, 1)
			buffer.writeu32(fake, 10, grid.chunkVersion[1] + 100)
			buffer.fill(fake, 14, 0x55, 64)
			S.NetService.fireAll("Paint", "delta", 9100, desc.mapVersion, fake)
			task.wait(0.3)
			-- re-send the frozen state; the client re-reports its hash
			local full = grid:encodeChunks()
			S.NetService.fireAll("Paint", "freeze", 9100, desc.mapVersion, full, { a = grid.totals[1], b = grid.totals[2], total = grid.totalScoringArea })
			task.wait(0.5)
			expect(S.PaintService.frozenAck(p)):toBe(frozenHash)
			expect(S.DiagnosticsService.getCount("event.PaintHashMismatch")):toBe(mismatches0)
		end)

		it("PAINT-11 / NET-03 a reset while a snapshot is pending discards the old match completely", function()
			-- new match 9101: send the map and only the first snapshot part (not last)
			S.PaintService.setMap(desc, 9101)
			local g2 = S.PaintService.grid()
			S.PaintService.paintSphere(Vector3.new(0, 100, 10), 5, 1, nil)
			S.NetService.fireAll("Paint", "map", 9101, desc.mapVersion, MapCodec.encode(desc.defs), { mapId = desc.mapId, totalScoring = g2.totalScoringArea, chunkCount = g2.chunkCount })
			S.NetService.fireAll("Paint", "snap", 9101, desc.mapVersion, g2:encodeChunks({ 1, 2, 3 }), false)
			task.wait(0.2)
			expect(S.PaintService.isSynced(p)):toBe(false)
			-- reset mid-snapshot, then a fresh match 9102
			S.PaintService.clear()
			task.wait(0.2)
			S.PaintService.setMap(desc, 9102)
			local g3 = S.PaintService.grid()
			S.PaintService.paintSphere(Vector3.new(-10, 100, -10), 4, 2, nil)
			S.PaintService.flush()
			-- a late part of the old snapshot must be ignored (wrong match id)
			S.NetService.fireAll("Paint", "snap", 9101, desc.mapVersion, g2:encodeChunks({ 4, 5 }), true)
			S.PaintService.syncPlayer(p)
			expect(waitFor(function()
				return S.PaintService.isSynced(p) and S.PaintService.ackHash(p) == g3:hash()
			end, 10)):toBe(true)
		end)

		it("cleans up", function()
			S.PaintService.clear()
			S.MapService.unload()
			expect(S.PaintService.grid()):toBe(nil)
		end)
	end)
end
