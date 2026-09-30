# MAP_CONTRACT — Color Clash arena content (ContractVersion 1)

**Audience:** Codex, building **Switchyard** and **Canopy Courts**.
**Enforced by:** `src/server/Map/MapLoader.luau` and `src/shared/Config/MapManifest.luau`.
**Binding rules:** GDD 09.1–09.5 (the design brief), plus the mechanical rules below. A map that breaks any of them is
rejected before a match starts, with a precise report.
**Tests:** `engine:MapContract` (MAP-02/03/04), `perf:RoundSoak` (FLOW-14).

## 1. Delivery

- Place each map as a **Model** under `ServerStorage.ColorClashMaps`, tracked as `.rbxm`/`.rbxmx` in the repo.
  Rojo does not map `ServerStorage` today; add the mapping in `default.project.json` and `production.project.json` in
  the same commit, and record it in `CODEX_HANDOFF.md`.
- There is exactly one model per slot. Any other model is skipped with a `MapSkipped` diagnostic.

| Slot `MapId` | DisplayName | Footprint (X × Z) | Team base centres | Rotation order |
|---|---|---|---|---|
| `switchyard` | Switchyard | 240 × 160 | X = −108 (A), +108 (B), Z = 0 | 1 |
| `canopy_courts` | Canopy Courts | 220 × 180 | X = −98 (A), +98 (B), Z = 0 | 2 |

The rotation alternates between the slots. Team A is on −X and Team B is on +X.

## 2. Root model

| Attribute | Type | Rule |
|---|---|---|
| `MapId` | string | one of the slot ids above |
| `MapVersion` | number | increase on every change that affects collision, surfaces, spawns or volumes |
| `ContractVersion` | number | `1` |
| `DisplayName` | string | optional; defaults to the MapId |
| `ExpectedScoringCells` | number | **required**; must equal the loader-derived count |
| `ExpectedWallCells` | number | **required**; must equal the loader-derived count |
| `ExpectedPatches` | number | **required**; the number of paint surfaces |
| `IsFixture` | bool | must be absent or false (fixtures never enter the production rotation) |

**How to get the three counts.** Load the map once in Studio with the attributes absent. The loader rejects it and
reports each derived value, e.g. `manifest attribute ExpectedScoringCells missing (derived value 31234)`. Copy those
values into the attributes. After that, any geometry change that alters the counts is caught.

## 3. Required folders

| Folder | Contents |
|---|---|
| `Geometry` | Every collidable gameplay part: floors, walls, cover, canopies, perimeter. Anchored and static. Used for collision, line of sight, paint visibility and camera collision. |
| `PaintSurfaces` | One BasePart per paintable patch (section 4). These parts are also geometry. |
| `Spawns` | Exactly 4 BaseParts with `Team = "A"` and 4 with `Team = "B"`. Each part's CFrame is the spawn pad (the character is placed 3 studs above it, facing the part's LookVector). |
| `Volumes` | One `ProtectedBase` volume per team (`VolumeKind = "ProtectedBase"`, `Team = "A"/"B"`) and at least one `VolumeKind = "OutOfBounds"` volume. Volumes are made non-collidable and non-queryable at load. |
| `Markers` | `StagingReturn` (a BasePart) is required. |
| `Decor` | Anything purely visual. It is made non-queryable and non-touchable at load, so it can never become a paint target or a hitbox. **Decor must not block routes, cover or sightlines that the gameplay geometry does not also define.** |

## 4. Paint surfaces

Each `PaintSurfaces` BasePart carries these attributes:

| Attribute | Values |
|---|---|
| `SurfaceId` | unique, stable string (it is referenced in replication; keep it across map versions) |
| `Face` | `Top`, `Front`, `Back`, `Left`, `Right` (the paintable face of the part) |
| `SurfaceKind` | `Floor`, `Ramp`, `Wall`, `Base` |
| `Scoreable` | bool: floors and ramps that count toward the result |
| `Climbable` | bool: walls that can be paint-climbed |
| `InitialOwner` | optional `1`/`2` for `Base` surfaces (base floors display their team colour) |

**Surface geometry**
- Face dimensions are whole studs. Each cell is 1 × 1 stud.
- Walls, ceilings and faces pointing down are never scoreable.
- Ramps must be 30° or less.

**Legal cells (masks)**
- The loader probes the space 0.1–0.9 studs in front of each cell. Any geometry there makes the cell illegal (DECISIONS
  D-008). Close off the space under raised structures physically, with a solid fill.
- Scoring cells inside a protected-base volume are masked.

**Rejected outright**
- Two scoring surfaces stacked in X/Z (legal cells more than 1 stud apart vertically), such as a hidden floor under a
  platform.
- Legal cells inside an `OutOfBounds` volume.
- A climbable face whose top edge leads into an `OutOfBounds` volume (no mantle onto an out-of-bounds roof).

**Budgets:** at most 50,000 scoring cells, 16,000 wall cells and 96 patches.

## 5. Spawns and bases

- Each spawn lies inside its own team's protected base.
- Each spawn has 3 × 5.5 × 3 studs of clear space above the pad.
- Spawns on the same side are at least 7 studs apart; closer spawns produce a warning.
- **No opposing spawn pair has a direct line of sight at 4.5 studs eye height.** Block it with geometry.
- Enemy players cannot enter a protected base: the server builds per-team collision barriers from the base volumes.
- Shots, blasts, thrown capsules and launches stop at base boundaries.

## 6. Slot validation (MAP-03)

These checks run after a successful load, using the tolerances in `MapManifest`.

| Check | Rule |
|---|---|
| Footprint | Bounds of `Geometry` + `PaintSurfaces` in X/Z are within ±10% of the slot footprint and centred on the origin (±8 studs). |
| Base centres | Each `ProtectedBase` centre is within 8 studs of (∓BaseCenterX, 0). |
| Mirrored area | Legal scoring cells on the A half (X < 0) and the B half (X > 0) differ by at most 3%. |

The GDD's route-timing tests (equal reach to centre within 0.5 s, flank routes usable with a screen in the opening, no
forced 90-stud crossing, Linecaster cannot shoot through canopy supports) are **content tests for Codex's maps**.
Record them with evidence in the Codex handoff.

## 7. Presentation vs gameplay

- The Paint Screen folders `ScreensA` and `ScreensB` are created by code under `Workspace.ColorClashArena`. Do not
  author them.
- Canopies that must block Paintstorm rain are `Geometry`, not `Decor`.
- Non-paintable materials (grating) are `Geometry` without a paint surface. Make them visibly distinct.

## 8. Reproduce

Run `CCTestRequest = "engine:MapContract"` in Studio Play. For a live check, set the map in `ServerStorage.ColorClashMaps`,
start Play with DevGate off (production rotation), and watch the output for `MapLoaded`, or for `MapLoadFailed` with
the first error.
