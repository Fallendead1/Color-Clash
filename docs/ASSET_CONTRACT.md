# ASSET_CONTRACT — Color Clash presentation content (ContractVersion 1)

**Audience:** Codex. This file covers models, animations, effects, audio and icons. Maps are covered by
`MAP_CONTRACT.md` and UI by `UI_CONTRACT.md`.

**Code owns WHEN and WHETHER** things play: timing, gameplay, damage, movement, pooling and budgets.
**Codex supplies WHAT** plays, by key.

**Every asset is optional to the code.** A missing or invalid asset is counted or reported once, and play continues
unaffected. The final content gate still requires all of them (GDD 13.2).

**Tests:** `engine:Presentation` (weapon model contract and binding), client `Presentation` (cue dispatch, bounds,
cleanup).

## 1. Where assets go

```
ReplicatedStorage.ColorClashAssets         (Folder; track as .rbxm/.rbxmx; add the Rojo mapping in the same commit)
  Weapons/<kitId>                          (Model)             bound to the character by the server
  Character/AthleteDescription             (HumanoidDescription) appearance of the shared athlete
  Animations/<Key>                         (Animation)          played by PresentationController
  Sounds/<Key>                             (Sound)              played by PresentationController
  Effects/<Key>                            (Model | BasePart | Attachment with emitters)
```

Every published asset needs a real, accessible asset ID with an owner/permission record, purpose and licence note, and
a tested load status in the live experience (GDD 13.3). **Never invent IDs.**

## 2. Weapons (`src/server/Presentation/WeaponModels.luau`)

The kit ids are: `sprayline`, `twin_jets`, `lane_roller`, `linecaster`, `splash_pot`, `street_sweeper`, `popshot`.

**Every weapon model**
- Attributes `AssetKey = <kitId>` and `ContractVersion = 1`.
- An Attachment **`Grip`** in the handle part.

**Per class**

| Class | Kits | Required attachments |
|---|---|---|
| Ranged | `sprayline`, `linecaster`, `splash_pot`, `popshot` | `Muzzle` |
| Melee | `lane_roller`, `street_sweeper` | `EffectOrigin` (contact/effect marker) |
| Twin Jets | `twin_jets` | child Models `Left` and `Right`, each with its own `Grip`; muzzles `MuzzleL` (in Left) and `MuzzleR` (in Right) |

**Binding**
- The server clones the model into the character as `CCWeaponModel`.
- It aligns `Grip` to `RightGripAttachment` (Twin Jets: `LeftGripAttachment` and `RightGripAttachment`) with a
  RigidConstraint.
- It forces every part to Massless, non-colliding, non-queryable, non-touchable and unanchored. **Weld all other parts
  of the model to the handle yourself.**
- The character attribute `CCWeaponModel` = kit id, `missing`, `invalid` or `unmounted`.

**Rules**
- Cosmetic parts are never hitboxes. Damage uses fixed server capsules (5.5 tall, 1.4 radius).
- Muzzle positions are presentation only: the server validates shot origins against its own muzzle estimate.
- Budget: about 8,000 triangles or fewer per equipped weapon.

**Throwables:** visuals for the Splash Can, Color Burst capsule and Paintstorm beacon are Effects keys (section 5).

## 3. Character

- `Character/AthleteDescription` (HumanoidDescription) supplies the look. The server always forces unit height,
  width, depth and head scales, and body type/proportion 0, so every player keeps an identical hitbox. Accessories
  must not change collision.
- **Team readability:** read the character attribute `CCTeam` (1/2), and the local palette choice from the player
  attribute `CCPalette` (`standard`/`accessible`). Use shapes and outlines as well as colour.
- Budget: about 20,000 triangles.

**Replicated state for presentation (read-only)**

| Attribute | Values |
|---|---|
| character `CCMoveState` | `Standing` / `Gliding` / `Climbing` |
| character `CCLifeId` | current life id |
| player `CCAlive` | bool |
| player `CCWeapon` | equipped kit id |

## 4. Animations (`src/client/Controllers/PresentationController.luau`)

Default Roblox locomotion (idle/walk/jump/fall) stays unless Codex replaces the `Animate` script content. The keys
below are played by code.

| Key | When | Looped |
|---|---|---|
| `Glide`, `Climb` | while `CCMoveState` is Gliding / Climbing | yes |
| `Attack_<kitId>` | each attack: local send; remote Shot/Volley/Flick/Sweep cues | no |
| `ChargeHold`, `ChargeRelease` | Linecaster charge start / release | no |
| `Dash` | Twin Jets dash | no |
| `Throw` | gadget/ultimate throw | no |
| `UltPrep` | ultimate preparation | no |
| `Gadget` | local gadget use (screen placement) | no |
| `Mantle` | local mantle over a climb top | no |
| `Eliminated`, `Spawn` | any player's `CCAlive` false / true | no |

Markers such as `Windup`, `Fire`, `Recover` and `Footstep` may be added for presentation sync. **They never gate
damage**: the server uses the configured attack times in `src/shared/Config/Weapons.luau`. A retiming requires a
config change and a re-run of `engine:Weapons`.

## 5. Effects and sounds

| Cue (server `Effect` remote or local action) | Sound key | Effect key |
|---|---|---|
| Shot / Volley (per kit) | `Shot_<kitId>` | `Muzzle_<kitId>` |
| Linecaster release | `ChargeFire` | `Beam` |
| Charge start | `ChargeStart` | — |
| Dash | `Dash` | `DashWake` |
| Roller flick / brush sweep | `Melee_<kitId>` | — |
| Blast / burst (Popshot, Splash Can, Color Burst) | `Burst` | `Burst` |
| Throw | `Throw_splash_can`, `Throw_color_burst`, `Throw_paintstorm` | — |
| Ultimate preparation | `UltPrep_color_burst`, `UltPrep_paintstorm` | — |
| Storm active | `Storm` | `Storm` |
| Storm beacon fizzled | `Fizzle` | `Fizzle` |
| Team Launch landing marker (enemy-readable) | `LaunchMarker` | `LaunchMarker` |
| Hit confirm / shield hit (owner) | `UI_HitConfirm` / `UI_ShieldHit` | — |
| Elimination | `Eliminated` | — |
| Respawn (local) | `Spawn` | — |
| Final 30 seconds / round end | `UI_FinalCue` / `UI_RoundEnd` | — |
| Intro 3-2-1 / Live start | `UI_Countdown` / `UI_RoundStart` | — |
| Local glide (loop while gliding; refill is felt through it) | `GlideLoop` (looped) | — |
| Dry shot (server "dry" rejection) | `EmptyClick` | — |
| Paint below 20 (on crossing) | `UI_LowPaint` | — |
| Paint Screen hit / destroyed | `ScreenBreak` (on destroy) | `ScreenHit` / `ScreenBreak` |

**Effect templates**
- Optional attributes: `Lifetime` (seconds, default 1.5, maximum 10) and `Burst` (particles to `Emit`).
- Parts are anchored and non-colliding.
- Objects are cloned at the cue position and destroyed after `Lifetime`.

**Sounds**
- Optional attribute `Lifetime`.
- Sounds play in SoundGroup `CCSfx`, except `UI_*` keys, which play in `CCUi`. Keys with a position are 3D.
- The player's Music/SFX volume settings drive the groups `CCMusic` / `CCSfx`.

**Concurrency and readability**
- At most 64 transient presentation objects exist at once; extra requests are dropped and counted.
- The wireframe effects (`EffectsController`) remain as a fallback.
- **Warnings stay readable at low quality:** thrown-capsule warnings, storm area and launch marker must not be hidden
  by decorative particles (GDD 13.4). Paint ownership colour always comes from the palette, never from effects.

## 6. Icons and glyphs

The Armory, HUD and Map icons are part of the production UI (`UI_CONTRACT.md`). The contract requires:
- seven weapon icons, two gadget icons and two ultimate icons;
- input glyphs for keyboard/mouse, gamepad and touch;
- team markers, reticles, shield/connection/error indicators, and map representations.

## 7. Content inventory

This is the GDD 13.2 list with the code hook for each item.

| Area | Items | Code hook status |
|---|---|---|
| World | Switchyard; Canopy Courts; staging area; cover/ramps/climb panels/boundaries/spawn presentation | Loader + slot contract ready; contract fixtures used for tests |
| Character | athlete rig, team-readable materials, Paint Tank visual, glide presentation | AthleteDescription hook; CCTeam/CCMoveState attributes; Glide loop key |
| Weapons | 7 models (Twin Jets left/right), 2 gadget visuals, 2 ultimate visuals | WeaponModels binder + validator; throwable/storm/screen effect keys |
| UI | 13 screen groups, icons, glyphs, markers, reticles, indicators, map | UI contract + adapter + wireframe |
| Animations | locomotion (default Animate), jump/fall, glide, climb/mantle, holds/attacks, charger, dash, roller/brush, throw/place, ult prep, elimination, spawn | all keys wired (section 4); weapon hold poses ride on `Attack_<kitId>`/locomotion or a replaced Animate script |
| Effects | muzzle/impact, paint readability, shield hit, low paint, charge ready, dash wake, screen damage/break, grenade warning/explosion, storm, launch marker/transit/landing, results cue | all keys wired (section 5); paint colour is the palette, not an effect |
| Audio | per-weapon fire/charge/empty/impact, glide/refill, gadget/ultimate, shield, elimination, spawn, countdown, final 30 s, round end, UI feedback | all keys wired (section 5) |

New keys are small code additions in PresentationController and need no gameplay change. Request them through the
handoff.
