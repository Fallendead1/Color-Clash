# Engineering Decisions

Each entry: the decision, the reason, the alternatives considered, the measured consequence and the affected tests (GDD 20.1).
GDD values stay authoritative unless a decision here changes them.

## D-001 — Project location is `C:\Color-Clash`

- **Decision:** All work happens in `C:\Color-Clash` (git remote `https://github.com/Fallendead1/Color-Clash.git`, branch `main`).
  The user also referred to `C:\ColorClash`; that path does not exist. `START_HERE.md`, the GDD and the video are in `C:\Color-Clash`.
- **Reason:** It is the only folder that holds the project files; the user confirmed the repository by URL.
- **Affected tests:** ENV-01.

## D-002 — Toolchain pinned through Rokit

- **Decision:** `rokit.toml` pins rojo 7.7.0, wally 0.3.2, selene 0.31.0, stylua 2.5.2, lune 0.10.4 and luau-lsp 1.69.0. No Wally
  packages are used (no `wally.toml`), so there is no `Packages` folder to mistake for installed dependencies.
- **Reason:** GDD 17 Phase 00 asks for an intentional toolchain. Every tool already existed in the local Rokit store; nothing was
  downloaded except Python (D-003).
- **Affected tests:** ENV-02.

## D-003 — Python 3.12 installed for the video tooling

- **Decision:** Installed Python 3.12.10 from winget (`Python.Python.3.12`, user scope, installer hash verified by winget).
  Created the isolated venv `tools/.venv` (git-ignored) with Pillow 12.3.0.
- **Reason:** START_HERE requires a Python/FFmpeg extraction script; only the Microsoft Store alias existed.
- **Alternatives:** Lune scripts with ffmpeg only. Rejected because START_HERE names Python.

## D-004 — Paint renderer: native chunk-merged rectangles instead of EditableImage

- **Decision:** Implement `IPaintRenderer` with a native renderer that greedily merges same-owner cells into rectangles within each
  16×16 chunk and draws them as pooled, non-colliding, non-queryable thin Parts on the registered surface.
- **Reason:** GDD 10.4 prefers an EditableImage atlas but requires proof that the API is permitted in the actual experience.
  Observed in Phase 00 (Studio 0.740.19, place 130101797221207, group-owned) from a client-side call:
  `EditableImage is not accessible. Go to the Security Tab in Experience Settings to enable this API.`
  Enabling it is an experience-security setting on the user's account, and live use also depends on publishing/verification
  requirements that cannot be demonstrated without publishing authorization. GDD 10.4 allows qualifying a bounded native
  alternative against the same accuracy and performance tests.
- **Alternatives:** (a) Ask the user to enable EditableImage and publish a private test. This is still possible later, and
  `IPaintRenderer` keeps it swappable. (b) SurfaceGui frames per rectangle: similar cost with more UI overhead.
- **Consequence:** The renderer must pass PAINT-08/PERF-01 with measured part counts and update times. Only one production
  renderer is built.
- **Measured (Phase 02, desktop Studio):** accurate at every tested cell. Adversarial checkerboard at budget = 65,960
  parts, steady frame p95 equal to the no-paint baseline, +119 MB. Realistic heavy paint = 5,924 parts, +4 MB.
  Renderer work is budgeted at 2.5 ms/frame. Full numbers: `docs/qa/phase-02.md`. Mobile is unmeasured (no device).
- **Affected tests:** PAINT-08, PAINT-09, PERF-01.

## D-005 — Pure logic tested with Lune, engine logic tested in Studio Play

- **Decision:** Deterministic modules (grid math, stamps, scoring, round state machine, team assignment, validation, ballistics)
  live in `src/shared` using string `require("./X")` paths so the same files run under Lune (`lune run tests/run`) and in Roblox.
  Engine and integration tests live in `tests/` (mapped to `ServerStorage.ColorClashTests` in the development project only) and
  run in a Studio Play session through the Studio MCP.
- **Reason:** GDD 17 Phase 01 requires a repeatable runner. Lune gives fast, deterministic runs. Studio Play gives real engine
  behaviour.
- **Affected tests:** all unit tests; FLOW-01..05; SEC-01.

## D-006 — Development vs production Rojo projects

- **Decision:** Dev-only code (TestKit, unit specs, the `paint_lab` fixture, engine test runners) lives in `src/server/Dev`.
  `default.project.json` (development) syncs it with the rest of `src/server`. `production.project.json` excludes it with
  `globIgnorePaths: ["src/server/Dev", "src/server/Dev/**"]`, so test controls, fixtures and test runners cannot ship.
  `tools/verify.ps1` fails if the production build contains dev markers.
- **Why not a separate `tests/` → ServerStorage mapping:** the running `rojo serve` does not hot-reload new project-tree
  nodes. The user prefers not to restart it for routine changes, so new code goes under existing mapped folders.
  `tests/run.luau` (the Lune runner) stays outside the mapped tree.
- **Reason:** GDD 11.5, 09.4 and SEC-01. Test controls must be inaccessible in production.
- **Affected tests:** SEC-01, FINAL-05.

## D-007 — Paintstorm throw preparation

- **Decision:** Paintstorm uses a 0.25 s preparation, the same as Color Burst.
- **Reason:** GDD 08.3 says the beacon uses "the same throw preparation/trajectory" in the paragraph right after Color
  Burst (0.25 s preparation, Splash Can trajectory). This is an interpretation, not a new value.
- **Affected tests:** ABIL-05, ABIL-06.

## D-009 — Shoulder camera only for match participants

- **Decision:** The custom shoulder camera (mouse locked) runs for a participant in Intro/Live/VacancyPause. Staging uses
  the default Roblox camera with a free mouse.
- **Reason:** Staging is menu-driven (Play/Armory/Settings buttons). A locked mouse would make them unusable. During
  the Intro the camera must stay controllable even though firing is disabled (GDD 12.1), so the lock follows the
  camera, not the firing context.

## D-010 — Mantle landing restricted to wall-top height; collision beats minimum camera distance

- **Decision:** A mantle may only land within [root − 1.6, root + 0.3] studs of the current height, after a
  standing-clearance check. The camera never clamps to a minimum distance that would place it inside geometry.
- **Reason:** Found by MOVE-04 and CAM-03 in Studio. Without the window, a mantle vaulted onto an overhang 3 studs
  above the climbable wall, and the camera entered a wall with the player's back to it.

## D-008 — Map legal-cell masks derive from collision

- **Decision:** At map load, a cell is legal only if a 0.6 × 0.6 × 0.8 overlap probe placed 0.1–0.9 studs in front of it
  touches no map geometry. Scoring cells inside protected-base volumes are also masked. Scoring surfaces stacked in X/Z
  (legal cells more than 1 stud apart vertically) reject the map.
- **Reason:** GDD 09.5 requires masks validated against collision. Raycasts cannot detect a part that contains their
  start point, which let floor under a platform stay legal on the first attempt (caught in Studio).
- **Consequence:** Floors beneath raised structures must be physically closed (the fixture adds a solid ramp fill) or
  the map is rejected. Codex's MAP_CONTRACT will state this. A 0.5-thick cover masks the two cell columns it intrudes on.
- **Affected tests:** MAP-02, MAP-04, PAINT-04, CONTENT-01.
