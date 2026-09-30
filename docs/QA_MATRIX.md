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
| FLOW-06 | Pure + Engine + 2 real clients | PASS | raw-count results; both clients frozen hash == server |
| FLOW-07 | Engine | PASS | late impact excluded; nothing in flight after the round (all-clients agreement via frozen hashes) |
| FLOW-08 | Pure | PASS (pure) | exact tie / near tie |
| FLOW-09 | Pure + 3 real clients | PASS | backfill to smaller side, synced first, ult 0 |
| FLOW-10 | Pure + 3 real clients | PASS | <= 60 s left: stays in staging |
| FLOW-11 | Pure | PASS (pure) | real replacement-in-grace NOT RUN |
| FLOW-12 | Pure + real clients | PASS | real kick -> pause (clock frozen) -> NoContest |
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
| MOVE-06 | Pure + Engine | PASS | rolling/charging/pushing: no refill |
| MOVE-07 | Client + Engine | PASS | held actions released on elimination |
| MOVE-08 | Engine + real client | PASS | teleport step not painted; dash stops at wall |
| MOVE-09 | Engine | PASS | regen delay/rate/reset |
| CAM-01 | Client | PASS | blocked muzzle detected |
| CAM-02 | Client (real keyboard) | PASS | view controllable during glide and climb (charge/gadget/ult Phase 05/06) |
| CAM-03 | Client | PASS | near-wall pull-in outside geometry; shoulder swap |

## 18.3 Combat, weapons and abilities

| ID | Level | Result | Evidence |
|---|---|---|---|
| COMBAT-01 | Engine | PASS | enemy/friendly targets, exact cost |
| COMBAT-02 | Engine | PASS | replay: one cost, one hit |
| COMBAT-03 | Engine | PASS | thin cover blocks; normalized rig has 0 accessories |
| COMBAT-04 | Engine | PASS | empty tank |
| COMBAT-05 | — | NOT RUN | next multi-client session |
| COMBAT-06 | Pure + real clients (single attacker) | PASS (pure) / assist with real attackers NOT RUN | |
| COMBAT-07 | — | NOT RUN | next multi-client session |
| COMBAT-08 | Engine + Client (real mouse) | PASS | base both directions |
| COMBAT-09 | Engine | PASS | shield removed by attack |
| COMBAT-10 | Pure + Engine | PASS | OOB elimination; recent-hit credit (pure) |
| COMBAT-11 | Engine | PASS (server) | kit locked in match; client listener stacking: single controller stack by design |
| WEAPON-01 | Pure + Engine + real mouse | PASS | 5 hits, 0.48 s window |
| WEAPON-02 | Engine + real client | PASS | 6 hits single event; dash cost/cooldown/state; dash stops at wall |
| WEAPON-03 | Engine | PASS | flick 65/40/0; roll contact 60, strip, drain |
| WEAPON-04 | Engine + real client | PASS | early release free, full 110, forged key rejected, glide/panel cancel |
| WEAPON-05 | Engine | PASS | volley capped 55 |
| WEAPON-06 | Engine | PASS | sweep 32, spam bounded, push exclusive |
| WEAPON-07 | Engine | PASS | direct 70 xor splash |
| WEAPON-08 | Engine | PASS | all classes accepted and blocked by cover; enemy screens block projectiles, beams and blasts (engine:Tactical) |
| WEAPON-09 | Perf (stress_lab) | MEASURED | matrix in qa/phase-05.md; human playtest NOT RUN |

| ABIL-01 | Engine | PASS | paid at release, fuse 1.2 s ±0.12, 70 / falloff / 0, one result per victim, duplicate and second-can refused, cover blocks |
| ABIL-02 | Engine + real client | PASS | in-base and inside-geometry placements free; legal placement atomic (-55); interval; replacement removes the old part; 5 s lifetime |
| ABIL-03 | Engine | PASS | destroying Popshot shot consumed (4 x 70); no blocker left (raycast clear, next shot hits); own screen ignored; enemy screen blocks beam and blast |
| ABIL-04 | Pure + Engine | PASS | own floor 0, walls 0, Color Burst paint 0, neutral floor > 0 within 6/s |
| ABIL-05 | Engine | PASS | death in preparation: cancelled, meter already spent, no refund; after release: burst still resolves |
| ABIL-06 | Engine | PASS | canopy blocks rain paint and damage; two overlapping storms, <= 1 tick of 5 per 0.5 s; wall beacon fizzles with cue; no meter |
| ABIL-07 | Engine + real client (Base) | PASS (Base) / teammate NOT RUN | channel 1.0 s, transit invulnerable, arrival 2.0 s at a validated spawn, 8 s cooldown; real client via Launch remote 2.10 s; teammate launch needs 2 same-team clients |
| ABIL-08 | Engine | PASS | damage / >1 stud movement / attack cancel the channel; no departure, no cooldown; 1.5 s recent-damage rule |
| ABIL-09 | Engine (in-transit) | PASS (in-transit fallback) / target death NOT RUN | blocked frozen landing -> validated friendly spawn, cooldown retained; pre-departure target death needs a teammate client |
| ABIL-10 | Engine | PASS | round end with storm, screen, can in flight and launch channel: all cleared, nothing resolves later, no screen parts left |

## 18.4 UI, maps and content

| ID | Level | Result | Evidence |
|---|---|---|---|
| UI-01 | Client | PASS | UIInput.spec |
| UI-02 | — | BLOCKED | real multi-touch unavailable (no touch injection/device) |
| UI-03 | Engine | PASS (server) | one confirmed selection, locked live; client Equip double-submit guard in UIController |
| UI-04..10 | — | NOT RUN | |
| MAP-01 | Pure + Engine + real client | PASS | projection totals == grid totals on server and client; 0 stacked pixels; base floors absent |
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
| NET-04 | 2 real clients | PASS (2 clients) / 8 clients BLOCKED (memory) | same frozen state & results |
| NET-05..08 | — | NOT RUN | |
| SEC-01 | Build + Engine | PASS | |
| SEC-05..08 | Pure | PASS (pure) | engine adversarial suite Phase 08 |
| SEC-09 | Engine | PASS | trail teleport step skipped |
| SEC-02 | Engine | PASS | CFrame / extra keys / non-table / self / unknown id rejected; no position change |
| SEC-03 | Engine | PASS | extra cost/damage keys rejected; meter < 100 refused; dry gadget free |
| SEC-04 | Engine | PASS | dead and old-life casts/launches rejected; paint hash unchanged |
| SEC-10 | — | NOT RUN (Phase 08) | |
| DATA-01..04 | — | NOT RUN | Phase 07 |
| PERF-01 | Engine + Client (desktop Studio) | PASS (desktop) / mobile BLOCKED | stress_lab measurements in qa/phase-02.md |
| PERF-02..05 | — | NOT RUN | |
| OBS-01..03 | — | NOT RUN | |

## 18.6 Handoff and release

| ID | Result |
|---|---|
| HANDOFF-01 | NOT RUN |
| HANDOFF-02, FINAL-01..06 | NOT RUN (Phase 09/10) |
