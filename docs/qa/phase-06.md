# Phase 06 — Core tactical tools

```text
Phase ID / title: 06 — Core tactical tools
Status: PASS_CODE (fixture, solo practice + real client). Teammate Team Launch and target-death cancel: NOT RUN (need
  two same-team clients; scheduled for the next multi-client session).
Project / place / branch: C:\Color-Clash / Color Clash (130101797221207) / main
Implementation completed:
  server: AbilityService (new; Bootstrap ORDER now 11 services)
    - Splash Can: 0.15 s preparation, cost at release, 1.2 s fuse, one active per owner, 0.75 s interval, 70->25
      falloff with line of sight, paint 8, sticks at first world/enemy-screen impact, base boundary stops it
    - Paint Screen: floor/base/geometry validation before cost, 12x8, 250 HP, 5 s, one per owner, 1 s interval,
      replacement, non-colliding, blocks enemy projectiles/beams/blasts/paint visibility, destroyed part leaves nothing
    - Color Burst: meter spent at activation, 0.25 s preparation (death cancels, no refund), 0.7 s fuse, paint 18,
      80/40 with line of sight, ultimate paint grants no meter
    - Paintstorm: beacon needs an upward floor (else fizzle cue), radius 18, 6 s, 0.5 s ticks, top-down rain rays
      (roofs block paint and damage), one tick per target per interval across overlapping storms, no meter
    - Team Launch: Launch remote takes only { target = teammate UserId | "Base" }; eligibility (alive, own paint for a
      teammate / non-enemy floor for Base, not attacking, no damage for 1.5 s); 1.0 s channel cancelled by damage,
      >1 stud movement or an attack; server landing search; frozen landing; 1.0 s invulnerable transit with enemy
      marker cue; in-transit fallback to a clear friendly spawn; 0.25 s landing protection; 8 s cooldown on departure
    - Round end / reset clears throwables, storms, screens, preparations and launches; fuses and storms use the match
      clock (VacancyPause-safe)
  combat core: action gate (transit blocks everything, a preparation locks weapon firing, an attack cancels a
    channel), enemy-screen hits consume shots and damage the screen (hitScreen), screenDamage carried by projectiles
  shared: Paint/TacticalMap (projection of the SAME grid, stacked-layer detector, launch target selection)
  client: TacticalMapController (Map panel, raster, teammate markers, target list, confirm, launch status/reasons),
    WeaponController Gadget/Ultimate input, EffectsController cues (throw arc + blast-radius warning, storm zone,
    fizzle, launch landing marker)
Tests executed:
  engine:Tactical 18/18 (fixture, solo; real validation path) — ABIL-01..10, MAP-01, SEC-02..04 (see QA_MATRIX)
  client:ManualMapLaunch (real client, Launch remote): map opens in Menu context; projection totals == client grid;
    Base is the only solo target; channel -> transit -> arrived in 2.10 s inside own base; cooldown reason shown;
    map closes back to Gameplay
  client:ManualWeaponClient "gadget" (real client, team B): Gadget press -> one send, replicated screen placed;
    Ultimate with meter < 100 -> not sent
  Regression: engine 88/88 (9 specs, fresh session); client all 8/8; unit 61/61 (Lune + Studio); verify.ps1 PASSED
Defects found and fixed:
  - CombatService.spawnProjectile copied spec fields explicitly, so screenDamage was dropped -> Popshot hits on an
    enemy screen were consumed but did 0 damage (caught by ABIL-03) -> field carried
  - Test isolation: solo team is random -> spec re-forms until team A (geometry is laid out for A); a failed launch
    test leaked a channel into the next test -> standAt cancels any launch; Boot's fresh-session check moved first
    (spec renamed Tactical); counters baselined
Unrun / blocked:
  - ABIL-07 teammate launch, ABIL-09 target death before departure, COMBAT-05/06/07, FLOW-11: need a multi-client
    session with two players on the same team
  - Human readability of the wireframe warnings (not production VFX; Codex Phase 09)
```

Decisions: D-011 (what damages a screen; how a launch transit is represented).
