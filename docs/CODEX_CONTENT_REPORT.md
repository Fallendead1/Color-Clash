# Phase 09 content report — Codex to Claude

**Status: BLOCKED / incomplete.** Original native content is implemented and tracked, but the Phase 09 acceptance gate is not met. Published animation/audio IDs are absent, combat sightlines exceed the GDD target, and the final production-map soak failed its memory-growth assertion. Do not mark `CORE_PVP_VERIFIED` or Phase 09 complete from this report.

## Project and preservation

Work stayed in `C:\Color-Clash`, branch `main`, repository `Fallendead1/Color-Clash`, existing Color Clash Studio place **130101797221207**, universe **10768629864**, owner group **506801379**. Starting HEAD was **33d6840**; prior code baseline **2d0852a** and contract handoff **1deba2c**. ContractVersion remains **1**, content version **1**, both map versions **3**. The content commit is the commit introducing this report; use `git log -1 --format=%H -- assets/maps/ColorClashMaps.rbxmx` to resolve it.

No files under `src/server/Services`, `src/server/Combat` or `src/shared` were modified. No shops, cosmetics economy, ranked, PvE, balance changes or excluded feature was added. The original Studio baseplate, spawn and Lighting were preserved. Map floor elevation is 100, matching the established fixture elevation; X/Z slot origins and footprints remain unchanged.

Rojo 7.7.0 remains served on port **34872** by the existing process. The Studio plugin reported a stale disconnected session. Content was imported into the same place using the same builders through the Studio API; reconnection has **not** been confirmed. `tools/prepare_studio_import.py` prepares that import for recovery. This does not replace the tracked Rojo mappings or create another project.

## Implemented inventory

| Area | Delivered content and runtime use |
|---|---|
| Arenas | Original mirrored Switchyard and Canopy Courts with protected bases, eight spawn markers, floor/ramp/climb patches, solid undersides, cover, canopy collision, perimeter/recovery volumes and staging return. Slot/load validation passes. Sightline acceptance remains open. |
| Athlete | AthleteDescription normalized by the existing service; original non-colliding welded Paint Tank/harness; team palette, A-triangle/B-square labels and occluded outlines. Default R15/default locomotion remains. Custom source animation playback is not available yet. |
| Weapons | All seven exact kit IDs; Twin Jets has left/right models, grips and separate muzzles; melee EffectOrigin attachments; cosmetic construction welds. Construction validators pass. |
| Gadgets/ultimates | Splash Can, Paint Screen, Color Burst capsule and Paintstorm beacon. Authored capsules ride the existing cosmetic trajectories; screen trim reads existing health/palette attributes. Fuse, warning, collision queries, cost, range and damage remain code-owned. |
| UI | Exported native ScreenGui, 13 contract groups, templates, responsive panels, mint/cream/navy styling, button state/focus treatment, four-tick reticle, 11 original native silhouette icons, input glyph sources and visible input legend. Code-owned map/score/settings data and actions remain bound by UIKey. |
| Effects | 23 native effect/model templates, bounded cosmetic lifetimes, no collision/query/touch. Existing warning areas remain visible; extra templates without dispatch are explicitly pending below. |
| Animation sources | 26 R15 KeyframeSequences; seven attack Fire markers match configured windup times. No root translation. All are **unpublished sources**; runtime Animations folder is empty. |
| Audio sources | 34 original synthesized mono WAV cues and a per-cue source/permission manifest. All are **unpublished sources**; runtime Sounds folder is empty. |

Exports and all three required destinations are mapped in **both** `default.project.json` and `production.project.json`, in this content commit. The staging mapping is narrow and preserves other Workspace children. `assets/README.md` records rebuild and publication steps. No fake IDs or temporary Studio animation registration IDs are shipped.

## Budgets and map evidence

| Map v3 | Footprint | Scoring cells | Wall cells | Patches | Native parts |
|---|---|---|---|---|---|
| Switchyard | 240 × 160 | 31,530 | 2,064 | 9 | 165 |
| Canopy Courts | 220 × 180 | 32,704 | 2,240 | 9 | 173 |

The loader derived these values in **Server Play mode**, then accepted the declared attributes with zero warnings and zero slot errors. Both are below 50,000 scoring cells, 16,000 wall cells and 96 patches. Ramp high ends meet terraces; ramp inclines are below 30 degrees. Terraces are 8/10 studs, with solid fill. Full screens are 8 studs and low-cover wings are 3.5 studs. Weapon models use 6–16 native parts; the export audit's 256-triangles-per-part budgeting estimate is 1,536–4,096 per weapon, not a measured renderer/device triangle count. The 20,000-triangle athlete target and physical-device performance remain unmeasured.

`routes-v3.json` records all six sampled approaches per map succeeding without jumping: a radius-9 agent to the center, radius-6 agents to flank samples at Z ±48. These are pathfinding checks, not measured player traversals or proof that the three approaches remain independent throughout their length. Mirrored center estimates are equal: Switchyard **7.04 s**, Canopy **6.44 s** at 16 studs/s. Canopy's asymmetric flank pathfinder lengths need manual route/parity review; its GDD flank lanes near Z ±58 were not separately accepted.

**Failed design criterion:** sampled eye-height sightlines reach **151 studs** on Switchyard and **171 studs** on Canopy Courts, above the roughly 90-stud intended maximum. The scan samples an 8-stud grid in four directions; it is not a global maximum proof. Several tighter experimental layouts failed route clearance and were discarded. No experiment-only geometry remains in the delivered maps. Screen-blocked flank access, measured human traversal parity, all canopy gameplay occlusion cases and human readability/fun still require review.

## Executed checks

| Check | Actual result and scope |
|---|---|
| `tools/verify.ps1` | PASS: 120 Luau files parse; 66/66 Lune; selene 0 errors/0 warnings; dev/prod builds; no dev modules in production; client surface scan 60 scripts/38 client-readable. |
| Export audit | PASS: serialized exports deserialize; UI contract keys/classes; map declarations/budgets; weapon construction and effect safety; source attack timings. Publication gates are reported open. |
| Full Studio engine suite | 112/112, 14 specs, 238,950 ms. Existing gameplay specs explicitly use their intended fixtures. Includes actual-content validation, but ran before final map v3; final content was rechecked separately. |
| Final production content | 3/3, 492 ms on map v3: both actual map slots/manifests without warnings, seven weapons, ramp joins and canopy vertical collision rays. |
| Final client suite | 15/15, 6,257 ms after final UI icon/legend changes. Six viewports including 740×360, long labels/empty rows and controller action paths. `CCUIWireframe=false`, `CCUIErrors=0`, empty layout diagnostics. Not physical touch/gamepad testing. |
| Earlier production soak v2 | 20 accelerated solo rounds, passed; retained as historical evidence only. Superseded by final v3 for current content acceptance. |
| Final production soak v3 | **FAIL**, 20 accelerated solo rounds, 233,624 ms. Both actual maps rotate (`fixture=false`), all seven kits; 0 paint hash mismatches, 0 handler errors, post-reset Workspace instances early/late 320/325. The memory assertion reports **+66.3 MB after warm-up** (early 1,817.8 MB, late 1,884.1 MB). See `soak-v3.json`. |

The soak uses six-second Live windows and one local client. It is not 20 full-length matches, an eight-player stress test or a device budget certification. Reported frame p95 is roughly 18 ms wall-frame time, not game-owned CPU; per-round maxima include load/reset. Total Studio memory is noisy and a later snapshot fell to 1,860.3 MB, but there is insufficient category baseline data to attribute or dismiss the failed assertion. Do not replace this failure with the older v2 pass.

Visual inspection used Studio captures of both arenas, the seven models and the staging UI. `switchyard.png` and `ui.png` are saved edit-time previews; the UI image does not contain runtime-populated status text. It is not gameplay/device evidence.

## Integration details and reasons for code changes

- The only changed production code under `src` is `EffectsController`: attach original throwable art to the existing pooled cosmetic part, reset carrier transparency on reuse and remove attached art when returned to the pool.
- The exported GUI includes a presentation-only LocalScript for style, icons, tank/team markers and screen trim. It uses the existing public `UIController.adopt` hook when StarterGui replication arrives after initial wireframe bootstrap, then removes the obsolete wireframe after successful adoption.
- Fixture-specific dev tests now select their intended fixture explicitly, and missing-asset fallback tests temporarily isolate the real content library and restore it. They must not mistake real production content for a missing-asset failure.
- UIPanels now clones the real exported template and waits for layout before sampling the safe-area origin. A stale origin previously caused a false off-screen Jump result; the actual compact position was (630,292), size 64×64.
- `ProductionContent`, `ProductionSoak` and the offline export/route tools provide separate evidence for actual content. Dev code remains excluded from production builds.

## Required next work — return to Claude with these gates open

1. Finish map combat sightlines while retaining route widths, mirrored travel and specified footprints. Increment MapVersion, derive new counts, repeat route, screen-blocked-flank, loader and soak checks. Do not alter protected gameplay code as a shortcut.
2. Diagnose the v3 soak memory failure with category baselines and repeated warmed measurements. Inspect map/paint lifecycle retention and presentation character connections before drawing a leak conclusion.
3. Publish the source animations/audio through an available authenticated Roblox workflow. The attempted `CreateAssetAsync` upload returned **“CreateAssetAsync and CreateAssetVersionAsync are not available yet”**. Record genuine IDs and permissions under group 506801379, create the keyed runtime Animation/Sound instances, rebuild, and verify every requested presentation key in the target live experience. No assets were uploaded or place published here.
4. Review/add presentation dispatch for `Impact`, `ChargeReady`, `ShieldHit`, `LaunchTransit`, `LaunchLanding`, `ResultsCue` and extra source clip keys. Existing contract-dispatched cues are present as native templates; unpublished animation/audio missing counts are expected and are not an acceptance pass.
5. Confirm the existing Rojo plugin connection to localhost:34872, then prove a clean tracked-content import in a test copy of the same place setup. Offline dev/prod builds pass; the clean Studio import test remains unrun.
6. Complete CONTENT-02/03 visual action geometry, CONTENT-04 playback, CONTENT-06 low-quality/palette readability, CONTENT-07 clean import, CONTENT-08 full budgets, physical devices, multi-client/eight-client, published saves/smoke test, and human playtests. These are not covered by the passing structural checks.

Claude can resume investigation/integration review with this report, but Phase 10 final acceptance remains blocked by the unfinished Phase 09 items above.
