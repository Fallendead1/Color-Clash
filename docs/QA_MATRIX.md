# QA Matrix — Color Clash

Every GDD Section 18 test ID with its latest **actual** result.
- **Pure** = Lune and in-Studio run of pure modules with simulated inputs.
- **Engine** = Studio Play, server VM, real services (fixture maps unless stated).
- **Client** = Studio Play, client VM, the real client.

All Studio results so far are **solo Play (1 server + 1 real client) on the paint_lab/stress_lab fixtures**. Nothing
here is a 4v4, multi-client, production-map or device result unless it says so. Legend: PASS, FAIL, BLOCKED (missing
capability), NOT RUN.

Runners: `lune run tests/run`; `tools/verify.ps1`; Studio attribute runners (`CCTestRequest` = unit | engine[:filter]
| perf[:filter] on ServerScriptService; `CCClientTestRequest` on LocalPlayer). Phase reports: `docs/qa/phase-NN.md`.

## 18.1 Environment and round lifecycle

| ID | Level | Result | Evidence |
|---|---|---|---|
| ENV-01 | Manual | PASS | STATUS §Project identity |
| ENV-02 | verify.ps1 | PASS | syntax, unit, lint, dev+prod builds, prod instance check |
| ENV-03 | Studio canary | PASS | console boot lines |
| ENV-04 | Rojo vs Studio content | PASS | Workspace/Lighting/StarterPlayer/TextChatService unchanged |
| ENV-05 | — | NOT RUN | no other game's Rojo server active |
| FLOW-01 | Engine | PASS | Boot.spec staging |
| FLOW-02..04 | Pure | PASS (pure) | RoundMachine.spec; multi-client BLOCKED |
| FLOW-05 | Pure + Engine | PASS (pure) / lifecycle engine PASS | Teams.form matrix; RoundLifecycle.spec (solo practice override) |
| FLOW-06 | Pure + Engine | PASS (pure); engine raw-count results PASS (solo) | RoundLifecycle.spec results = raw totals |
| FLOW-07 | — | NOT RUN | Phase 04 |
| FLOW-08 | Pure | PASS (pure) | exact tie / near tie |
| FLOW-09..12 | Pure | PASS (pure) | engine/multi-client pending |
| FLOW-13, FLOW-14 | — | NOT RUN | |

## 18.2 Painting and movement

| ID | Level | Result | Evidence |
|---|---|---|---|
| PAINT-01 | Pure + Engine | PASS | PaintEngine.spec exact 10×10 on fixture |
| PAINT-02 | Pure + Engine | PASS | same-team repaint 0 changes |
| PAINT-03 | Pure + Engine | PASS | exact 50/50 transfer |
| PAINT-04 | Pure + Engine | PASS | wall + base change without score; masked floor never owned |
| PAINT-05 | Pure + Engine | PASS | rotated ramp grid; floor under ramp masked |
| PAINT-06 | Pure + Engine | PASS | thin cover and double wall block paint (real raycasts) |
| PAINT-07 | Pure + Engine | PASS | north face painted, back face untouched |
| PAINT-08 | Client (fixture + budget) | PASS (desktop) | all 6,412 fixture cells; 9,422 sampled budget cells; 0 mismatches |
| PAINT-09 | Client | PASS | palette recolour, ownership hash unchanged |
| PAINT-10 | Pure + Engine + Client | PASS | forged newer delta after freeze ignored; hashes equal |
| PAINT-11 | Pure + Engine + Client | PASS | reset during pending snapshot |
| PAINT-12 | Client (renderer level) | PASS | denied prediction gone < 0.5 s; expiry. Weapon-driven version in Phase 04 |
| MOVE-01 | Pure + Client (real keyboard) | PASS | Own 26.0 / Neutral 10.0 / Enemy 9.0 measured |
| MOVE-02 | Client (real keyboard) | PASS | glide exit < 0.12 s |
| MOVE-03 | Engine + Client (real keyboard) | PASS | lost-paint detach while held; server validation geometric |
| MOVE-04 | Client (real keyboard) | PASS | mantle onto platform; blocked ledge refused |
| MOVE-05 | Pure + Engine | PASS | all refill conditions against the authoritative tank |
| MOVE-06 | Pure | PASS (pure) | engine with weapons Phase 05 |
| MOVE-07 | Client + Engine | PASS | held actions released on elimination |
| MOVE-08 | — | NOT RUN | Phase 05 (dash/roll) |
| MOVE-09 | Engine | PASS | regen delay/rate/reset |
| CAM-01 | Client | PASS | blocked muzzle detected |
| CAM-02 | Client (real keyboard) | PASS | view controllable during glide and climb (charge/gadget/ult Phase 05/06) |
| CAM-03 | Client | PASS | near-wall pull-in outside geometry; shoulder swap |

## 18.3 Combat, weapons and abilities

| ID | Level | Result | Evidence |
|---|---|---|---|
| COMBAT-01..11 | — | NOT RUN | Phase 04/05 |
| WEAPON-01, 02, 04, 07 | Pure | PASS (pure formulas) | Combat.spec; engine pending |
| WEAPON-03, 05, 06, 08, 09 | — | NOT RUN | |
| ABIL-01 (formula), ABIL-04 | Pure | PASS (pure) | |
| ABIL-02, 03, 05..10 | — | NOT RUN | |

## 18.4 UI, maps and content

| ID | Level | Result | Evidence |
|---|---|---|---|
| UI-01 | Client | PASS | UIInput.spec |
| UI-02 | — | BLOCKED | real multi-touch unavailable (no touch injection/device) |
| UI-03..10 | — | NOT RUN | |
| MAP-01 | — | NOT RUN | tactical map Phase 06 |
| MAP-02 | Pure + Studio | PASS (fixture iterations) | duplicate id, budget, stacked scoring, hidden floor rejected |
| MAP-03 | Studio | PASS (fixtures) | paint_lab/stress_lab spawns, clearance, sightline |
| MAP-04 | — | NOT RUN | |
| CONTENT-01..08 | — | NOT RUN | Codex Phase 09 |

## 18.5 Network, security, saves and performance

| ID | Level | Result | Evidence |
|---|---|---|---|
| NET-01 | Pure + Engine + Client | PASS | late join while painting converges (hash ack) |
| NET-02 | Pure + Engine + Client | PASS | gap → exactly one bounded resync → exact state |
| NET-03 | Engine + Client (single client, simulated disconnect by reset) | PASS (simulated) | real disconnect during snapshot needs multi-client: BLOCKED |
| NET-04..08 | — | NOT RUN | |
| SEC-01 | Build + Engine | PASS | |
| SEC-05..08 | Pure | PASS (pure) | engine adversarial suite Phase 08 |
| SEC-02..04, 09, 10 | — | NOT RUN | |
| DATA-01..04 | — | NOT RUN | Phase 07 |
| PERF-01 | Engine + Client (desktop Studio) | PASS (desktop) / mobile BLOCKED | stress_lab measurements in qa/phase-02.md |
| PERF-02..05 | — | NOT RUN | |
| OBS-01..03 | — | NOT RUN | |

## 18.6 Handoff and release

| ID | Result |
|---|---|
| HANDOFF-01 | NOT RUN |
| HANDOFF-02, FINAL-01..06 | NOT RUN (Phase 09/10) |
