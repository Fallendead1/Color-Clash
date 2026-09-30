-- Phase 08 engine hardening on the paint_lab FIXTURE (solo practice): SEC-05/06/07 malformed, non-finite, impossible,
-- replayed and stale requests through the real handlers; SEC-10 remote inventory; NET-07 rewind bound; OBS-01/02/03
-- telemetry semantics. The real-remote adversarial burst runs from a client (ManualAdversarial + harness:NetAudit).
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local S = t.services
	local H = require(S.Dev.MatchHarness)
	local Net = require(game.ReplicatedStorage.Shared.Protocol.Net)
	local Weapons = require(game.ReplicatedStorage.Shared.Config.Weapons)
	local Workspace = game:GetService("Workspace")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local D = S.DiagnosticsService

	describe("Hardening (fixture, solo practice)", function()
		local p, seq = nil, 900000
		local function life()
			return S.CharacterService.life(p)
		end
		local function muzzle()
			return life().root.Position + Vector3.new(0, 1.1, 0)
		end
		local function msg(over)
			seq += 1
			local m = { m = S.RoundService.matchId(), l = life().lifeId, s = seq, a = "Fire", t = Workspace:GetServerTimeNow(), o = muzzle(), d = Vector3.new(1, -0.2, 0).Unit }
			for k, v in over or {} do
				m[k] = v
			end
			return m
		end
		local function snapshot()
			return { hp = life().health, paint = S.LoadoutService.paint(p), ult = S.LoadoutService.ultimate(p), hash = S.PaintService.grid():hash(), proj = S.CombatService.projectileCount() }
		end
		local function same(a, b)
			return a.hp == b.hp and math.abs(a.paint - b.paint) < 1e-6 and a.ult == b.ult and a.hash == b.hash and a.proj == b.proj
		end

		it("starts the match", function()
			p = H.startSolo(S)
			S.LoadoutService.devSetKit(p, "sprayline")
			H.place(S, p, Vector3.new(0, 100, -4), Vector3.new(1, 0, 0))
			task.wait(0.4)
			S.CharacterService.onOffensiveAction(p)
			S.LoadoutService.fillTank(p)
		end)

		it("SEC-05 unknown ids and malformed payloads are rejected cheaply without exceptions or mutation", function()
			local before = snapshot()
			local err0 = 0
			for name, n in D.counters() do
				if string.find(name, "RemoteHandlerError", 1, true) then
					err0 += n
				end
			end
			local huge = string.rep("x", 100000)
			local wide = {}
			for k = 1, 300 do
				wide["k" .. k] = k
			end
			local deep = {}
			local cur = deep
			for _ = 1, 40 do
				cur.n = {}
				cur = cur.n
			end
			local garbage = { false, 1, huge, wide, deep, true, { a = huge }, { a = "Fire", s = "1" }, Vector3.new(1, 2, 3), p }
			local failures = 0
			for k = 0, #garbage do
				local g = garbage[k] -- k = 0 gives nil
				for _, fn in {
					function()
						S.CombatService.handleAction(p, g)
					end,
					function()
						S.AbilityService.requestLaunch(p, g)
					end,
					function()
						S.SettingsService.patch(p, g)
					end,
					function()
						S.LoadoutService.select(p, g)
					end,
					function()
						S.CharacterService.onClientEvent(p, g)
					end,
				} do
					local ok = pcall(fn)
					if not ok then
						failures += 1
					end
				end
			end
			expect(failures):toBe(0)
			expect(S.LoadoutService.select(p, "golden_gun")):toBe(false)
			expect(S.LoadoutService.select(p, huge)):toBe(false)
			S.CombatService.handleAction(p, msg({ a = "GiveUltimate" }))
			S.CombatService.handleAction(p, msg({ a = huge }))
			S.CombatService.handleAction(p, msg({ extra = 1 }))
			task.wait(0.2)
			expect(same(before, snapshot())):toBe(true)
			local err1 = 0
			for name, n in D.counters() do
				if string.find(name, "RemoteHandlerError", 1, true) then
					err1 += n
				end
			end
			expect(err1):toBe(err0)
		end)

		it("SEC-06 NaN, infinity, non-unit aim and impossible origins are rejected before any work", function()
			local before = snapshot()
			local inv0 = D.getCount("ShotRejected.invalid")
			local org0 = D.getCount("ShotRejected.origin")
			local nan = 0 / 0
			S.CombatService.handleAction(p, msg({ d = Vector3.new(nan, 0, 0) }))
			S.CombatService.handleAction(p, msg({ o = Vector3.new(math.huge, 0, 0) }))
			S.CombatService.handleAction(p, msg({ d = Vector3.new(5, 0, 0) }))
			S.CombatService.handleAction(p, msg({ t = nan }))
			S.CombatService.handleAction(p, msg({ o = muzzle() + Vector3.new(0, 0, 40) }))
			S.CombatService.handleAction(p, msg({ o = Vector3.new(1e7, 0, 0) }))
			expect(D.getCount("ShotRejected.invalid")):toBe(inv0 + 5)
			expect(D.getCount("ShotRejected.origin")):toBe(org0 + 1)
			task.wait(0.2)
			expect(same(before, snapshot())):toBe(true)
			S.AbilityService.requestLaunch(p, { target = nan })
			S.AbilityService.requestLaunch(p, { target = math.huge })
			expect(S.AbilityService.launchState(p)):toBe(nil)
		end)

		it("SEC-07 duplicate, future and ancient sequences/timestamps: no replay, no extra shots", function()
			S.LoadoutService.fillTank(p)
			S.CombatService.state(p).nextReady = 0
			local acc0 = D.getCount("ShotAccepted.sprayline")
			local good = msg()
			S.CombatService.handleAction(p, good)
			expect(D.getCount("ShotAccepted.sprayline")):toBe(acc0 + 1)
			local seq0 = D.getCount("ShotRejected.sequence")
			local ts0 = D.getCount("ShotRejected.timestamp")
			S.CombatService.handleAction(p, good) -- exact replay
			local older = table.clone(good)
			older.s -= 5
			S.CombatService.handleAction(p, older)
			S.CombatService.handleAction(p, msg({ t = Workspace:GetServerTimeNow() + 2 }))
			S.CombatService.handleAction(p, msg({ t = Workspace:GetServerTimeNow() - 30 }))
			expect(D.getCount("ShotRejected.sequence")):toBe(seq0 + 2)
			expect(D.getCount("ShotRejected.timestamp")):toBe(ts0 + 2)
			expect(D.getCount("ShotAccepted.sprayline")):toBe(acc0 + 1)
		end)

		it("SEC-10 the client-visible remote surface is exactly the protocol (no RemoteFunctions, no dev remotes)", function()
			local folder = ReplicatedStorage:FindFirstChild("ColorClashNet")
			local names = {}
			for _, r in folder:GetChildren() do
				names[r.Name] = r.ClassName
			end
			for name, kind in Net.Remotes do
				expect(names[name]):toBe(if kind == "unreliable" then "UnreliableRemoteEvent" else "RemoteEvent")
				names[name] = nil
			end
			expect(next(names)):toBe(nil)
			local stray = {}
			for _, root in { ReplicatedStorage, Workspace, game:GetService("StarterPlayer"), game:GetService("StarterGui") } do
				for _, d in root:GetDescendants() do
					if d:IsA("RemoteFunction") or ((d:IsA("RemoteEvent") or d:IsA("UnreliableRemoteEvent")) and d.Parent ~= folder) then
						table.insert(stray, d:GetFullName())
					end
				end
			end
			expect(table.concat(stray, ",")):toBe("")
		end)

		it("NET-07 charger rewind is the capped one-way latency; static cover uses the current world", function()
			local rewindFor = require(S.Dev.Parent.Combat.Charger).rewindFor
			S.DevGate.set("RewindPingSeconds", 0.1)
			expect(rewindFor(p)):toNear(0.05, 1e-9)
			S.DevGate.set("RewindPingSeconds", 1.2)
			expect(rewindFor(p)):toNear(0.15, 1e-9) -- capped at 150 ms however slow the client is
			S.DevGate.set("RewindPingSeconds", nil)
			expect(rewindFor(p) <= 0.15):toBe(true)
			-- a full charge through thin cover at the maximum rewind still hits nothing
			S.LoadoutService.devSetKit(p, "linecaster")
			local tg = S.CombatService.targets()[1]
			tg.feet = Vector3.new(18.5, 100, -10)
			tg.part.CFrame = CFrame.new(tg.feet + Vector3.new(0, 2.75, 0)) * CFrame.Angles(0, 0, math.rad(90))
			tg.health, tg.alive = 100, true
			tg.part:SetAttribute("Health", 100)
			S.CombatService.setTargetTeam(1, "Any")
			H.place(S, p, Vector3.new(10, 100, -10), Vector3.new(1, 0, 0))
			task.wait(0.35)
			S.CharacterService.onOffensiveAction(p)
			S.LoadoutService.fillTank(p)
			S.DevGate.set("RewindPingSeconds", 1.2)
			local s = S.CombatService.state(p)
			s.nextReady, s.charging = 0, false
			S.CombatService.handleAction(p, msg({ a = "ChargeStart" }))
			task.wait(Weapons.Defs.linecaster.FullCharge + 0.03)
			S.CombatService.handleAction(p, msg({ a = "ChargeRelease", d = (tg.feet + Vector3.new(0, 2.75, 0) - muzzle()).Unit }))
			S.DevGate.set("RewindPingSeconds", nil)
			task.wait(0.2)
			expect(tg.health):toBe(100)
			local fired = D.recent("ChargeFired", 1)[1]
			expect(fired ~= nil and fired.data.rewind <= 150):toBe(true)
			S.LoadoutService.devSetKit(p, "sprayline")
		end)

		it("OBS-01 milestone timings use server time in seconds; unknown milestones stay nil", function()
			local uid = -4242 -- synthetic id: never a real player
			D.eventAt("SessionStarted", { player = uid }, 1000)
			D.eventAt("ClientReady", { player = uid }, 1002.5)
			D.eventAt("FirstMove", { player = uid }, 1010.25)
			local m = D.milestones(uid)
			expect(m.unit):toBe("s")
			expect(m.clientReady):toNear(2.5, 1e-9)
			expect(m.firstMove):toNear(10.25, 1e-9)
			expect(m.firstPaint):toBe(nil)
			expect(m.firstGlide):toBe(nil)
			expect(D.milestones(-4343).sessionStarted):toBe(nil)
		end)

		it("OBS-02 invalid requests, legal rejections and combat outcomes are separate categories", function()
			H.place(S, p, Vector3.new(0, 100, -4), Vector3.new(1, 0, 0))
			task.wait(0.35)
			S.CharacterService.onOffensiveAction(p)
			local tg = S.CombatService.targets()[1]
			tg.feet = Vector3.new(10, 100, -4)
			tg.part.CFrame = CFrame.new(tg.feet + Vector3.new(0, 2.75, 0)) * CFrame.Angles(0, 0, math.rad(90))
			tg.health, tg.alive = 100, true
			tg.part:SetAttribute("Health", 100)
			local a = D.shotSummary()
			local k = Weapons.Defs.sprayline
			local s = S.CombatService.state(p)
			-- invalid x2
			S.CombatService.handleAction(p, msg({ o = muzzle() + Vector3.new(0, 0, 40) }))
			S.CombatService.handleAction(p, msg({ d = Vector3.new(0 / 0, 0, 0) }))
			-- three shots at once: the cadence gate tolerates 60 ms of network bunching (two accepted hits), the third is
			-- a legal cadence rejection
			S.LoadoutService.fillTank(p)
			s.nextReady = 0
			for _ = 1, 3 do
				S.CombatService.handleAction(p, msg({ d = (tg.feet + Vector3.new(0, 2.75, 0) - muzzle()).Unit }))
			end
			task.wait(k.Cadence + 0.3)
			-- accepted, no victim (painting the floor) x1
			S.CombatService.handleAction(p, msg({ d = Vector3.new(-1, -0.4, 0).Unit }))
			task.wait(0.4)
			local b = D.shotSummary()
			Workspace:SetAttribute("CCObsDiag", string.format("inv %d legal %d acc %d hits %d noVictim %d blocked %d cad %d tgHealth %s", b.rejectedInvalid - a.rejectedInvalid, b.rejectedLegal - a.rejectedLegal, b.accepted - a.accepted, b.hits - a.hits, b.noVictim - a.noVictim, b.blocked - a.blocked, (b.byReason.cadence or 0) - (a.byReason.cadence or 0), tostring(tg.health)))
			expect(b.rejectedInvalid - a.rejectedInvalid):toBe(2)
			expect(b.rejectedLegal - a.rejectedLegal):toBe(1)
			expect(b.accepted - a.accepted):toBe(3)
			expect(b.hits - a.hits):toBe(2)
			expect(b.noVictim - a.noVictim):toBe(1)
			expect(b.attempts - a.attempts):toBe(6)
			expect((b.byReason.cadence or 0) - (a.byReason.cadence or 0)):toBe(1)
		end)

		it("OBS-03 the known exit fact is separate from performance correlation", function()
			S.CharacterService.onClientEvent(p, { k = "Perf", p50 = 40, p95 = 250, hitches = 12, mem = 900, win = 10 })
			local d1 = S.TeamService.sessionEndData(p)
			expect(d1.reason):toBe("left")
			expect(d1.causeInferred):toBe(false)
			expect(d1.lastClientFrameMsP95):toBe(250)
			S.TeamService.devMarkKick(p, "test")
			expect(S.TeamService.sessionEndData(p).reason):toBe("kicked:test")
			S.TeamService.devMarkKick(p, nil)
			-- unknown frame timing stays nil (never zero)
			S.CharacterService.onClientEvent(p, { k = "Perf", win = 10, mem = 900 })
			expect(S.CharacterService.lastPerf(p).frameMsP95):toBe(nil)
			expect(S.TeamService.sessionEndData(p).lastClientFrameMsP95):toBe(nil)
			-- invalid numbers are dropped, not clamped into fake data
			S.CharacterService.onClientEvent(p, { k = "Perf", p95 = -5, p50 = 0 / 0, win = 10 })
			expect(S.CharacterService.lastPerf(p).frameMsP95):toBe(nil)
			expect(S.CharacterService.lastPerf(p).frameMsP50):toBe(nil)
			H.stop(S)
		end)
	end)
end
