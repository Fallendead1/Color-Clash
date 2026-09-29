-- Runs last in the engine suite: the whole session must have produced no divergence or handler faults.
-- PaintHashMismatch (client frozen state != server), RemoteHandlerError (uncaught error in a remote handler) and
-- ProjectileCapReached (legal play hit the safety cap) must all be zero.
return function(t)
	local it, expect = t.it, t.expect
	local S = t.services
	it("no paint divergence, handler errors or projectile-cap overloads during the engine run", function()
		local bad = {}
		for name, n in S.DiagnosticsService.counters() do
			if (string.find(name, "PaintHashMismatch", 1, true) or string.find(name, "RemoteHandlerError", 1, true) or string.find(name, "ProjectileCapReached", 1, true)) and n > 0 then
				table.insert(bad, name .. "=" .. n)
			end
		end
		table.sort(bad)
		expect(table.concat(bad, ",")):toBe("")
	end)
end
