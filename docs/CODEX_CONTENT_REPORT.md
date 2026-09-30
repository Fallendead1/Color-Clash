# Phase 09 Round 2 content report — Codex to Claude

**Items 6 and 7 implemented and checked; ready for Claude's Phase 10 review.** This report covers the owner's Round 2 request against starting commit `2c62699`. It supersedes the v4 report. Historical results remain in Git and the versioned QA files. Owner publishing item 5 remains deferred; this is not a declaration of `CORE_PVP_VERIFIED` or full release acceptance.

## Delivered changes

Both arenas are **MapVersion 5**, ContractVersion 1. New gallery side screens and rear backstops limit views from the ramps and terraces. Selected existing cover carries upper backstop panels, and the ramp entrance screens have **7.5 studs of clearance beneath them**. The ramp walking surface remains 20 studs wide; the deck's open cross-section is 22.5 studs. Ordinary cover and the original 8/10-stud climb faces remain. The Switchyard ramp-side backstop stops short of the walking surface, and a raised rear-corner return closes its final diagonal without obstructing the ground route.

Switchyard also received a small mirrored adjustment to its central islands and approach to remove six ground rays between 95 and 97 studs found by Claude's scanner. Main approach clearance remains 18 studs, flank clearance 12; the short protected spawn-pad access remains 12. The specified footprints, symmetry, stable paint-surface IDs, bases, spawn markers, ramp slopes and staging location are preserved. New geometry is anchored and static; no code-owned behavior or timings changed.

The implementation lives in `tools/content/elevated_cover.luau`, `maps.luau` and `cover_layouts.luau`, with the tracked `assets/maps/ColorClashMaps.rbxmx` export and loader-derived counts. Existing mappings in both Rojo projects continue to target `ServerStorage.ColorClashMaps`.

The prior inventory is preserved: normalized athlete presentation, seven weapon kits and their attachments, gadgets/ultimates, 23 native effect templates, production native UI/icons/glyphs, 26 unmapped animation source sequences and 34 original WAV sources. Runtime authoring poses remain excluded. No new remote asset ID, upload or publication was attempted. The owner's permission/publication records remain in `assets/README.md` and `assets/audio_manifest.json`.

## Acceptance and budgets

**The acceptance scanner is the unchanged `tools/content/sightline_scan_claude.luau`, run in Edit mode.** Its SHA-256 is `81D342BBF31D76787850BE841847E2D901D5155878D001EA10664251CFDFD8E4`.

| Map | Ground maximum | Elevated maximum | Lines over 95 |
|---|---|---|---|
| Switchyard v5 | 94.7 studs | 81.0 studs, terrace_A (−51, −57) | **0 ground / 0 elevated** |
| Canopy Courts v5 | 93.0 studs | 90.9 studs, ramp_A (−25, −61) | **0 ground / 0 elevated** |

There are **no remaining over-limit locations** in this acceptance sample. The same script measured v4 at 196.6/204.9 studs elevated, with 1,258/1,355 over-limit elevated rays. It also measured Switchyard v4 ground at 96.7, with six over-limit rays. No thresholds, sampling rules or protected-volume exclusions were changed. This remains a finite 2-stud-grid / 64-direction horizontal-ray scan, not proof over every possible position and aiming angle.

| Map v5 | Footprint | Scoring cells | Wall cells | Patches | Native parts |
|---|---|---|---|---|---|
| Switchyard | 240 × 160 | 26,620 | 1,744 | 9 | 343 |
| Canopy Courts | 220 × 180 | 28,156 | 1,920 | 9 | 391 |

The actual MapLoader derived these counts in Server Play with the Expected attributes absent. Declared counts then passed with zero errors, warnings and slot failures. Both maps remain below 50,000 scoring cells, 16,000 wall cells and 96 patches. Geometry under new cover is masked normally; no scoring surface or source animation was removed to evade the sightline test.

| Check | Current result |
|---|---|
| Claude's Edit acceptance scan | PASS, both categories on both maps; exact output in `sightlines-v5.json`. |
| Route sweeps / screen-blocked flanks | PASS, 18-stud main / 12-stud secondary clearance, both central screen orientations and the approach screen. Actual flank targets remain Z ±48 / ±58. |
| Live humanoid traversal | PASS, **24/24 walkers**, jumping disabled, WalkSpeed 16. Includes the main/flank approaches and three tracks along each ramp and deck, in both directions. All mirrored pairs differ by less than **0.016 s**. |
| Gallery base sightlines / climb clearance | PASS, 32 rays from the designated terrace-center firing positions to all spawn pads blocked. 80 capsule-sized climb-column and mantle-landing clearance samples clear. This is geometry evidence, not a new climb mechanic. |
| `engine:ProductionContent` | PASS, **4/4**, 801 ms: both manifests/slots, no runtime animation sources, seven weapon constructions, ramp joins and canopy collision. |
| Serialized export audit | PASS: actual exports, budgets, UI contract, weapon/effect safety, preserved source timing, no runtime poses or duplicate banks. |
| `tools/verify.ps1` | PASS: 121 Luau files parse; 66/66 unit tests; clean selene; dev/prod builds; no dev instances in production; client surface scan clean. |
| Final `perf:ProductionSoak` | PASS: 20 accelerated rounds, 237,841 ms, both production maps and all seven kits; 0 problems, 0 handler errors, 0 paint hash mismatches. Early/late memory means 2,293.5/2,280.5 MB; post-reset instance means 320/325. Passes the existing collector-aware gate; no claim that every memory sample was flat. |

Reproducers: the unchanged acceptance scanner, `check_routes.luau`, expanded `check_walk_routes.luau`, and `check_gallery_clearance.luau` under `tools/content`. Evidence is versioned under `docs/qa/phase-09/*-v5.json`. The retained ground-only route scan is supplementary; **it is not the Round 2 sightline acceptance check**.

## Rojo tracking and handoff

Work stayed in `C:\Color-Clash`, branch `main`, existing Color Clash place **130101797221207**, universe **10768629864**, owner group **506801379**. No second project or worktree was created. No files under `src/` were changed.

Tracked files and exports were changed first. The existing Rojo server was still listening on **127.0.0.1:34872**, but a tracked MapVersion update did not reach Studio. Therefore **maps-only imports were necessary**, using the new `tools/prepare_map_import.py`. This fallback replaces only `ServerStorage.ColorClashMaps`; it does not import scripts, UI, presentation assets, staging or Lighting. The broad `prepare_studio_import.py` helper was not executed this turn.

**Owner/Claude action: reconnect the Studio Rojo plugin to the existing server on port 34872 before continuing integration.** Live tracking has not been re-established or claimed. A read-only comparison confirmed that Studio's `EffectsController.Source` matches the tracked file; no script Source was assigned and no mapped script instance was replaced in this turn. Source equality is not proof of future Rojo synchronization.

Studio is left stopped in the same place with both final v5 templates and their new manifests installed. The acceptance scan was repeated after that final import and matched the recorded output exactly. Both arenas received an Edit-mode visual review; scratch copies were removed and the UI's original enabled state restored.

Claude should resume Phase 10 with the v5 content commit and recorded acceptance results. Publishing the 26 clips and 34 sounds remains the owner's job; record genuine IDs/permissions before keyed runtime instances and live playback are verified. Remaining release gates include physical devices, eight-client load, published smoke/save/playback checks and human readability/fun review. The accelerated solo soak does not certify those gates or replace the previously recorded longer-run engine-memory investigation.
