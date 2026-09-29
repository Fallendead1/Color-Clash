# Phase 04 — First playable vertical slice (Sprayline)

```text
Phase ID / title: 04 — First playable vertical slice
Status: PASS_CODE with one BLOCKED gate item: the eight-client capacity/replication test (insufficient local memory).
Project / place / branch: C:\Color-Clash / Color Clash (130101797221207) / main
Implementation completed:
  server CombatService: cheapest-first validation (shape/types/finite -> match/life/sequence -> timestamp window ->
    muzzle plausibility -> climbing/base state -> family -> server cadence -> atomic paint cost), deterministic spread,
    swept projectiles (segment raycast vs world incl. enemy screens; segment-capsule vs enemy players/targets),
    trail drips (spacing 4, first visible floor below), impact paint with occlusion, base-boundary blocking both ways,
    per-attack-id damage dedupe, impacts only strictly before RoundEndTime, all entities cancelled at round end,
    practice targets (fixture), hit/shield confirmations to the attacker, disposable shot cues to others
  shared: Credit.resolve (final hitter, assists >= 20 in 5 s, environmental credit within 5 s); previewSphere
  client: WeaponController (cadence-paced sequenced shots, local paint gate, predicted trajectory + paint via exact
    footprint preview, denial -> immediate prediction removal, per-life sequences), EffectsController (pooled cosmetic
    projectiles <= 192, confirmed hit marker distinct from local cue, elimination burst), HUD elimination countdown
Tests executed:
  engine:Combat (solo, fixture targets; 3 consecutive runs, 13/13 each):
    COMBAT-01 enemy target -24, friendly target 0, cost exactly 1.8 | WEAPON-01 five hits 76,52,28,4,0 and
    first->fifth impact ~0.48 s | COMBAT-02 replayed sequence: one cost, one hit | COMBAT-03 thin cover blocks |
    COMBAT-04 empty tank: no projectile/cost, dry cue rate-limited | COMBAT-08 no firing inside own base; shots stop
    at the enemy base boundary | COMBAT-09 first attack removes the shield | floor shot paints | SEC-02..07 forged/
    malformed/stale/replayed payloads rejected with no cost or effect | SEC-07/08 40-shot same-frame burst -> <= 2
    accepted | FLOW-07 shot landing after the deadline has no effect; nothing left in flight after the round
  client:ManualFire (REAL mouse, solo): hit -> 10 shots, 0 denied, target 100 -> 0, 34 own cells painted, no
    prediction left | base -> 10/10 denied ("base"), no paint, no ghost prediction
  multi (Studio local server, REAL CLIENTS, 1v1 development override, fixture):
    2-client session: setup (1v1 live, both synced) PASS; server-validated duel P1 -> P2 eliminated, credit, respawn
      in own base with shield PASS
    3-client session: setup PASS; duel PASS; real-client duel: Player1's client sent 12 shots over the network
      (semantic Primary press inside the real client — OS mouse injection does not reach separate test windows),
      server accepted 12, real Player2 eliminated PASS; finish: both clients' frozen paint hash == server hash,
      results from raw counts (A 162 / B 84 / neutral 5018 of 5264 -> A), next round live automatically PASS;
      FLOW-10 (50 s left: stays in staging) + FLOW-09 (200 s left: backfilled to the smaller side, synced before
      combat, ultimate 0) with a real third client PASS; FLOW-12 kicking the lone team member -> VacancyPause with
      frozen match clock, NoContest after 15 s PASS
  Regression: engine suite, unit (Lune 58/58), client all, verify.ps1 PASSED
Defects found and fixes:
  - test races (Heartbeat observer order; stale target attribute) -> attribute-driven observation
  - denial-before-impact is correct at Studio latency -> PAINT-12 real-fire assertion corrected to "no ghost paint"
  - replay protection rejected a real client after server-injected shots used its sequence space (test artefact;
    confirms SEC-07) -> fresh life before the real duel
  - idle rule un-readied test players (correct behaviour) -> tests register activity
Unrun tests or external blockers:
  - Eight-client capacity/replication (Phase 04 gate): BLOCKED — measured 15.9 GB RAM, 0.8 GB free with 6 Studio
    processes (9.0 GB). Re-run when memory allows (other Studio places closed) or in the Phase 10 published test.
  - COMBAT-05 (two simultaneous eliminations), COMBAT-06 assist with two real attackers, COMBAT-07 (respawn while an
    old projectile is in flight): NOT RUN with real clients — scheduled for the next multi-client session (credit
    rules PASS at pure level)
  - FLOW-11 replacement within the vacancy grace with real clients: NOT RUN (pure PASS)
Next automatic step: Phase 05 — the other six weapons
```
