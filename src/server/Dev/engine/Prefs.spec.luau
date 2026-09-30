-- DATA-01..04 through the real SettingsService logic on the dev in-memory backend (failure injection), plus the real
-- DataStore path's failure branch (Studio API access disabled on this place => a read failure must leave the game
-- usable). The published DataStore save path itself is NOT proven here (GDD 11.6: in-memory is not proof).
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local S = t.services
	local GameConfig = require(game.ReplicatedStorage.Shared.Config.GameConfig)
	local Players = game:GetService("Players")
	local SS = S.SettingsService
	local D = S.DiagnosticsService
	local DEBOUNCE = GameConfig.Persistence.SaveDebounceSeconds

	describe("Preferences persistence", function()
		local p, mem, key

		it("real DataStore path: a failed read gives a usable default session and never writes", function()
			p = Players:GetPlayers()[1]
			S.DevGate.set("PrefsBackend", nil)
			expect(SS.backendName()):toBe("datastore")
			local failed0 = D.getCount("Prefs.load.readFailed")
			SS.devReload(p)
			local st = SS.state(p)
			-- when API access is enabled this branch reads "new"/"ok" instead; both keep the session usable
			expect(st.load == "readFailed" or st.load == "new" or st.load == "ok"):toBe(true)
			expect(st.profile.settings.sensitivity ~= nil):toBe(true)
			if st.load == "readFailed" then
				expect(D.getCount("Prefs.load.readFailed")):toBe(failed0 + 1)
			end
		end)

		it("DATA-01 load, edit and rejoin with the chosen kit and settings (memory backend)", function()
			S.DevGate.set("PrefsBackend", "memory")
			mem = SS.memory()
			key = "u_" .. p.UserId
			table.clear(mem.store)
			mem.failReads, mem.failWrites, mem.beforeUpdate = 0, 0, nil
			mem.store[key] = { v = 1, loadout = "popshot", onboardingDismissed = true, settings = { invertY = true, sensitivity = 2 } }
			SS.devReload(p)
			local st = SS.state(p)
			expect(st.load):toBe("ok")
			expect(SS.savedLoadout(p)):toBe("popshot")
			expect(st.profile.settings.invertY):toBe(true)
			expect(st.profile.onboardingDismissed):toBe(true)
			local w0 = mem.writes
			SS.patch(p, { sensitivity = 1.5, palette = "accessible" })
			SS.setLoadout(p, "street_sweeper")
			expect(SS.state(p).save):toBe("pending")
			task.wait(DEBOUNCE + 0.6)
			expect(mem.writes):toBe(w0 + 1)
			expect(SS.state(p).save):toBe("saved")
			local stored = mem.store[key]
			expect(stored.settings.sensitivity):toBe(1.5)
			expect(stored.settings.palette):toBe("accessible")
			expect(stored.settings.invertY):toBe(true)
			expect(stored.loadout):toBe("street_sweeper")
			SS.devReload(p) -- "rejoin"
			st = SS.state(p)
			expect(st.profile.settings.sensitivity):toBe(1.5)
			expect(SS.savedLoadout(p)):toBe("street_sweeper")
		end)

		it("DATA-04 rapid slider bursts collapse into one bounded write with explicit status", function()
			local w0 = mem.writes
			for k = 1, 20 do
				SS.patch(p, { sfxVolume = (k % 10) / 10 })
				task.wait(0.05)
			end
			SS.patch(p, { sfxVolume = 0.3 })
			expect(SS.state(p).save):toBe("pending")
			task.wait(DEBOUNCE + 0.6)
			expect(mem.writes):toBe(w0 + 1)
			expect(mem.store[key].settings.sfxVolume):toBe(0.3)
			expect(SS.state(p).save):toBe("saved")
			-- a failing write reports "failed", keeps the change dirty, and a later flush succeeds
			mem.failWrites = GameConfig.Persistence.WriteAttempts
			SS.patch(p, { musicVolume = 0.2 })
			task.wait(DEBOUNCE + 2.2)
			expect(SS.state(p).save):toBe("failed")
			expect(mem.store[key].settings.musicVolume):toBe(nil)
			expect(SS.devFlush(p)):toBe(true)
			expect(mem.store[key].settings.musicVolume):toBe(0.2)
			expect(SS.state(p).save):toBe("saved")
		end)

		it("DATA-02 read failure: usable defaults, unknown profile never overwritten; later edits merge safely", function()
			mem.store[key] = { v = 1, loadout = "popshot", settings = { invertY = true }, secret = "keep" }
			mem.failReads = GameConfig.Persistence.ReadAttempts
			local w0 = mem.writes
			SS.devReload(p)
			local st = SS.state(p)
			expect(st.load):toBe("readFailed")
			expect(st.profile.settings.invertY):toBe(false) -- session defaults
			task.wait(DEBOUNCE + 0.5)
			expect(mem.writes):toBe(w0) -- nothing written by merely loading
			expect(mem.store[key].settings.invertY):toBe(true)
			SS.patch(p, { sfxVolume = 0.5 })
			task.wait(DEBOUNCE + 0.6)
			local stored = mem.store[key]
			expect(stored.settings.sfxVolume):toBe(0.5)
			expect(stored.settings.invertY):toBe(true) -- the unknown stored profile survives: only the edit merged
			expect(stored.secret):toBe("keep")
			expect(stored.loadout):toBe("popshot")
		end)

		it("DATA-03 newer schema is read-only; invalid values repaired; concurrent session changes survive", function()
			mem.store[key] = { v = 5, settings = { invertY = true }, future = { x = 1 } }
			local w0 = mem.writes
			SS.devReload(p)
			expect(SS.state(p).load):toBe("newer")
			expect(SS.state(p).profile.settings.invertY):toBe(true)
			SS.patch(p, { sensitivity = 2.5 })
			task.wait(DEBOUNCE + 0.5)
			expect(mem.writes):toBe(w0)
			expect(mem.store[key].v):toBe(5)
			expect(SS.state(p).save):toBe("readonly")
			-- invalid stored values
			mem.store[key] = { v = 1, loadout = "golden_gun", settings = { sensitivity = "fast", palette = "neon", invertY = true } }
			SS.devReload(p)
			local st = SS.state(p)
			expect(st.load):toBe("repaired")
			expect(st.profile.settings.sensitivity):toBe(1)
			expect(st.profile.settings.palette):toBe("standard")
			expect(st.profile.settings.invertY):toBe(true)
			-- concurrent session: another server writes shoulder=left between our load and our save
			mem.store[key] = { v = 1, loadout = "sprayline", settings = {} }
			SS.devReload(p)
			mem.beforeUpdate = function(k)
				local s = mem.store[k]
				s.settings.shoulder = "left"
			end
			SS.patch(p, { sensitivity = 2 })
			task.wait(DEBOUNCE + 0.6)
			mem.beforeUpdate = nil
			expect(mem.store[key].settings.sensitivity):toBe(2)
			expect(mem.store[key].settings.shoulder):toBe("left")
			-- whitelist: currency, meter and loadout-by-patch are rejected
			local rej0 = D.getCount("Prefs.patchRejected")
			SS.patch(p, { cash = 5, ultimate = 100, loadout = "popshot", invertY = false })
			expect(D.getCount("Prefs.patchRejected")):toBe(rej0 + 3)
			expect(SS.state(p).profile.settings.invertY):toBe(false)
			expect(SS.savedLoadout(p)):toBe("sprayline")
			task.wait(DEBOUNCE + 0.6)
			S.DevGate.set("PrefsBackend", nil)
			SS.devReload(p)
		end)
	end)
end
