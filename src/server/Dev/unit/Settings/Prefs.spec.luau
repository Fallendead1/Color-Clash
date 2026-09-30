-- DATA-03 (pure): schema fallback, invalid preferences, merge policy for concurrent sessions, patch whitelist.
return function(t)
	local Prefs = t.require("Settings/Prefs")
	local describe, it, expect = t.describe, t.it, t.expect
	local function isKit(id)
		return id == "sprayline" or id == "popshot"
	end

	describe("Prefs", function()
		it("validates fields and snaps numbers to their step", function()
			expect(Prefs.validateField("sensitivity", 1.23)):toNear(1.2, 1e-9)
			expect(Prefs.validateField("sensitivity", 99)):toBe(3)
			expect(Prefs.validateField("sensitivity", 0 / 0)):toBe(nil)
			expect(Prefs.validateField("sensitivity", "1")):toBe(nil)
			expect(Prefs.validateField("invertY", 1)):toBe(nil)
			expect(Prefs.validateField("palette", "accessible")):toBe("accessible")
			expect(Prefs.validateField("palette", "neon")):toBe(nil)
			expect(Prefs.validateField("cash", 5)):toBe(nil)
		end)

		it("reads stored profiles: new, ok, repaired and newer schema", function()
			local p, s = Prefs.fromStored(nil, isKit, "sprayline")
			expect(s):toBe("new")
			expect(p.loadout):toBe("sprayline")
			p, s = Prefs.fromStored({ v = 1, loadout = "popshot", settings = { invertY = true } }, isKit, "sprayline")
			expect(s):toBe("ok")
			expect(p.loadout):toBe("popshot")
			expect(p.settings.invertY):toBe(true)
			expect(p.settings.sensitivity):toBe(1)
			p, s = Prefs.fromStored({ v = 1, loadout = "golden_gun", settings = { sensitivity = "fast" } }, isKit, "sprayline")
			expect(s):toBe("repaired")
			expect(p.loadout):toBe("sprayline")
			expect(p.settings.sensitivity):toBe(1)
			p, s = Prefs.fromStored({ v = 7, loadout = "popshot", settings = { reducedEffects = true, future = 1 } }, isKit, "sprayline")
			expect(s):toBe("newer")
			expect(p.settings.reducedEffects):toBe(true)
			p, s = Prefs.fromStored("garbage", isKit, "sprayline")
			expect(s):toBe("repaired")
		end)

		it("accepts only whitelisted patch keys", function()
			local acc, rej = Prefs.validatePatch({ sensitivity = 2, invertY = true, loadout = "popshot", cash = 99, ultimate = 100 }, isKit)
			expect(acc["settings.sensitivity"]):toBe(2)
			expect(acc["settings.invertY"]):toBe(true)
			expect(acc.loadout):toBe("popshot")
			expect(#rej):toBe(2)
			local acc2, rej2 = Prefs.validatePatch({ loadout = "golden_gun" }, isKit)
			expect(next(acc2)):toBe(nil)
			expect(rej2[1]):toBe("loadout")
			local _, rej3 = Prefs.validatePatch("x", isKit)
			expect(#rej3):toBe(1)
		end)

		it("merges only dirty fields into the latest stored copy and keeps unknown keys", function()
			-- session A loaded {sens 1}, then session B wrote invertY = true and a future key; A saves its sensitivity
			local latest = { v = 1, loadout = "popshot", settings = { invertY = true, sensitivity = 1, futureField = "x" }, extra = 5 }
			local out = Prefs.mergeForWrite(latest, { ["settings.sensitivity"] = 2 })
			expect(out.settings.sensitivity):toBe(2)
			expect(out.settings.invertY):toBe(true) -- B's change survives
			expect(out.settings.futureField):toBe("x")
			expect(out.extra):toBe(5)
			expect(out.loadout):toBe("popshot")
			expect(latest.settings.sensitivity):toBe(1) -- input not mutated
			expect(Prefs.mergeForWrite({ v = 9 }, { loadout = "sprayline" })):toBe(nil) -- never downgrade a newer profile
			local fresh = Prefs.mergeForWrite(nil, { loadout = "sprayline" })
			expect(fresh.v):toBe(1)
			expect(fresh.loadout):toBe("sprayline")
		end)

		it("cycles UI values", function()
			expect(Prefs.nextValue("invertY", false)):toBe(true)
			expect(Prefs.nextValue("palette", "accessible")):toBe("standard")
			expect(Prefs.nextValue("sfxVolume", 0.9)):toNear(1, 1e-9)
			expect(Prefs.nextValue("sfxVolume", 1)):toBe(0)
			expect(Prefs.format("sfxVolume", 0.8)):toBe("80%")
			expect(Prefs.format("glideMode", "auto")):toBe("Auto")
		end)
	end)
end
