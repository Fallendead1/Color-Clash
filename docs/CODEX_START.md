# Message to start Codex (paste this as Codex's first prompt)

> Read `C:\Color-Clash\Color_Clash_Master_GDD.md`, then `docs/IMPLEMENTATION_STATUS.md` and `docs/CODEX_HANDOFF.md`,
> before editing. Also read the three contracts, `docs/MAP_CONTRACT.md`, `docs/UI_CONTRACT.md` and
> `docs/ASSET_CONTRACT.md`.
>
> **Where to work.** Continue in the same project folder `C:\Color-Clash`, repository
> https://github.com/Fallendead1/Color-Clash.git, branch `main`, and the existing Rojo/Studio setup
> (`rojo serve default.project.json`, Studio place "Color Clash"). Do not start a second project. Do not overwrite
> gameplay code (`src/server/Services`, `src/server/Combat`, `src/shared/*`).
>
> **What you own: Phase 09.** Create and directly implement:
> - the two original arenas, Switchyard and Canopy Courts;
> - the normalized athlete character;
> - the seven weapon models;
> - gadget and ultimate assets;
> - animations;
> - the production native UI;
> - icons, VFX and authorized audio.
>
> Follow the asset, map and UI contracts exactly. Preserve IDs, attachments, timings and code-owned behaviour.
>
> **Where content goes.**
> - `ServerStorage.ColorClashMaps` (maps)
> - `StarterGui.ColorClashUI` (UI)
> - `ReplicatedStorage.ColorClashAssets` (models, animations, effects, sounds)
>
> Export each as tracked `.rbxm`/`.rbxmx` files and add the Rojo mappings in the same commit.
>
> **Testing and records.**
> - Test your content with the checks in `CODEX_HANDOFF.md` section 3.
> - Keep within the budgets.
> - Record real asset IDs and permissions; never invent IDs.
>
> **Out of scope.** Do not add shops, cosmetic systems, ranked, PvE or any other excluded feature.
>
> **Finish** with a complete content report and commit. Then return the project to Claude for Phase 10 integration
> verification.

Notes for the person running Codex:
- Only one agent works in this folder at a time. Claude has stopped. Resume Claude after Codex with the GDD 20.4
  message.
- Keep Studio's Rojo plugin connected to the same `rojo serve` on port 34872. If that server was started by a Claude
  session and has stopped, run `rojo serve default.project.json --port 34872` from `C:\Color-Clash`.
