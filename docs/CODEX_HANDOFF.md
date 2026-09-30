# CODEX_HANDOFF — Claude → Codex (HANDOFF-01)

**Status:** `CODE_READY_FOR_CODEX` — the code, fixture and contract phases 00–08 are complete. This is **not** a
game-complete or release claim: final acceptance needs Codex's production content (Phase 09) and Claude's
verification afterwards (Phase 10).

| Item | Value |
|---|---|
| Repository | https://github.com/Fallendead1/Color-Clash.git, branch `main` |
| Code commit | recorded in section 7 of this file (it names the commit it was written against) |
| Contracts | `docs/MAP_CONTRACT.md`, `docs/UI_CONTRACT.md`, `docs/ASSET_CONTRACT.md`; each is ContractVersion 1 |
| Place | Color Clash (placeId 130101797221207) |
| Rojo | `rojo serve default.project.json` (port 34872 in this setup). Production build: `production.project.json` excludes all `Dev` folders. |
| Toolchain | Rokit (`rokit.toml`): rojo 7.7.0, lune 0.10.4, selene 0.31.0, stylua 2.5.2, luau-lsp 1.69.0 |

## 1. Rules for the shared project (GDD 13.5)

- **One folder, one branch, one Rojo/Studio session, and one agent at a time.** Read this file, `git log`,
  `git status` and the Rojo mapping before editing.
- **Do not rewrite gameplay, networking, saves or match flow.** That covers the paths below; ask Claude through the
  handoff instead.
  - `src/server/Services/*`
  - `src/server/Combat/*`
  - `src/shared/{Config,Paint,Combat,Round,Movement,Protocol,Settings}`
- **Where Codex content goes (all tracked):**
  - `ReplicatedStorage.ColorClashAssets` (models, animations, effects, sounds, athlete description)
  - `ServerStorage.ColorClashMaps` (the two maps)
  - `StarterGui.ColorClashUI` (production UI)
  - Export them as `.rbxm`/`.rbxmx` and add the Rojo mappings in the same commit.
- Studio-only changes do not flow back into Git on their own.
- Record every external asset ID with its owner/permission, purpose, licence and tested load status. **Never invent
  IDs.**

## 2. What Codex builds

The complete inventory, with the code hook for each item, is in `ASSET_CONTRACT.md` section 7.

- **Maps:** Switchyard (`switchyard`) and Canopy Courts (`canopy_courts`), to GDD 09.1–09.3 and `MAP_CONTRACT.md`.
  Include the manifest attributes. Both must load in the production rotation with no errors.
- **UI:** the native production UI, to `UI_CONTRACT.md`. It must pass contract validation, so the adapter adopts it
  instead of the wireframe.
- **Presentation:**
  - 7 weapon models with their Grip/Muzzle attachments;
  - the athlete description;
  - animations, effects and sounds by the keys in `ASSET_CONTRACT.md`;
  - icons and glyphs.

## 3. How to check your content

| Check | How |
|---|---|
| Map contract | Put the map in `ServerStorage.ColorClashMaps` and Play with no dev overrides. The output shows `MapLoaded`, or the first error; engine diagnostics record `MapLoadFailed`. |
| UI contract | Play and read player attributes `CCUIWireframe` (must be false) and `CCUIErrors` (must be 0). The client spec `UIPanels` re-runs layout at 6 viewports on whichever UI is active. |
| Weapon models | Character attribute `CCWeaponModel` = kit id. `engine:Presentation` shows the expected shape. |
| Presentation keys | `PresentationController.stats().missing` lists every key that was requested but absent. |
| Full regression | `tools/verify.ps1`, then Studio: `CCTestRequest = "engine"`, `CCClientTestRequest = "all"`, and `perf:RoundSoak` (set `DevGate ContractFixtures` off, so the production maps rotate). |

## 4. Fixture evidence (what has actually run)

All results come from desktop Studio on this machine. They use code-built fixtures (`paint_lab`, `stress_lab`, and
the contract fixtures for both slots), solo practice, and at most 3 real local clients. **None of it is evidence about
the production maps, production UI or devices.**

- `tools/verify.ps1`: Luau syntax, Lune unit 66/66, selene clean, dev and prod builds, prod contains no dev code,
  client-surface scan clean.
- Studio engine suite: 13 specs (see `docs/qa/phase-08.md` for the latest count). The count covers:
  boot, combat, all 7 weapons, abilities/launch, map contract, movement, paint engine/sync, preferences, hardening,
  presentation, round lifecycle and end-of-run health.
- Client suite: UI contract/input, UI panels (gamepad, 6 viewports, long text, notices, production-UI swap), and
  presentation.
- Real-client manual specs:
  - weapons (dash, charge cancel, gadget);
  - movement/climb/camera;
  - map/launch (Base launch through the real remote);
  - death during panels;
  - latency 50–600 ms RTT (simulated);
  - adversarial floods;
  - combat load.
- Multi-client (Phase 04): 2- and 3-client fights, late join, vacancy pause, NoContest.
- `perf:RoundSoak`: 20 rounds alternating both contract fixtures, all 7 kits. No leaks, memory flat, 0 hash
  mismatches.
- `perf:WeaponMatrix`: numerical balance matrix (`qa/phase-05.md`).

Per-phase reports are in `docs/qa/phase-01.md` … `phase-08.md`. The complete matrix, with the level for each ID, is in
`docs/QA_MATRIX.md`.

## 5. Pending — must not be reported as passed

| Area | Tests | Why pending |
|---|---|---|
| Production content | FINAL-01, CONTENT-01..08, map-specific route/timing tests, UI on production UI, all presentation keys | needs Codex Phase 09 |
| Multi-client | COMBAT-05/07, COMBAT-06 assists, FLOW-11 replacement in grace, FLOW-13 reconnect mid-state, ABIL-07/09 teammate launch and target death, NET-07 moving-player rewind | needs a Studio local-server session with 2–3 clients on the same team (the user starts it) |
| Eight clients | PERF-02, NET-04/08 at 8 clients | this machine has 15.9 GB RAM and about 0.8 GB free with Studio |
| Devices | PERF-04, UI-02 multi-touch, UI-05 physical, FINAL-02 | no physical phone or tablet available |
| Saves | DATA-01 on the real DataStore path | Studio API access is disabled for the place; enable it, or test in a published private server |
| Publishing | FINAL-03 published smoke test, asset permissions in the live experience | publishing not yet authorized |
| Human play | readability and fun observations (GDD 07.5) | needs real players |

## 6. Known limitations (by design or deferred)

- Paint is rendered with native parts (EditableImage is disabled for this experience; D-004). Renderer budgets were
  measured on desktop only.
- Team Launch transit keeps the character anchored in place and invulnerable (D-011). Codex's transit presentation
  goes on top of this.
- The optional practice context was not built; the GDD marks it optional.
- Balance values are the GDD starting specification plus measured matrices. No tuning has been applied without
  human playtests.

## 7. Code commit for this handoff

This file was written against the Phase 08 code commit shown by:

```
git log --oneline -3
```

The first line of that log is `Phase 08 docs: contracts and Codex handoff (CODE_READY_FOR_CODEX)`. The line below it,
`Phase 08 PASS_CODE: ...`, is the exact code commit whose evidence is summarised here. Record both hashes in the Codex
report when you start.
