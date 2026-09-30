# Color Clash native content — Phase 09 candidate

These are original project-authored Roblox primitives, native UI, R15 pose clips and synthesized audio. No Creator Store model, external texture, copied layout, image asset or sampled recording was imported. The two arenas are content candidates, not an accepted Phase 09 release: see `docs/CODEX_CONTENT_REPORT.md` for failed and pending gates.

## Tracked imports

| Export | Destination in both Rojo projects |
|---|---|
| `maps/ColorClashMaps.rbxmx` | `ServerStorage.ColorClashMaps` |
| `presentation/ColorClashAssets.rbxmx` | `ReplicatedStorage.ColorClashAssets` |
| `ui/ColorClashUI.rbxmx` | `StarterGui.ColorClashUI` |
| `staging/ColorClashStaging.rbxmx` | `Workspace.ColorClashStaging` |
| `animation_sources/AnimationSources.rbxmx` | Publishing source only; excluded from both runtime projects |

Rebuild models and UI with `lune run tools/build_content`. Rebuild the 34 original WAVs with `tools/.venv/Scripts/python.exe tools/content/audio.py`. Run `lune run tools/validate_content` and `powershell -ExecutionPolicy Bypass -File tools/verify.ps1` afterwards. Map geometry changes require a new MapVersion and fresh Studio-derived counts in `map_counts.json`; never estimate those counts.

Prefer the existing Rojo connection on port 34872 for Studio updates. If map synchronization fails, `python tools/prepare_map_import.py` assembles a maps-only fallback in `build/import_maps.luau`; it never imports scripts or replaces UI/assets. Reconnect the Studio Rojo plugin after any fallback import. Use Claude's unchanged `tools/content/sightline_scan_claude.luau` in Edit mode for both ground and elevated map acceptance.

## Identity and permission record

- Native content: authored in this repository for Color Clash; no remote ID or external loading permission is needed.
- Audio: 34 mono PCM WAVs, 22,050 Hz; deterministic synthesis with no third-party samples. Per-file purpose, duration and publication state are in `audio_manifest.json`.
- Animations: 26 original R15 KeyframeSequences, keyed by name. Timing and loop flags are in `docs/qa/phase-09/export-audit.json`. No root translation or marker-driven damage.
- Published asset IDs: **none**. `Animations` and `Sounds` are intentionally empty, with `PublicationStatus = SOURCE_ONLY_UPLOAD_REQUIRED`. The source clips are not a substitute for playable published Animations.
- Intended publisher: experience owner group **506801379**, universe **10768629864**, place **130101797221207**. This is an intended destination, not evidence that upload permission has been granted or playback has passed.
- The Edit-mode upload attempt for `Glide` returned `CreateAssetAsync and CreateAssetVersionAsync are not available yet`. Nothing was uploaded by that attempt.

## Complete publication later

Upload the original clips and WAVs under the experience owner through an available authenticated Roblox publishing workflow. Record each returned real ID, creator, permission grant, source file, upload date and target-place load result. Add Animation/Sound instances using the exact contract keys to the content builder, then regenerate the `.rbxmx`; Studio-only edits will be lost on rebuild. Retain default Roblox locomotion until replacement clips are published and reviewed. Verify playback and moderation status in the target live experience before changing the Phase 09 status.

Claude added dispatch for the extra effects, sounds and animation keys during Phase 10. Animation/audio playback remains pending the owner's publication of genuine IDs. Existing warning/range/paint rendering remains code-owned.
