# Phase 05 — Complete all seven main weapons

```text
Phase ID / title: 05 — Complete all seven main weapons
Status: PASS_CODE (fixture, solo practice + real client). Human playtest readability/fun: NOT RUN (no players).
Project / place / branch: C:\Color-Clash / Color Clash (130101797221207) / main
Implementation completed:
  server: CombatService core (shared validation, projectiles with onImpact/onExpire, per-attack dedupe, line of sight
    incl. enemy screens and base boundaries, pose history for bounded rewind, paint helpers, family registry) and
    families Projectile (Sprayline, Twin Jets + dash), Roller (windup flick fan, roll strip + moving contact damage
    with per-target cooldown), Charger (server-measured charge, 150 ms-capped rewind, current walls block, beam trace
    paint, held-aim warning relay), Lobber (three lobes, one attack id, 55 cap), Brush (sweep arc, push trail,
    mutual exclusion), Blaster (direct XOR splash, burst on impact or range end); Trail helper (swept strip, time-based
    drain, stationary contact once, teleport-step skip)
  client: WeaponController for every family (cadence-paced sends, twin muzzles, physics dash that walls stop,
    roll/push start-stop, charge start/release/cancel with forced-release cancel, focus FOV, held aim), effects
    (lobes, beams, aim warnings, bursts); InputController forced-release reasons
  dev: LoadoutService.devSetKit (DevGate-guarded); MapService FixtureMap=stress_lab (dev); harness Kit step
Tests executed:
  engine:Weapons 14/14 (fixture, solo; real validation path):
    WEAPON-02 Twin Jets 82,64,46,28,10,0 (6 hits, one event per paid shot); dash cost 8, 2.5 s cooldown, refused
      while gliding
    WEAPON-03 flick 65 close / 40 far / 0 behind, cost 14; roll: contact 60 once while moving, ~24 paint for ~2 s of
      movement, strip > 150 cells
    MOVE-06 rolling in place: no refill, no drain; MOVE-08/SEC-09 40-stud teleport step: no paint streak (skipped)
    WEAPON-04 early release free; forged duration key rejected; glide cancels charge; full charge eliminates (110);
      partial 0.5 s charge ~62.6 damage (server-measured)
    WEAPON-05 three lobes on one victim: exactly 55, one health change
    WEAPON-06 32 per sweep; 20-sweep spam -> <= 2 accepted; sweep ends push
    WEAPON-07 direct 70 exactly (one change); neighbour 3.5 studs away: splash only
    WEAPON-08 every class really fired (accepted counters asserted) through thin cover -> 0 damage
    COMBAT-11 / UI-03 selection locked in match, unknown kit rejected, free again after the match
  client:ManualWeaponClient (real client, semantic input): Twin Jets dash toward a wall stops at it (min root x
    -14.13, wall face -15); Linecaster panel entry and glide mid-charge -> 2 cancels, 0 releases
  perf:WeaponMatrix (stress_lab, server-driven; see table)
  Regression: engine 70/70 (8 specs incl. ZHealth: 0 PaintHashMismatch / 0 handler errors / 0 cap overloads);
    unit 58/58 (Lune + Studio); verify.ps1 PASSED
Defects found and fixed:
  - PaintService.freeze encoded without flushing -> clients could keep stale versions of the last chunks
    (PaintHashMismatch caught by the suite) -> flush + broadcast before freezing; regression test added
  - balance matrix aimed lobs straight at the target (artefact) -> ballistic aim solver
Unrun / blocked:
  - Human playtest clips/observations for readability, frustration, counterplay (GDD 07.5): NOT RUN (no players)
  - Real-client roll/push/lobber input paths: exercised server-side; client paths exercised in code only
```

## WEAPON-09 balance matrix (desktop Studio, stress_lab fixture, server-driven inputs)

| Weapon | Coverage 10 s (cells, unlimited paint) | Seconds to empty | TTK 5 / 15 / 30 studs (s) |
|---|---|---|---|
| Sprayline | 651 | 7.33 | 0.66 / 0.66 / 0.79 |
| Twin Jets | 444 | 7.59 | 0.60 / 0.59 / 0.69 |
| Lane Roller (roll) | 1312 | 8.33 | 1.63 / 2.44 / out of reach (22) |
| Linecaster | 585 | 7.58 | 1.51 / 1.51 / 1.51 |
| Splash Pot (solved lob aim) | 894 | 5.33 | 1.33 / 1.33 / 1.33 |
| Street Sweeper (push) | 824 | 9.96 | 0.93 / out of reach (12) / out of reach |
| Popshot | 603 | 8.16 | 1.63 / 1.63 / 1.63 |

Findings (numerical, not a fun/balance verdict):
- No kit dominates every scenario. The Roller covers the most floor but cannot duel beyond 22 studs. Twin Jets kill
  fastest but paint least. The Linecaster is the only kit with a consistent 30-stud kill. The Splash Pot drains
  fastest (5.3 s).
- No tuning change is applied now. Candidate experiments, pending human playtests: Splash Pot tank drain (-10% cost),
  Twin Jets coverage (+0.2 impact radius). Log any change in DECISIONS.md with before/after matrices.
- Sprayline TTK 0.66 s includes ~0.1 s flight at 15 studs; the configured 0.48 s cadence window is verified exactly in
  engine:Combat.
