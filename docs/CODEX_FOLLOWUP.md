# Codex follow-up after Phase 10 review (Claude → Codex)

This list comes from Claude's first Phase 10 integration pass over Codex content `b387aed`. The code-side fixes are
already committed. The items below belong to **Codex** (content) or **the project owner** (publishing).

**Codex follow-up, 2026-09-30:** items 1–4 are implemented in the v4 content export. Current results and exact
measurement limits are in `CODEX_CONTENT_REPORT.md` and `qa/phase-09/*-v4.json`. Item 5 was explicitly skipped
at the owner's request. The original review below is retained as the task record.

## Codex — content fixes

1. **Combat sightlines (GDD 09.1, about 90 studs).**
   - Problem: sampled eye-height lines reach 151 studs (Switchyard) and 171 studs (Canopy Courts).
   - Fix: break the long lanes with full-height cover while keeping route widths, the mirror symmetry and the
     footprints.
   - Afterwards:
     - Bump `MapVersion` and re-derive the `Expected*` counts.
     - Re-run the route checks and the screen-blocked-flank review.
     - Re-run `engine:ProductionContent` and `perf:ProductionSoak`.
2. **Remove `AnimationSources` from the runtime tree.** The 26 KeyframeSequences are authoring sources, but they ship
   inside `ReplicatedStorage.ColorClashAssets` in the production build, so every client downloads them. Keep them in
   `assets/animation_sources` for publishing only. Move them to a location that is not mapped into the production
   project, or exclude them there.
3. **UI presentation script hygiene.** In `ColorClashUI.Presentation` (lines ~177–178), the per-character connections
   are appended to the script-wide `connections` table, which is only cleared when the GUI is destroyed. The table
   grows by two entries every respawn.
   - Fix: hold them in a per-character list and disconnect it when the character is removed.
   - This is not the cause of the soak memory failure (see below), but it is unbounded.
4. **Canopy Courts flank parity.** Your own report flagged asymmetric flank pathfinder lengths and flank lanes near
   Z ±58 that were not accepted. Review them together with item 1.

## Project owner — publishing (cannot be done by either agent)

5. **Upload the animation and audio sources** under group 506801379 through Studio or Creator Hub:
   - `assets/animation_sources` — 26 animations;
   - `assets/audio_sources` — 34 WAV files.
   Record the real asset IDs and permissions. Then Codex (or Claude) creates the keyed `Animation`/`Sound` instances
   in `ColorClashAssets.Animations` / `.Sounds`, and Claude verifies every key plays in the experience.

## Already resolved by Claude (for your records)

- **Soak memory failure:** diagnosed as uncollected garbage in Studio's whole-process total, not a leak.
  - Every replaced character is collectable on both server and client.
  - The Lua heap is flat at 15 MB.
  - With collection cycles forced, total memory is flat (+6 MB over 10 rounds) and the soak passes. The soak now
    samples memory after a collection nudge.
  - A small residual creep (about 0.4 MB/round in Animation/BaseParts engine tags) is recorded for a longer run.
- **Presentation dispatch** now plays these extra keys:
  - effects `Impact`, `ChargeReady`, `ShieldHit`, `LaunchTransit`, `LaunchLanding`, `ResultsCue`;
  - sounds `Impact`, `UI_Confirm`, `UI_Back`, `ChargeReady`;
  - animations `GlideEntry`, `GlideExit`, `RollerSecondary`, `BrushSecondary`.
- **Team Launch** no longer lands on top of the teammate (found in the 3-client test).
- **The clean production build from tracked files** contains both maps (with manifests), the full UI and the asset
  library.
