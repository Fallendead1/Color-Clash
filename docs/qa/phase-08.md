# Phase 08 — Harden, profile and prepare the Codex handoff

```text
Phase ID / title: 08 — Harden, profile and prepare the Codex handoff
Status: PASS_CODE -> CODE_READY_FOR_CODEX (fixture/contract-fixture evidence, desktop Studio, 1 real client).
  Blocked: 8-client stress (memory), physical devices, real DataStore save path (Studio API access off).
Project / place / branch: C:\Color-Clash / Color Clash (130101797221207) / main
Implementation completed:
  network: dev-only simulation in NetService (one-way latency, jitter, unreliable loss; reliable ordering kept);
    application RTT (Ping/Pong over the real remotes) drives the connection-delay notice
  telemetry: client PerfSample (frame p50/p95, hitches, memory; unknown = nil; labelled client-reported);
    server frame-time ring; milestones in seconds since SessionStarted; shotSummary with explicit categories and
    denominators; Hit.* outcome counters; SessionEnded with known exit fact vs labelled perf correlation;
    TeamService.kick records an explicit reason (no latency-based kicks exist)
  security: SEC-10 client-surface scanner in verify.ps1; charger rewind test override (DevGate)
  presentation hooks for Codex: server WeaponModels (contract validator + presentation-only binding, one-time
    reports), authored AthleteDescription with forced normalized scales, client PresentationController
    (animations/sounds/effects by key, bounded 64 transient objects, optional assets); UI adapter no longer depends
    on hierarchy names (Touch.Root, Results.CoverageFillA/B keys)
  docs: MAP_CONTRACT, UI_CONTRACT, ASSET_CONTRACT (with content inventory), CODEX_HANDOFF
Tests executed:
  engine (fresh session): see "Regression" below; new Hardening 9/9, Presentation 2/2
  real client + dev net simulation: NET-05 (RTT 0.115/0.198/0.35 s), NET-06 (0.67-0.70 s): 15/15 accepted each,
    0 rejects, 0 duplicates, client hash == server hash, notice shown and rate-limited, no kick
  real client adversarial (ManualAdversarial + harness:NetAudit): 272 malformed sends + ~900 flood requests,
    0 handler errors, rate limits engaged, max server frame 23.5 ms, paint hash unchanged
  perf:RoundSoak (PERF-03, contract fixtures): 20/20 rounds, flat memory and instances, frame p95 18 ms
  client ManualCombatLoad (PERF-05): no stuck input, heap stable
  client Presentation: cue dispatch, missing-asset skip, 64-object bound, cleanup
  verify.ps1 PASSED (syntax, Lune unit, selene, both builds, prod excludes dev, client surface scan)
Defects found and fixed:
  - NetService used the simulated-order table before its declaration (selene caught it)
  - UI adapter still depended on two hierarchy names (TouchControls, Results bar A/B) -> keyed
  - a solo-team assumption and a cumulative counter in tests (fixed in Phase 06 carry-over)
Unrun / blocked (honest list):
  - PERF-02 eight-client stress; NET-04/08 at 8 clients: BLOCKED (15.9 GB RAM, ~0.8 GB free)
  - PERF-04, UI-02, UI-05 on physical devices: BLOCKED (no device, no production content)
  - DATA-01 on the published DataStore path: BLOCKED (Studio API access disabled for this place)
  - Multi-client: COMBAT-05/07, COMBAT-06 assists with real attackers, FLOW-11 replacement-in-grace, FLOW-13
    reconnect mid-state, ABIL-07/09 teammate launch and target death, NET-07 moving-player rewind: NOT RUN
  - Real internet links (only simulated latency), window resize under load: NOT RUN
  - Everything requiring production maps, models, animations, UI, VFX, audio: Codex Phase 09, then Phase 10
```

## Baselines (desktop Studio, this machine; fixture content)

| Measure | Value | Source |
|---|---|---|
| Server frame time during Live (Studio, 1 client) | p50 16.9 ms, p95 18 ms, live max < 24 ms | harness:NetAudit, perf:RoundSoak |
| Map-load hitch (contract fixtures, ~31-38k cells) | 190-207 ms per load, excluded window | perf:RoundSoak |
| Server send rate during rounds | ~3.3 KB/s (1 client) | perf:RoundSoak |
| Memory across 20 rounds | flat (±0.2 MB after warm-up); Workspace instances constant 287 | perf:RoundSoak |
| App RTT added by simulation | +65-70 ms over configured RTT (heartbeat alignment) | ManualNetLatency |

The earlier paint-renderer and paint-network budgets are recorded in `qa/phase-02.md`, and the weapon matrix in
`qa/phase-05.md`.

## Reproduce

1. `powershell -ExecutionPolicy Bypass -File tools\verify.ps1`
2. In Studio Play (solo), in a fresh session, set `ServerScriptService` attribute `CCTestRequest = "engine"`, then
   `"perf:RoundSoak"`. On the client, set `LocalPlayer` attribute `CCClientTestRequest = "all"`.
3. Network and security steps:
   1. Run the server harness steps `MatchSetup` → `Kit` (`CCKit = "sprayline"`) → `Place` (`CCPlaceTarget =
      "0,100,-4,1,0"`) → `NetSim` (`CCNetSim = "latency,jitter,loss"`) → `NetAudit`.
   2. Run the client spec `ManualNetLatency`, then `NetAudit` again.
   3. Run the client spec `ManualAdversarial`, then `NetAudit` again.
