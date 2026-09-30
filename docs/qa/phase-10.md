# Phase 10 — Claude verifies the actual game (in progress)

```text
Phase ID / title: 10 — Integration verification against Codex content (first pass)
Status: IN PROGRESS — not CORE_PVP_VERIFIED. Remaining gates are listed at the end.
Project / place / branch: C:\Color-Clash / Color Clash (130101797221207) / main
Content under test: Codex content commit b387aed (maps v3, ContractVersion 1)
Implementation completed (code side):
  - Team Launch landing never lands on a living character (found by the 3-client test)
  - presentation dispatch for the extra authored keys (Impact, ChargeReady, ShieldHit, LaunchTransit,
    LaunchLanding, ResultsCue, UI_Confirm/UI_Back, GlideEntry/Exit, Roller/BrushSecondary); LaunchMarker cue
    carries the departure point
  - soak memory sampled after a collection nudge; soaks use the in-memory prefs backend (never the tester's
    real saved profile); DevGate respawn override for lifecycle tests
Tests executed:
  3 real clients on Switchyard v3 (multi:ThreeClient): COMBAT-05, COMBAT-06, COMBAT-07, ABIL-07 (teammate),
    ABIL-09 (target death), NET-04 (3 clients, frozen hashes equal), FLOW-11 (team leaves, replacement) — all PASS
  engine 112/112 (14 specs, fresh session, production content present)
  client 15/15 on the production UI (CCUIWireframe=false, CCUIErrors=0)
  perf:ProductionSoak 10 rounds with collection cycles: PASS (total 2218 -> 2224 MB, Lua heap flat 15 MB)
  garbage probe: all 12 replaced characters collectable on server and client after collection
  clean tracked build: production.rbxlx contains both maps (with manifest attributes), ColorClashUI and
    ColorClashAssets; Rojo reconnect replaced a stale Studio copy of EffectsController with the tracked file
  DATA-01 on the real DataStore (Studio scope): PASS
Defects found and fixed:
  - teammate launch landed on top of the teammate
  - EffectsController edited in Studio had detached from Rojo (stale copy ran) -> reconnect; tracked file wins
  - a soak wrote kit choices into the tester's real saved profile, which later broke a fixture test -> soaks use
    the memory backend; the Combat slice pins its kit
Findings passed to Codex (docs/CODEX_FOLLOWUP.md): combat sightlines 151/171 studs (target ~90); AnimationSources
  ship in the runtime tree; per-character connection list in the UI presentation script; Canopy flank parity
Open observations: ~0.4 MB/round creep in engine Animation/BaseParts tags over 10 rounds (needs a longer run to
  see whether it plateaus); Codex's +66 MB figure was uncollected garbage in the Studio process total
Remaining gates (not passed):
  - Codex follow-up items 1-4, then re-verification (routes, sightlines, soak on final maps)
  - published animation/audio IDs (project owner) and CONTENT-04 playback of every key
  - eight-client stress (memory), physical devices, published private-server smoke test, human playtests
```

## Second pass — Codex follow-up content v4 (commit 905f295)

```text
Scope check: only src/server/Dev/engine/ProductionContent.spec.luau changed under src; protected gameplay paths
  untouched. Studio content matched the tracked v4 exports (MapVersion 4, counts 26,996 / 28,434, no
  AnimationSources in the runtime tree, one ColorClashUI, current EffectsController).
Tests (Claude, fresh sessions):
  verify.ps1 PASS; engine 113/113 (14 specs); client 15/15 on the production UI (wireframe=false, 0 UI errors);
  perf:ProductionSoak 20/20 rounds PASS: 0 problems, 0 handler errors, 0 hash mismatches, post-warm-up memory
  2261.4 -> 2276.9 MB (+0.7 %, within the 5 % target) with a steady ~1 MB/round creep in the Studio process total
  (open observation), instances 320/325
Independent sightline scan (tools/content/sightline_scan_claude.luau; 2-stud grid, 64 directions, eye 4.5):
  GROUND: Switchyard 96.7 studs (6 lines > 95), Canopy Courts 94.1 (0 > 95) -> confirms Codex's ground result
  ELEVATED (upper ramps, terraces): lines up to ~197 (Switchyard) and ~205 (Canopy) studs over the full-height
    cover; 1,258 / 1,355 sampled lines > 95. Codex's scan measured ground level only.
  Base visibility: from mid-map floor there are clear lines into each enemy base's exit area at ~89-99 studs.
    Shots cannot cross a base boundary and the loader's spawn-to-spawn sightline check passes, so this is a
    design note, not a gameplay defect.
Decision needed (owner): GDD 09.1 targets about 90 studs for combat sightlines and asks for long-range positions
  without direct protected-base sightlines. Elevated lines of ~200 studs exceed the target (no weapon reaches beyond
  120 studs). Either accept elevated long views as the intended long-range positions, or ask Codex to add parapets /
  backstops on the ramp tops and terraces.
```
