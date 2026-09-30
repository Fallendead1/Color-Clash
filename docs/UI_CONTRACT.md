# UI_CONTRACT — Color Clash production UI (ContractVersion 1)

**Audience:** Codex, building the native production ScreenGui.
**Enforced by:** `src/shared/UI/UIContract.luau` (validation) and `src/client/Controllers/UIController.luau` (adapter).
**Reference implementation:** the development wireframe in `src/client/UI/Wireframe.luau`. It is flagged
`IsWireframe = true` and is not final art.
**Tests:** client `UIPanels` (UI-04/05/06/08/10), `UIInput` (UI-01), `ManualModalDeath` (UI-09), `ManualMapLaunch` (UI-07).

## 1. Root

- A `ScreenGui` named **`ColorClashUI`** in `StarterGui`. It is copied to PlayerGui, and the adapter finds it there
  at client start.
- Set `ResetOnSpawn = false`.
- Set `ContractVersion = 1`, and `IsWireframe` must be absent or false.
- Use `ScreenInsets = CoreUISafeInsets` (or `DeviceSafeInsets`) so safe areas and cutouts are respected.

**Binding.** Controls are bound **only by their unique `UIKey` attribute**, never by name or hierarchy path.
Rearranging, renaming or nesting is safe.

**Validation.** The adapter validates the root before using it: every mandatory key present, correct classes, no
duplicate actionable keys. If validation fails, it disables that UI, uses the wireframe, and warns with the first
error. Player attributes `CCUIWireframe` / `CCUIErrors` show the result.

**Hot swap.** `UIController.adopt(gui)` swaps to a new root without restarting. Button handlers, touch bindings and
settings rows are rebound by key.

## 2. Key kinds

| Kind | Allowed classes |
|---|---|
| `button` | any `GuiButton` (TextButton/ImageButton) |
| `text` | `TextLabel` / `TextButton` / `TextBox` |
| `frame` | any `GuiObject` |
| `image` | `ImageLabel` / `ImageButton` |
| `scroll` | `ScrollingFrame` (use a UIListLayout or UIGridLayout; code sets `LayoutOrder`) |
| `template` | a hidden `GuiObject` that code clones into a list (the clone loses its UIKey) |

## 3. Mandatory keys (GDD 12.3)

- `Loading.Root/Stage/Retry`
- `Staging.Root/Ready/Unready/Status`
- `Armory.Root/KitList/Equip/Close`
- `Controls.Root/Close`
- `HUD.Root/Timer/CoverageA/CoverageB/Neutral/Paint/Health/Reticle/Gadget/Ultimate`
- `Touch.Primary/Secondary/Glide/Jump/Gadget/Ultimate/Map`
- `Map.Root/Image/TargetList/ConfirmLaunch/Close`
- `Scoreboard.Root/TeamA/TeamB`
- `Elimination.Root/Countdown`
- `Results.Root/Outcome/Coverage/Stats`
- `Settings.Root/Close`
- `Notices.Root`

Classes are listed in `UIContract.Mandatory`.

## 4. Optional keys (bound when present; the wireframe has all of them)

| Key | Kind | Behaviour driven by code |
|---|---|---|
| `Staging.Play`, `Staging.OpenArmory/OpenControls/OpenSettings` | button | open panels / ready |
| `Staging.Kit` | text | equipped kit name |
| `Staging.Onboarding`, `Staging.OnboardingDismiss` | frame, button | first-use guidance; dismissal is saved |
| `Loading.Back`, `Loading.Detail` | button, text | recoverable failure path and the real stage detail (no fake percentages) |
| `Armory.KitTemplate` | template **TextButton** | one card per kit; code sets `Text` and handles `Activated` (selects the card) |
| `Armory.Detail`, `Armory.Status` | text | the selected kit's full behaviour; equip pending/result/locked |
| `Controls.Text` | text | device-specific bindings |
| `HUD.PaintFill`, `HUD.HealthFill`, `HUD.UltimateFill` | frame | code sets `Size.X.Scale` 0..1; the parent meter gets a `Value` attribute |
| `HUD.PaintText/HealthText/UltimateText/GadgetText/CoverageText/Kit/ReticleState/Callout/Shield` | text | live readouts |
| `Touch.Root` | frame | code shows it only for touch players in a match |
| `Map.TargetTemplate` | template **TextButton** | one per launch target; the attribute `LaunchTarget` = teammate UserId or `"Base"` |
| `Map.Status` | text | launch state and the specific rejection reason |
| `Scoreboard.Header` | text | contribution explanation (never implies kills decide the winner) |
| `Scoreboard.RowTemplate` | template text | one row per participant; code sets `Text`, `LayoutOrder`, `TextTruncate` |
| `Elimination.Attacker` | text | attacker and weapon, or environmental |
| `Results.CoverageText`, `Results.CoverageFillA/B` | text, frame | frozen totals; fills sized by share |
| `Results.StatRowTemplate` | template text | personal/participant stats |
| `Settings.List` + `Settings.RowTemplate` | scroll, template | **the row template must contain a TextLabel `Name` and a GuiButton `Value`**; code builds one row per preference and cycles values on `Value` activation. A custom UI may instead call `SettingsController.set(field, value)` from its own sliders/toggles. |
| `Settings.Status` | text | Saving… / Saved / Couldn't save / read-only |
| `Notices.Template` | template text | short, rate-limited notices |
| `Intro.Root/Title/Count` | frame, text | map name, team and 3-2-1 |

## 5. Behaviour contract (owned by code; keep it working)

**Buttons**
- Every button goes through one guarded handler: extra activations while pending are ignored, so Equip and Ready
  cannot double-submit.
- The code sets attributes `Pending`, `Disabled` and `Pressed` (touch). Style those states: idle, hover/focus,
  pressed, disabled, pending and error.

**Panels:** `Armory`, `Controls`, `Settings`, `Map` and `Scoreboard` are a stack.
- Opening one switches input to the Menu context, so combat input is ignored.
- Closing restores Gameplay, and the click that closed the panel never fires a shot.
- Gamepad B (`Cancel`) closes the top panel.
- On gamepad, the first visible keyed button in the panel is selected once the panel is laid out.

**Touch**
- `Touch.*` buttons are held actions: press/release is forwarded, and multi-touch is supported.
- Keep them at least 48 px, non-overlapping at 740×360, and away from the aim area.
- Fire should be 80–96 px.

**Death:** the tactical map closes on death. Other panels stay on the stack, and the elimination screen shows.

**Text** comes from `src/shared/UI/Strings.luau`. Restyle freely but keep the meaning.

## 6. Layout acceptance

The wireframe passes these at 1920×1080, 1366×768, 1280×720, 1024×768, 844×390 and 740×360 (`UIPanels` UI-05):
buttons on screen, at least 48 px, touch cluster not overlapping, text scaled/wrapped.

Codex must re-run the same checks on the production UI, plus:
- long names, 30% longer text, 8-player scoreboard/results and an empty roster;
- physical-device checks: UI-02 real multi-touch, UI-05 on real phones.

These physical-device checks are **not** proven by the wireframe.
