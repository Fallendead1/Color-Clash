# Phase 09 content follow-up — Codex to Claude

**Follow-up items 1–4 implemented and checked; ready for Claude's Phase 10 review.** Item 5 is explicitly deferred to the project owner: no animation/audio upload, invented ID or publication was attempted in this follow-up. This report supersedes the v3 content report; historical evidence remains in Git and the versioned QA files. It does not declare Phase 09 complete or `CORE_PVP_VERIFIED`.

## Scope and preservation

Worked in the existing `C:\Color-Clash` repository on `main`, starting at `f7cad55`. Studio identity remains Color Clash, place **130101797221207**, universe **10768629864**, group **506801379**. No second project, worktree or place was created. Protected paths `src/server/Services`, `src/server/Combat` and `src/shared` are unchanged.

Claude's Phase 10 fixes remain intact, including memory collection in the soak, extra presentation dispatch, Team Launch landing and memory-backed test preferences. No gameplay timing, balance, IDs, attachments, remotes or excluded features were changed.

The existing Rojo server still listens on **127.0.0.1:34872** (PID 30436). Both Rojo projects retain the required tracked model/UI mappings. The same deterministic builders were imported into the existing Studio through the Studio API; a live Rojo plugin connection was not independently confirmed. Baseplate, staging setup and Lighting were preserved.

## Changes delivered

1. **MapVersion 4 on both arenas.** Mirrored full-height utility banks, staggered approaches and Canopy base-corner cover break the long ground combat lanes. The authored rectangle layouts and review paths are reproducible in `tools/content/cover_layouts.luau`. Caps follow the revised collision geometry. Overlapping collinear banks were consolidated without changing their occupied area. Surface IDs, slot footprints, bases, ramps, staging and code-owned behavior remain stable.
2. **Authoring clips removed from runtime.** `ReplicatedStorage.ColorClashAssets` contains no `AnimationSources`, `KeyframeSequence` or `Pose`. All **26** source sequences remain in the unmapped `assets/animation_sources/AnimationSources.rbxmx`. Both the offline serialized-export audit and Studio production-content spec check this separation.
3. **Character connections have character lifetimes.** The UI presentation script keeps each character's team/ancestry/destroy connections in its own list. Removal disconnects that list, removes retained character references and destroys its gear. GUI destruction also cleans every surviving list. The script-wide array no longer accumulates these subscriptions. A diagnostic GUI attribute reports the live subscription count.
4. **Canopy flank parity reviewed at Z ±58.** The two flank paths use the intended crossings, mirrored bends and clear outer passages. Equivalent approaches have identical geometric lengths. The covered Canopy route starts at the matching lower spawn; its mirror starts at the upper opposing spawn. It does not require walking across the protected base to enter that flank.

The original inventory is preserved: normalized athlete presentation, **seven** weapon kits (including Twin Jets' separate models/muzzles), gadgets and ultimates, **23** native effect templates, native production UI with its contract keys/icons/glyphs, **26** animation sources and **34** original synthesized WAV cues. Runtime `Animations` and `Sounds` remain empty pending the owner. Identity, source and permission records remain in `assets/README.md`, `assets/audio_manifest.json` and the export audit.

## Map measurements and budgets

| Map v4 | Footprint | Scoring cells | Wall cells | Patches | Native parts |
|---|---|---|---|---|---|
| Switchyard | 240 × 160 | 26,996 | 1,744 | 9 | 287 |
| Canopy Courts | 220 × 180 | 28,434 | 1,920 | 9 | 323 |

Counts were derived by the actual MapLoader in Server Play with manifest counts absent, then declared and validated with **zero errors, warnings or slot failures**. Both maps remain below 50,000 scoring cells, 16,000 wall cells and 96 patches. The existing ramp inclines, solid terrace undersides and canopy collision checks pass. Weapon construction/budget estimates, source animation timing and effect safety still pass the export audit. Native-part counts are not physical-device renderer measurements.

The route audit sweeps a 5.5-stud-tall clearance box at intervals no greater than one stud. Main approaches have **18-stud** clearance; secondary routes have **12**. The short spawn-pad access segment uses 12 before joining the main approach. All six routes on each map pass. A 12 × 8 × 0.5 screen at the center in both orientations, and at the main approach, leaves both mirrored flanks clear. These are geometry checks against the screen's dimensions, not a new gameplay implementation.

The expanded ground scan uses a **2-stud grid, 64 directions and 4.5-stud eye height**: 372,032 rays on Switchyard and 393,792 on Canopy. Longest sampled continuous combat segments are **94.82** and **94.73 studs**, using 95 as the review tolerance for the GDD's “about 90.” Switchyard's raw geometry maximum is also 94.82. Canopy's raw maximum is **112.57**, ending inside a protected base; there are **zero** sampled rays over 95 that cross an entire base and return to combat space. The test reports both measurements rather than counting protected-base space as a combat lane. This finite ground scan is not a mathematical maximum over all positions, elevations and aiming angles.

Live Server Play traversal cloned the normalized player rig, disabled jumping, used WalkSpeed 16 and ran equivalent mirrored routes. All **12 walkers** reached their destinations. Maximum A/B timing differences: **0.0025 s Switchyard**, **0.0187 s Canopy**, within 0.5 s. Approximate center times were 11.05 s and 10.20–10.22 s. Canopy flank times were 11.63–11.64 s and 11.68–11.69 s. These are automated humanoid traversals, not human playtests or claims about the shortest pathfinder route.

Evidence: `docs/qa/phase-09/routes-v4.json`, `walk-routes-v4.json`, `export-audit.json`; reproducers in `tools/content/check_routes.luau` and `check_walk_routes.luau`.

## Verification

| Check | Result |
|---|---|
| `tools/verify.ps1` | PASS: 121 Luau files parse; 66/66 unit tests; selene 0 errors/warnings; development and production builds; no dev code in production; client surface scan passes. |
| Serialized export audit | PASS: map budgets, native UI contract, weapon construction, effects, all 26 preserved source timings, no runtime authoring poses, no duplicate utility banks. |
| `engine:ProductionContent` | PASS: 4/4, 680 ms, on the final geometry and source-free runtime library. |
| Route clearance / screen-blocked flanks | PASS on both maps; actual Canopy Z ±58 targets; no jumping required. |
| Live humanoid parity | PASS: 12/12 destinations, all six equivalent pairs within 0.5 s. |
| Final `perf:ProductionSoak` | PASS: 20 rounds, 237,291 ms; both production maps/all seven kits; 0 problems, 0 handler errors, 0 paint hash mismatches. Early/late memory 2,056.3/2,029.9 MB; post-reset instance means 320/325. |
| Final client UI suite | PASS: 15/15, 6,618 ms; production UI active, 0 UI errors, empty layout diagnostics. |
| Character connection monitor | PASS: 2,097 samples across the final soak; maximum/current 3 subscriptions, minimum 0 during removal. |

Final evidence is saved in `production-content-v4.json`, `soak-v4.json`, `client-v4.json` and `character-connections-v4.json` under `docs/qa/phase-09`. The clean production Rojo build also contains zero source sequences, poses or AnimationSources folders. Both final arenas were visually inspected in Edit mode; review clones were removed and the production UI restored. Studio is left stopped in the same project with both v4 templates installed. Claude already diagnosed the historical v3 memory failure as uncollected Studio garbage, not a demonstrated retention leak. His collector-aware soak remains unchanged. Accelerated solo rounds are not full-length matches, eight-player load, phone/tablet certification or a replacement for the recorded longer-run engine-memory investigation.

## Handoff

Claude should resume Phase 10 against this content commit and the final QA records. The project owner retains publishing item 5: upload the 26 clips and 34 WAVs under the owning group, record genuine IDs/permissions, then have the keyed runtime instances and playback verified. No publication is represented as complete.

Remaining release acceptance includes published asset playback/smoke/save checks, eight-client load, physical devices, elevated-angle and human readability/fun review, and other open Phase 10 matrix entries. Earlier fixture-only evidence is not promoted to production acceptance.
