# Phase 01 — Foundations, state and test harness

```text
Phase ID / title: 01 — Foundations, state and test harness
Status: PASS_CODE
Project / place / branch: C:\Color-Clash / Color Clash (130101797221207) / main
Commit / configuration / content contract version: see git log (Phase 01 commit); GameConfig v1; map contract v1; UI contract v1
Implementation completed:
  shared: GameConfig/Weapons/Abilities data; RoundMachine; Teams; PaintGrid/Surface/MapCodec; Ballistics;
          UltimateCredit; movement Rules; Validate; Net registry; Trove; UIContract; Strings
  server: Bootstrap (single start), DevGate, services Diagnostics/Net/Settings(in-memory)/Map/Team/Loadout/Paint/
          Combat(skeleton)/Character/Round; MapLoader (contract + masks + spawn/sightline validation)
  client: Bootstrap (single stack), InputController (semantic actions, contexts, focus release, glide toggle),
          UIController (UIKey adapter, contract validation, panel stack, double-submit guard), Wireframe (dev-only,
          watermarked), ScreensController (loading stages, staging, armory, controls, intro, HUD timer/coverage,
          results, notices), PaintClient (mirror)
  dev-only: paint_lab fixture, TestKit, server TestRunner, client ClientTestRunner, engine/client specs
  tools: tools/verify.ps1 (luau syntax, lune unit, selene, dev+prod builds, prod dev-instance check)
Tests executed (IDs + actual invocation):
  Pure unit (Lune): `lune run tests/run` -> 53 passed, 0 failed
  Pure unit (in Studio server VM): CCTestRequest="unit" -> 53 passed, 0 failed
  Engine (Studio Play, server VM): CCTestRequest="engine" -> Boot 6/6, RoundLifecycle 9/9
  Client (Studio Play, client VM): CCClientTestRequest="all" -> UIInput 8/8
  Local verification: powershell -File tools/verify.ps1 -> VERIFY PASSED
Environment / client count / device / network settings:
  Windows 11 Home 10.0.26200; Studio 0.740.19; solo Play (1 server + 1 client); no network emulation
Expected results / observed results:
  FLOW-01 engine: lone player waits in staging, matchId 0, not participating -> observed as expected
  Round lifecycle (fixture, solo practice dev override MinimumReady=1, AllowEmptyTeam, short timers):
    Waiting>Countdown>Loading>Intro>Live>Results>Reset>Intermission observed; fixture map loaded (paint_lab v5,
    isFixture=true); participant spawned inside own protected base with team collision group; the real client
    acknowledged the paint snapshot; server paint during Live raised team area; results frozen from raw counts
    (total 5264, a+b+neutral = total); paint after freeze rejected; reset cleared arena, grid, teams; ready persisted;
    player returned to staging
  UI-01: exactly one ColorClashUI root, contract valid (0 errors), wireframe flagged; contract validator detects a
    missing mandatory key and a duplicate actionable key
  Input: combat actions ignored outside Gameplay; opening a panel releases held actions and switches to Menu,
    closing restores; panel stack reveal; releaseAll; glide toggle mode
  SEC-01: DevGate copy without Dev sibling refuses set/get/devFolder; no remote name offers dev/test/cheat controls;
    production.rbxlx contains no Dev/TestKit/PaintLab/TestRunner instances
Evidence paths: console log lines "[ColorClash tests] ..." captured via Studio MCP; this file
Defects found and fixes:
  - MapLoader masks: raycasts cannot detect a part containing their origin -> overlap probe (D-008)
  - Fixture hidden floor under ramp rejected by validator -> added solid ramp fill (fixture v5)
  - Client syntax "Ambiguous syntax" from line-leading casts -> removed casts; added luau-lsp syntax gate to verify.ps1
  - verify.ps1 prod check matched source comments -> now matches instance names and sanity-checks the dev build
  - RoundLifecycle test race (observer Heartbeat order) -> test waits one tick
  - Rojo server died when the desktop app quit -> restarted `rojo serve` in background; user reconnected
Regressions rerun: full unit (Lune + Studio), engine, client suites after the fixes above
Unrun tests or external blockers:
  FLOW-02..05 with 4-8 real clients: NOT RUN (MCP offers solo Play only; covered at pure level)
  Gamepad-only and touch navigation: NOT RUN (Phase 07)
  One unexplained observation: on the very first Play of the session the character ended on the baseplate below
  staging; not reproduced in 3 later sessions; engine staging test passes. Likely stray Studio input; left open.
Next automatic step: Phase 02 — paint renderer, engine paint tests, occlusion with real geometry, sync tests
```
