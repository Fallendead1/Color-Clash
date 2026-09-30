-- DATA-01 on the REAL DataStore path (requires Studio API access; scope "studio", never live data). Loads the
-- player's profile, changes two settings and the kit, writes through UpdateAsync, reloads from the store and checks
-- the values survived, then restores the original values. Run: CCTestRequest = "perf:PrefsRealSave".
-- Output: Workspace attribute CCPrefsReal (summary).
return function(t)
	local it, expect = t.it, t.expect
	local S = t.services
	local SS = S.SettingsService
	local Players = game:GetService("Players")

	it("saves and reloads through the real DataStore", function()
		local p = Players:GetPlayers()[1]
		S.DevGate.set("PrefsBackend", nil)
		expect(SS.backendName()):toBe("datastore")
		SS.devReload(p)
		local st = SS.state(p)
		expect(st.load == "new" or st.load == "ok" or st.load == "repaired"):toBe(true)
		local orig = { sensitivity = st.profile.settings.sensitivity, invertY = st.profile.settings.invertY, loadout = st.profile.loadout }
		local newSens = if orig.sensitivity == 1.7 then 1.3 else 1.7
		SS.patch(p, { sensitivity = newSens, invertY = not orig.invertY })
		SS.setLoadout(p, if orig.loadout == "popshot" then "linecaster" else "popshot")
		expect(SS.devFlush(p)):toBe(true)
		expect(SS.state(p).save):toBe("saved")
		SS.devReload(p) -- a fresh read from the store ("rejoin")
		local after = SS.state(p)
		local summary = string.format("load=%s -> %s; sensitivity %s -> %s; invertY %s -> %s; kit %s -> %s", st.load, after.load, tostring(orig.sensitivity), tostring(after.profile.settings.sensitivity), tostring(orig.invertY), tostring(after.profile.settings.invertY), tostring(orig.loadout), tostring(after.profile.loadout))
		workspace:SetAttribute("CCPrefsReal", summary)
		expect(after.load):toBe("ok")
		expect(after.profile.settings.sensitivity):toBe(newSens)
		expect(after.profile.settings.invertY):toBe(not orig.invertY)
		expect(after.profile.loadout):toBe(if orig.loadout == "popshot" then "linecaster" else "popshot")
		-- restore
		SS.patch(p, { sensitivity = orig.sensitivity, invertY = orig.invertY })
		SS.setLoadout(p, orig.loadout)
		expect(SS.devFlush(p)):toBe(true)
		SS.devReload(p)
		expect(SS.state(p).profile.settings.sensitivity):toBe(orig.sensitivity)
	end)
end
