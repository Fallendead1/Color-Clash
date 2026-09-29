# QA Matrix — Color Clash

Every GDD Section 18 test ID with its latest **actual** result. "Unit (pure)" means a Lune/Studio run of pure modules
with simulated inputs. It is **not** the full engine/multi-client test the ID ultimately requires. Those stay open until
run. Results legend: PASS, FAIL, BLOCKED (missing capability), NOT RUN.

Runners:
- Pure unit: `lune run tests/run` (repo root) — specs in `src/server/Dev/unit/**`.
- Full local verification: `powershell -ExecutionPolicy Bypass -File tools/verify.ps1`.
- Engine: Studio Play via the Studio MCP; the procedures are recorded per phase in `docs/qa/`.

## 18.1 Environment and round lifecycle

| ID | Level run | Result | Evidence / note |
|---|---|---|---|
| ENV-01 | Manual inspection | PASS | IMPLEMENTATION_STATUS §Project identity |
| ENV-02 | verify.ps1 | PASS | 2026-09-29 run: 53/53 unit, lint clean, dev+prod builds |
| ENV-03 | Studio Play canary | PASS | console `[Color Clash] Server started` / `Client started` |
| ENV-04 | Rojo sync vs Studio content | PASS | Workspace/Lighting/StarterPlayer/TextChatService contents unchanged after sync |
| ENV-05 | — | NOT RUN | no other game's Rojo server active to test against |
| FLOW-01 | Unit (pure) | PASS (pure) | RoundMachine.spec "one player waits"; engine test pending |
| FLOW-02 | Unit (pure) | PASS (pure) | 20 s countdown, 2v2 split |
| FLOW-03 | Unit (pure) | PASS (pure) | shortened once to ≤ 5 s |
| FLOW-04 | Unit (pure) | PASS (pure) | canceled once, no orphan deadline |
| FLOW-05 | Unit (pure) | PASS (pure) | Teams.form 2/4/5/6/7/8 × 20 seeds |
| FLOW-06 | Unit (pure) | PASS (pure) | raw-count winner; engine test pending |
| FLOW-07 | — | NOT RUN | needs Phase 04 combat |
| FLOW-08 | Unit (pure) | PASS (pure) | exact tie draw; 47.31% near-tie |
| FLOW-09 | Unit (pure) | PASS (pure) | backfill > 60 s rule; engine pending |
| FLOW-10 | Unit (pure) | PASS (pure) | = 60 s rejected |
| FLOW-11 | Unit (pure) | PASS (pure) | pause + deadline shift |
| FLOW-12 | Unit (pure) | PASS (pure) | NoContest |
| FLOW-13 | — | NOT RUN | |
| FLOW-14 | — | NOT RUN | |

## 18.2 Painting and movement

| ID | Level run | Result | Evidence / note |
|---|---|---|---|
| PAINT-01 | Unit (pure) | PASS (pure) | 10×10 exact region |
| PAINT-02 | Unit (pure) | PASS (pure) | no inflation |
| PAINT-03 | Unit (pure) | PASS (pure) | exact transfer |
| PAINT-04 | Unit (pure) | PASS (pure) | wall/base/mask; ceiling rejected by validator |
| PAINT-05 | Unit (pure) | PASS (pure) | rotated ramp grid, back face rejected |
| PAINT-06 | Unit (pure) | PASS (pure) | injected occlusion; engine raycast version pending |
| PAINT-07 | Unit (pure) | PASS (pure) | adjacent visible face |
| PAINT-08 | — | NOT RUN | renderer (Phase 02) |
| PAINT-09 | — | NOT RUN | |
| PAINT-10 | Unit (pure) | PASS (pure) | frozen grid ignores stamps |
| PAINT-11 | Unit (pure) | PASS (pure) | reset bumps versions |
| PAINT-12 | — | NOT RUN | |
| MOVE-01 | Unit (pure) | PASS (pure) | speed rules; engine pending |
| MOVE-02..04 | — | NOT RUN | |
| MOVE-05 | Unit (pure) | PASS (pure) | refill rates/delays |
| MOVE-06 | Unit (pure) | PASS (pure) | charge/roll/push no refill |
| MOVE-07..09 | — | NOT RUN | |
| CAM-01..03 | — | NOT RUN | |

## 18.3 Combat, weapons and abilities

| ID | Level run | Result | Evidence / note |
|---|---|---|---|
| COMBAT-01..11 | — | NOT RUN | Phase 04/05 |
| WEAPON-01 | Unit (pure) | PASS (pure) | 5-hit arithmetic, cadence 0.48 s; engine pending |
| WEAPON-02 | Unit (pure) | PASS (pure) | 6-hit arithmetic only |
| WEAPON-04 | Unit (pure) | PASS (pure) | charge damage formula + early release |
| WEAPON-07 | Unit (pure) | PASS (pure) | falloff formula |
| WEAPON-03,05,06,08,09 | — | NOT RUN | |
| ABIL-01 | Unit (pure) | PASS (pure) | Splash Can falloff formula only |
| ABIL-04 | Unit (pure) | PASS (pure) | /16, 6 per s, 5 s same-cell |
| ABIL-02,03,05..10 | — | NOT RUN | |

## 18.4 UI, maps and content

| ID | Level run | Result | Evidence / note |
|---|---|---|---|
| UI-01..10 | — | NOT RUN | |
| MAP-01 | — | NOT RUN | |
| MAP-02 | Unit (pure) + Studio edit | PASS (partial) | duplicate id / budget (pure); stacked-scoring and hidden-floor rejection seen in Studio on fixture iterations |
| MAP-03 | Studio edit | PASS (fixture) | paint_lab v5: 4+4 spawns inside bases, clearance, no opposing sightline |
| MAP-04 | — | NOT RUN | |
| CONTENT-01..08 | — | NOT RUN | Codex Phase 09 |

## 18.5 Network, security, saves and performance

| ID | Level run | Result | Evidence / note |
|---|---|---|---|
| NET-01 | Unit (pure) | PASS (pure) | snapshot + replay convergence |
| NET-02 | Unit (pure) | PASS (pure) | stale/duplicate/reordered versions |
| NET-03..08 | — | NOT RUN | |
| SEC-01 | Build inspection | PASS (partial) | production.rbxlx contains no Dev/TestKit/fixture; server-side dev-command gate pending |
| SEC-05 | Unit (pure) | PASS (pure) | shape/size validators |
| SEC-06 | Unit (pure) | PASS (pure) | NaN/inf/bounds |
| SEC-07 | Unit (pure) | PASS (pure) | cadence gate |
| SEC-08 | Unit (pure) | PASS (pure) | rate limiter |
| SEC-02..04, 09, 10 | — | NOT RUN | |
| DATA-01..04 | — | NOT RUN | |
| PERF-01..05 | — | NOT RUN | |
| OBS-01..03 | — | NOT RUN | |

## 18.6 Handoff and release

| ID | Result |
|---|---|
| HANDOFF-01 | NOT RUN |
| HANDOFF-02, FINAL-01..06 | NOT RUN (Phase 09/10) |
