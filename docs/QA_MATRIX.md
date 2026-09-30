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
| FLOW-13 | — | NOT RUN | reconnect during loading/results/reset needs a client joining mid-state (multi-client session) |
| FLOW-14 | Perf (contract fixtures, solo) | PASS | perf:RoundSoak 20/20 rounds: maps alternate every round, 7 kits reselected and locked, no entity/arena leftovers, memory -0.5 MB, 0 hash mismatches, 0 handler errors |

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
| UI-04 | Client (simulated gamepad device) | PASS | every panel gets a gamepad selection inside it and closes with B; staging buttons selectable; defects fixed: B did nothing, selection set before layout |
| UI-05 | Client (wireframe layout at 6 viewports) | PASS (wireframe) | buttons on screen and >= 48 px, touch cluster non-overlapping at 1920x1080..740x360, CoreUISafeInsets; defect fixed: Jump overlapped Fire. Physical devices NOT RUN; Codex re-runs on production UI |
| UI-06 | Client | PASS | 8-player synthetic roster: 4/4 grouping, contribution order, 42-char names truncated in bounds, empty roster; 30 % longer status text scales |
| UI-07 | Engine + real client | PASS | map open/close restores context; every launch rejection shows its reason; teammate-only markers (no enemy ESP) |
| UI-08 | Client + Engine | PASS (code paths) | connection notice (2 slow samples, 30 s rate limit); save failure notice; read-failure notice on the real DataStore path; loading stages from Phase 04 |
| UI-09 | Real client (death during open panels) | PASS | map closes on death, Settings stays consistent, elimination shown, fresh HUD, Gameplay restored; reconnect variant NOT RUN (multi-client) |
| UI-10 | Client | PASS | restructured non-wireframe UI (different hierarchy/names, same keys) adopted; handlers, settings rows and touch rebound; swapped back |
| MAP-01 | Pure + Engine + real client | PASS | projection totals == grid totals on server and client; 0 stacked pixels; base floors absent |
| MAP-02 | Engine (fixtures) | PASS | missing/duplicate SurfaceId, off-grid face, manifest count mismatch, production map without manifest: precise reports |
| MAP-03 | Engine (contract fixtures) | PASS | both manifest slots validate; unknown slot, off-centre base, footprint, unmirrored area, opposing-spawn sightline rejected |
| MAP-04 | Engine (contract fixtures) | PASS | scoring cells in OOB, climb face topping into OOB, spawn in OOB rejected |
| CONTENT-01..08 | — | NOT RUN | Codex Phase 09 |

## 18.5 Network, security, saves and performance

| ID | Level | Result | Evidence |
|---|---|---|---|
| NET-01 | Pure + Engine + Client | PASS | late join while painting converges (hash ack) |
| NET-02 | Pure + Engine + Client | PASS | gap → exactly one bounded resync → exact state |
| NET-03 | Engine + Client (single client, simulated disconnect by reset) | PASS (simulated) | real disconnect during snapshot needs multi-client: BLOCKED |
| NET-04 | 2 real clients | PASS (2 clients) / 8 clients BLOCKED (memory) | same frozen state & results |
| NET-05 | Real client + dev net simulation | PASS (simulated) | one-way 25/75/150 ms + jitter 10-30 ms + 5 % unreliable loss (measured app RTT 0.115/0.198/0.35 s): 15/15 shots accepted each, 0 rejects, 0 duplicates (server accepted delta == sent), client paint hash == server hash, 0 handler errors. Real internet links NOT RUN |
| NET-06 | Real client + dev net simulation | PASS (simulated) | 300 ms one-way (RTT 0.67-0.70 s): 15/15 accepted, hashes equal, "Connection delayed" shown and rate-limited (30 s), player never kicked (no latency kick path exists) |
| NET-07 | Engine | PASS (bound) / moving-player rewind NOT RUN | rewind = one-way latency capped at 150 ms (0.1 s RTT -> 50 ms, 1.2 s -> 150 ms); full charge at max rewind still blocked by current thin cover; moving-player case needs 2 clients |
| NET-08 | Real client | PASS (1 client) | resync requested mid-burst under fire: converged hash, no rejects; queue bounded by SnapshotReplayBufferMax; 8-client saturation BLOCKED (memory) |
| SEC-01 | Build + Engine | PASS | |
| SEC-05 | Pure + Engine + real client (real remotes) | PASS | 11 garbage payload types x 5 handlers (engine) and 17 x 16 remotes from a real client: 0 handler errors, no state mutation, unknown kit/action/target rejected |
| SEC-06 | Engine | PASS | NaN/inf vectors, non-unit aim, NaN time, 1e7 origin -> "invalid"; +40-stud origin -> "origin"; launch NaN/inf targets rejected; no state change |
| SEC-07 | Engine | PASS | exact replay and older sequence -> "sequence"; +2 s future and -30 s ancient -> "timestamp"; exactly one accepted shot |
| SEC-08 | Real client (real remotes) | PASS | floods of ~900 requests: rate limiter dropped 280 Action / 113 Ready, SelectLoadout, PaintResync, Launch, SettingsPatch / 97 ClientEvent; server frame max 23.5 ms; 0 handler errors |
| SEC-09 | Engine | PASS | trail teleport step skipped |
| SEC-02 | Engine | PASS | CFrame / extra keys / non-table / self / unknown id rejected; no position change |
| SEC-03 | Engine | PASS | extra cost/damage keys rejected; meter < 100 refused; dry gadget free |
| SEC-04 | Engine | PASS | dead and old-life casts/launches rejected; paint hash unchanged |
| SEC-10 | Build scan + Engine | PASS | tools/scan_client_surface.py over build/production.rbxlx (59 scripts, 37 client-readable): no credentials/webhooks/loadstring/asset-id requires/RemoteFunctions/debug commands (positive control detects planted items); remote surface == protocol list, no stray remotes |
| DATA-01 | Engine (memory backend) + real DataStore (Studio, scope "studio") | PASS | perf:PrefsRealSave after API access was enabled: new profile -> sensitivity 1.7, invertY, kit popshot written via UpdateAsync, re-read "ok" with the same values, then restored. Published-server save still part of FINAL-03 |
| DATA-02 | Engine (memory + real DataStore failure) | PASS | read failure -> usable defaults + notice, nothing written, later edit merges without overwriting the stored profile |
| DATA-03 | Pure + Engine | PASS | newer schema read-only; invalid values repaired; concurrent-session change survives; patch whitelist |
| DATA-04 | Engine | PASS | 21-patch burst -> 1 write; failed write reports "failed", keeps the change, later flush succeeds; leave/shutdown flush in code |
| PERF-01 | Engine + Client (desktop Studio) | PASS (desktop) / mobile BLOCKED | stress_lab measurements in qa/phase-02.md |
| PERF-02 | — | BLOCKED | eight clients need more free RAM (15.9 GB total, ~0.8 GB free with Studio open) |
| PERF-03 | Perf (contract fixtures, solo) | PASS (desktop Studio, fixtures) | 20 rounds: memory after reset flat (rounds 3-7 mean 2457.0 MB vs 16-20 mean 2456.9 MB, Studio process), 287 Workspace instances every round, server frame p95 18 ms, send ~3.3 KB/s; per-round max ~190-207 ms is the map-load window (excluded by GDD 14.2) |
| PERF-04 | — | BLOCKED | no physical mobile device / production content |
| PERF-05 | Real client | PASS (palette + focus loss) / resize NOT RUN | 8 palette switches + focus loss under sustained fire: no stuck input or continuous action, Lua heap 3.5 -> 2.6 MB (peak +0.2 MB); renderer parts not measurable while the Studio viewport is hidden (RenderStepped paused); window resize cannot be driven |
| OBS-01 | Engine | PASS | known-clock events -> milestones in seconds since SessionStarted (2.5, 10.25); missing milestones nil; unknown player nil |
| OBS-02 | Engine | PASS | shotSummary separates invalid (2), legal rejections (1 cadence), accepted (3) with hits (2) and noVictim (1); attempts 6 |
| OBS-03 | Engine | PASS | SessionEnded reason "left" or "kicked:<reason>"; client frame p95 attached only as correlation (causeInferred = false); unknown/invalid perf values nil |

## 18.6 Handoff and release

| ID | Result |
|---|---|
| HANDOFF-01 | PASS (document review) — `docs/CODEX_HANDOFF.md`: exact commit reference, contracts, inventory, fixture evidence, pending real-content tests |
| HANDOFF-02, FINAL-01..06 | NOT RUN (Phase 09/10) |
