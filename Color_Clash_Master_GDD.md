# COLOR CLASH
## Master Game Design Document · Core PvP Release

**Version:** 1.0  
**Prepared:** 29 September 2026  
**Working game title:** COLOR CLASH  
**Mode:** Color Control  
**Implementation owner:** Claude — code, gameplay logic, integration, testing  
**Content owner:** Codex — maps, models, animations, UI layouts, icons, visual effects and audio assets  
**Release objective:** A complete, repeatable, cross-platform paint-territory PvP game. Nothing beyond that scope.

> **The instruction that governs this entire project:** Build the core game, test every phase, fix failures, and continue without asking for routine review or permission. Do not substitute a feature checklist, a good-looking map, or an error-free console for a working multiplayer game. Claude owns the code. Codex owns the authored content. Final acceptance requires both to work together.

---

## 00. Read this first: authority, scope and honesty

### 00.1 What this document is

This is an implementation-ready design for an **original Roblox paint-territory shooter**, not a description of every system in Splatoon and not a claim to reproduce Nintendo's code or exact balancing. It preserves the recognizable loop: choose a loadout, paint territory, fight for control, travel through your own color, refill paint, respawn, and win on territory.

**All numbers, weapon names, map dimensions, damage values, test budgets and workflow decisions below are proposed specifications for OUR game.** They are not measurements taken from Splatoon. They are the starting configuration to implement and then validate. Keep tuning values in configuration files; do not bury them in scripts.

Nintendo's official materials establish the reference's paint/swim/combat loop, main/sub/special weapon kits, and variety of weapon types [R01]. Nintendo Support describes standard online battles starting with eight players [R02]. Our target is explicitly **two teams of four**, with a separately specified low-population fallback. Earlier brainstorming is not a second specification.

### 00.2 Source of truth, in priority order

1. The user's explicit core-only scope and division of responsibilities.
2. This GDD's rules, contracts, acceptance tests and approved-in-code configuration.
3. Recorded engineering decisions that preserve this scope and explain a necessary change.
4. The gameplay video, once actually supplied, as a reference for feel and observable behavior.
5. External documentation for current APIs and platform limitations.

A video of an extra mode does not authorize that mode. An earlier suggestion about a shop, a season pass, ranks or mastery does not authorize those systems. A reference game's hidden behavior must not be invented and labeled as observed.

### 00.3 What "finished" means

There are two different milestones:

- **CODE_READY_FOR_CODEX:** All code phases pass against clearly identified fixtures and functional wireframes. Code contracts and content requirements are ready. This is NOT a finished game.
- **CORE_PVP_VERIFIED:** Codex's actual maps, assets and UI are integrated; the full acceptance matrix passes; required device and multiplayer evidence exists; no known in-scope defects remain open.

Tests cannot prove that no possible bug exists. Report exactly what ran, on which build and devices, with what results. Missing access, missing assets, unrun tests and unsupported capabilities are **BLOCKED** or **NOT RUN**, never PASS.

### 00.4 Working title and original identity

COLOR CLASH is a temporary production name, not a claim of name or trademark availability. Use original weapon silhouettes, models, animations, sounds, maps, graphics and branding. Do not import Nintendo assets, trace their maps, reproduce their logos, or present this as an official Splatoon game. Similarity should be in the broad play loop, not copied presentation.

---

## 01. Locked release scope

### 01.1 The whole release in one sentence

**An eight-player, third-person Roblox shooter in which two teams paint an original arena, use their paint for movement and ammunition recovery, and compete to own the largest share of the scoring floor after four minutes.**

### 01.2 Included and required

| Area | Exact release commitment |
|---|---|
| PvP | One mode: Color Control. Target 4v4, with smaller balanced public matches when population is low. |
| Round loop | Join, load, choose loadout, ready, start, fight, finish, show results, reset, repeat. |
| Painting | Persistent per-round ownership; repainting; floors, ramps and designated walls; authoritative territory totals. |
| Movement | Third-person aiming, jumping, Paint Glide, climbing designated painted walls and Team Launch. |
| Combat | Seven main weapons, two gadgets, two ultimates, shared paint ammunition, damage, elimination and respawning. |
| Maps | Two original playable arenas. One separate engineering fixture for testing, not a third content map. |
| UI | Every screen, button, HUD state, touch control, controller selection path, loading state and error state needed for this loop. |
| Player setup | One normalized combat rig and team presentation. All combat loadouts available immediately and for free. |
| Platforms | Desktop keyboard/mouse; phones and tablets in landscape; gamepad controls and a verified console target before advertising console support. No VR. |
| Reliability | Server authority, exploit resistance, reconnect/late-join handling, bounded resource use and graceful failures. |
| Persistence | Settings, selected loadout and onboarding completion only. |
| Testing | Unit, server/client, multi-client, network, UI, device, content-contract and soak tests. |

### 01.3 Explicitly excluded

**Do not build PvE, enemy AI, bosses, a story campaign, events, ranked play, MMR, cosmetics systems, emotes for sale, mastery, titles, XP progression, weapon unlock grinds, shops, currencies, crates, gamepasses, developer products, ads, battle passes, daily quests, trading, replay recording, a custom social hub, or a custom cross-server party/matchmaking service.**

A small safe staging/practice area, a match scoreboard, a tactical map and basic test targets are core usability tools, not those excluded systems. Stationary damage targets do not become an AI mode. Team colors and a standard character model are combat presentation, not an inventory of cosmetics.

Do not create empty "Coming Soon" buttons, background services, databases or placeholder currencies for excluded features. The code may be modular without implementing a future game.

### 01.4 What was intentionally reduced

The reference has more weapon types and much more surrounding content [R01]. This release has **seven complete weapon archetypes, not every weapon variant or every weapon class in the franchise**. That is a deliberate production scope, not an assertion that the reference only has seven. The roster covers the main types already discussed: an automatic shooter, dual weapons, a roller, a precision charger, a lobber, a brush and an explosive launcher.

---

## 02. Reference idea > our specific version

The left column names reference concepts. The right column is the implementation contract for this project. Detailed numbers on the right are our design choices, not source-game data.

| Reference concept | Our version |
|---|---|
| Turf War / inked-territory victory | **Color Control:** highest scoring-floor ownership after 240 seconds. |
| Standard team battle | **4v4 target:** no third team; no 2v2-specific mode. Smaller rounds are population fallbacks. |
| Ink | **Paint:** two team ownership IDs, a neutral state and clear team colors. |
| Inkling/Octoling presentation | **Original Roblox arena athletes:** one normalized R15 combat rig. |
| Swim form in friendly ink | **Paint Glide:** a low paint-skimming stance, not a squid transformation. |
| Ink-covered wall movement | **Paint Climb:** climb only registered walls painted in your team color. |
| Ink tank | **Paint Tank:** 100 units shared by the main weapon and gadget. |
| Main + sub + special kit | **Main Weapon + Gadget + Ultimate:** fixed kits, selected before a round. |
| Super Jump concept | **Team Launch:** a telegraphed transfer to a living teammate or your base. |
| Weapon acquisition/progression | **Free Armory:** all seven kits available immediately; no purchases or stat upgrades. |
| Reference maps and setting | **Switchyard** and **Canopy Courts:** original layouts and original arena-sport art. |
| Splat terminology | **Elimination:** paint-burst presentation, then a four-second respawn. |
| Results reveal | **Coverage Reveal:** authoritative percentages, remaining neutral floor and individual contribution. |
| Reference presentation and branding | **Clean Roblox arena-sport identity:** original shapes, typography, icons, audio and effects. |

**Keep:** territory strategy, weapon tradeoffs, movement through friendly paint, repainting enemy routes, frequent respawns and loadout-based combat.  
**Change:** names, characters, silhouettes, map layouts, art, UI, sound, tuning and the complexity of the surrounding game.

---

## 03. Player experience and round rules

### 03.1 First-time player flow

The player enters a lightweight staging area with **Play**, **Armory**, **Controls** and **Settings**. A default Sprayline kit is already equipped. No mandatory account progression, shopping, cinematic, questionnaire or tutorial course blocks Play.

Show three brief, dismissible instructions: **Paint the floor. Glide in your color to move and refill. Own more floor when time ends.** The local practice surface allows immediate painting and refilling while waiting. An optional stationary target confirms damage and paint cost. Practice activity uses its own PracticeContext and isolated paint buffer, separate from the live MatchId. It never changes a live match, a result, ultimate meter or saved progression. Reuse the same weapon rules against stationary practice targets; do not create a second combat implementation.

Engineering targets: after essential content is ready, a player should be able to move or paint within 10 seconds; once a round starts, a direct route should reach useful contested territory in about 8–12 seconds. Measure those targets rather than assuming the layout achieves them.

### 03.2 Match configuration

| Setting | Starting value / rule |
|---|---|
| Mode ID | `color_control` |
| Server capacity | 8 players; one active match per server. |
| Teams | `A` and `B`, each capped at 4. Names/colors are presentation only. |
| Public minimum | 4 ready players. Begin 2v2 after the countdown rather than waiting forever for eight. |
| Development/private override | 1v1 with two test clients; solo practice with one. Never mislabel either as a full 4v4 test. |
| Countdown | 20 seconds when at least four players are ready; shorten remaining time to 5 seconds if eight become ready. |
| Odd populations | Split 5 or 7 ready players with a team-size difference of one. No team exceeds four. |
| Match length | 240 seconds of live play. |
| Round introduction | 3 seconds after all starting players are placed safely. Combat disabled. |
| Respawn | 4 seconds after elimination; details in Section 06. |
| Results | 10 seconds; no gameplay mutations. |
| Intermission | 15 seconds; reselect loadouts, ready/unready and prepare next map. |
| Map selection | Alternate the two maps. Randomize which is first when the server starts. No map voting UI. |
| Overtime | None. A last-second shot follows the explicit cutoff rule below. |
| Tie | Compare exact area units, not rounded UI numbers. An exact tie is a draw. |

Ready status persists between rounds unless the player selects Unready, leaves, or becomes idle. Cancel a pending start if fewer than four ready players remain. Re-form teams between rounds with a shuffled, reproducible seed; avoid assigning the same side every round. Do not move a living player to the opposing team mid-round to repair balance.

### 03.3 Scoring

Only registered, reachable **scoring floors and ramps** count. Designated walls can be painted and climbed but add **zero** territory score. Spawn pads, protected spawn interiors, decorative surfaces, hidden faces, ceilings, out-of-bounds geometry and test surfaces do not count.

The map publishes a fixed scoring denominator before the round begins. If the map has `N` equal-area valid scoring cells, and A owns `A_cells`:

`A_percent = 100 × A_cells / N`

B is calculated the same way. `Neutral_percent = 100 − A_percent − B_percent`. Display all three so an unfinished map is not falsely presented as 100% claimed. Painting enemy floor transfers ownership; it does not accumulate overlapping ownership. Kills, damage, time held and wall paint do not decide victory.

Use integer area units. For the initial one-stud-square cells, every valid scoring cell contributes one unit. Imported maps that cannot respect this grid must be re-baked or explicitly use tested fixed-point weights; do not silently change the denominator.

The winner is determined from the server's final raw counts. A displayed 47.3% versus 47.3% may still have a winner; show a second decimal when needed and label a true tie **Draw**. Never force the percentages to sum to 100 by hiding neutral territory.

### 03.4 Final-second behavior

The server owns `RoundEndTime`. Damage and paint apply only when an authoritative impact is processed at a simulation time **strictly before** that deadline. A projectile fired before the deadline but hitting afterward does not count. Do not keep the round open waiting for in-flight projectiles. Freeze the grid, cancel remaining combat entities, and use that exact frozen state for all results clients.

The last 30 seconds receive a timer/color/audio cue only. **No double damage, accelerated paint, surprise scoring multiplier or comeback boost.**

### 03.5 Joining, leaving and empty teams

A joining player receives the current map version, round state and paint snapshot before becoming combat-active. During live play, allow backfill with **more than 60 seconds remaining**, putting the player on the smaller team; choose the alternating side on a tie. With 60 seconds or less remaining, keep the newcomer in staging until the next round.

If either team becomes empty, suspend scoring, combat and the round clock for a maximum **15-second real-time vacancy grace**. Permit a replacement during that grace even inside the normal last-minute cutoff. On resumption, shift the authoritative RoundEndTime forward by the actual paused duration and broadcast the new deadline. Resume if both teams are populated. Otherwise show **Round ended — not enough players**, mark `NoContest`, and reset. A NoContest is not recorded as a win or loss.

A reconnect is a fresh join, not a reserved ranked slot. Use available capacity and the same backfill rules. Do not promise reconnection to the same server. Idle players become Unready after 60 seconds without meaningful input; do not claim a technical problem or automatically kick them. A player who remains connected but idle in a live round is flagged in diagnostics; do not silently convert them into a bot.

### 03.6 Round state machine

`Waiting → Countdown → Loading → Intro → Live → Results → Reset → Intermission → Countdown`

`Live ↔ VacancyPause` is the only pause path. Loading failure leads to a recoverable return to Waiting, not a half-started match. Give each round a unique `MatchId`, each loaded map a `MapVersion`, and each character life a `LifeId`. Every delayed callback verifies its relevant IDs before acting.

During VacancyPause, hold players at their pause positions while leaving camera/UI usable; freeze gameplay projectiles, fuses, storms, respawn/launch/protection timers, damage, regeneration and resource accumulation; use the match clock for those timers. On resumption, they continue from their remaining durations. Results/Reset cancel old gameplay entities rather than freezing them for the next round. UI notices and the 15-second vacancy grace use real time. Only RoundService may change round state. UI, weapon scripts and asset scripts must not start their own competing timers or round loops.

---

## 04. Character, controls and camera

### 04.1 Standard combat character

Use one normalized R15 character size for fair reach, sightlines and collision. Codex supplies the original athlete model and team-readable presentation. Claude supplies character setup, movement state and attachment validation. Do not let avatar bundles, hats or accessories enlarge damage hitboxes or obscure enemies.

Starting damage volume: an upright capsule approximately **5.5 studs high and 1.4 studs in radius**, aligned to the authoritative character root. One consistent body target; no headshot multiplier or limb damage in this release. The visual glide stance does not shrink that damage volume or grant invulnerability.

Use a simplified elimination effect rather than long-lived physical ragdolls. Gameplay never waits for an elimination animation to finish.

### 04.2 Camera

Third-person shoulder camera; initial distance 9 studs, vertical offset 2.5 studs, right offset 1.75 studs, default field of view 75 degrees. These are tunable starting values. Provide shoulder swap and sensitivity settings. The camera must avoid clipping through walls and return smoothly after obstruction.

The player always controls look direction during firing, charging, gliding, gadget use and ultimate activation. Do not freeze aim during an animation. Aim toward the crosshair, then trace from the legal weapon muzzle toward that aim point. A blocked muzzle cannot shoot through the wall just because the camera sees around it. Show a blocked-shot indicator rather than silently hitting somewhere unrelated.

Camera shake is optional and can be disabled. Do not add forced camera cutscenes, strong screen tilt, full-screen paint blindness or involuntary spinning.

### 04.3 Semantic input actions

Bind actions through one input layer, not device checks scattered through weapon scripts. Roblox documents an Input Action System for binding actions and contexts [R06]. Confirm the supported API in the actual Studio version before implementation.

| Action | Keyboard/mouse | Gamepad starting binding | Touch behavior |
|---|---|---|---|
| Move | WASD | Left stick | Standard movement stick. |
| Aim | Mouse | Right stick | Drag look region; can be used while holding Fire. |
| Primary | Left mouse | Right trigger | Large holdable Fire button. |
| Secondary | Right mouse | Left trigger | Contextual button only on kits that use it. |
| Paint Glide / Climb | Hold Shift | Hold right bumper | Glide toggle by default; hold mode in Settings. |
| Jump / leave climb | Space | A / platform equivalent | Jump button. |
| Gadget | Q | Left bumper | Gadget button with cost/readiness. |
| Ultimate | E | X / platform equivalent | Ultimate button with fill and ready state. |
| Tactical map / Team Launch | M | Y / platform equivalent | Map button; tap a teammate, then confirm Launch. |
| Scoreboard | Tab | View / available non-system binding | Scoreboard button. |
| Shoulder swap | C | Right-stick click | Settings option; no extra combat button required. |
| Cancel / close panel | Escape where not reserved | B / platform equivalent | Visible Close/Back button. |

Do not override Roblox/platform system menus. Adapt glyphs to the actual controller. Input contexts must prevent firing while interacting with menus and prevent a touch used on a button from also rotating the camera. Release held actions on focus loss, death, respawn, panel changes and round transitions. Never leave a weapon firing because the finger or controller disconnected.

### 04.4 Touch and accessibility requirements

Landscape is the supported mobile orientation. Test left-stick movement, right-thumb aim and held shooting together with real multi-touch. Keep essential touch targets at least **48 logical UI pixels**, with Fire around 80–96 at the reference layout. Respect safe areas, camera cutouts and the platform top bar; use responsive constraints rather than one fixed desktop canvas [R10, R11].

Provide sensitivity, invert-Y, glide hold/toggle, reduced camera effects, separate music/SFX volume and a team-color accessibility palette. Store team ownership as IDs, never as RGB comparisons. Use teammate icons, team labels and outlines in addition to color. Do not rely on red-versus-green alone. A local color preference must recolor all paint, UI and effects consistently without changing the server state.

---

## 05. Paint movement, tank and health

### 05.1 Movement states

`Standing`, `Airborne`, `Gliding`, `Climbing`, `WeaponSecondary`, `LaunchChannel`, `Launching`, `Eliminated`, `SpawnProtected`.

These are controlled states with explicit transitions, not unrelated booleans that can accidentally combine. Spawn protection is a timed modifier alongside a legal locomotion state; elimination and launching override ordinary locomotion. A gadget or weapon action may temporarily restrict an action without taking camera control away.

| Condition | Starting movement rule |
|---|---|
| Ordinary movement | 16 studs/second. |
| Firing a light weapon | 14 studs/second unless its definition overrides this. |
| Gliding on own paint | 26 studs/second; acceleration to glide speed over 0.15 seconds. |
| Holding Glide on neutral floor | 10 studs/second crouched movement; no glide benefit. |
| Standing on enemy paint | 9 studs/second; cannot glide or climb in it. |
| Climbing own registered wall | 14 studs/second; legal upward/lateral motion only. |
| Charger while charging | 10 studs/second. |
| Roller while rolling | 12 studs/second before enemy-paint restriction. |
| Brush while pushing | 22 studs/second before enemy-paint restriction. |

Enemy-floor restriction takes priority over weapon movement bonuses until the supporting cells become friendly. Movement uses authoritative ownership beneath the character. Apply a short, tested boundary hysteresis of about 0.08 seconds to avoid jitter across individual cells; do not create long grace periods that allow free movement across enemy territory.

There is **no passive damage from standing on enemy paint** in this release. It slows the player and prevents refill. This is a deliberate simplification, not a statement about the reference game.

### 05.2 Glide and climb details

Paint Glide is a low skimming stance with a readable wake. It is not full invisibility and never allows movement through solid geometry. Pressing Fire exits glide and returns to a legal firing state within 0.12 seconds. Jumping keeps momentum within configured caps. Hitting a neutral or enemy surface exits powered glide; falling does not leave the avatar flying.

Paint Climb only works on faces explicitly marked climbable and currently owned by your team at the contact samples. Require continuous nearby wall contact, no ceilings, and a maximum designated climb height of 12 studs on release maps. At the top, use a clearance-tested mantle onto a valid landing surface. Jump detaches. Loss of friendly paint or valid contact detaches safely. Do not rotate the whole camera onto the wall.

While climbing, refill at 20 tank units/second after the refill delay. Do not fire without first leaving climb. A ledge without standing clearance must not teleport the player through an obstacle. Dynamic geometry, curved painted meshes and climbing arbitrary decorations are not supported in these first maps.

### 05.3 Paint Tank

Tank capacity is **100**. Main weapon and gadget costs use the same server-owned balance. Ultimate charge is separate.

| Refill condition | Refill rate | Delay after last paint-consuming action |
|---|---|---|
| Own paint + Glide | 30 units/second | 0.35 seconds. |
| Own paint + standing | 12 units/second | 0.65 seconds. |
| Own paint + Climb | 20 units/second | 0.35 seconds. |
| Neutral floor + standing | 6 units/second | 1.25 seconds. |
| Enemy paint, active charge, roll/push or airborne | No refill | Not applicable. |
| Protected base, not firing | 50 units/second | Immediate. |

No manual magazine reload. Show a low-paint warning below 20 units. Costs are charged atomically when the server accepts the shot, throw release or screen placement; continuous actions deduct by authoritative elapsed time. A canceled gadget preparation before release costs no paint, while ultimate meter follows its separately defined activation rule. A rejected dry shot consumes nothing, creates no authoritative projectile and uses a quiet rate-limited cue, not a spammed popup. Continuous actions stop cleanly before the tank becomes negative. Prediction is visual; the server decides the balance.

### 05.4 Health and regeneration

Health is 100. No friendly fire, self-damage, fall damage from ordinary map heights, headshot bonus or permanent wounds. Opposing characters do not physically shove or trap each other; use a consistent character collision policy while retaining server damage capsules. After 3 seconds without taking damage, regenerate at 20 health/second. New damage resets that delay. Paint ownership does not change the regeneration rate. Out-of-bounds recovery is an elimination, not normal fall damage.

All players, weapons and visual quality settings use the same damage rules. No unlock, purchase or platform grants more health, stronger paint or a larger hitbox.

---

## 06. Combat fundamentals and respawning

### 06.1 Rules that every weapon shares

Every weapon specifies a legal fire cadence, paint cost, damage rule, range, trajectory, paint footprint and action locks. The server owns shot acceptance and uses one damage path. The client requests an action; it does not submit a trusted damage value, winner, paint total, victim list or elapsed charge duration. Roblox explicitly recommends validating client requests, weapon targeting, ammunition and fire rate on the server [R03].

A visible shot can hit world geometry, an enemy, a valid barrier or nothing. It must not travel through unregistered cover. Accessories are ignored for damage. Friendly characters do not block projectiles in this release. Use explicit collision/query filters; decorative effects never become damage targets or paint surfaces accidentally [R08].

At most one direct/splash damage result applies to a victim for a single attack ID, unless the weapon explicitly defines repeated ticks. No double damage from both a projectile event and a touched event. No duplicate damage when the client retries a message.

### 06.2 Aiming and lag behavior

Predict muzzle flash, recoil, trajectory and paint feedback locally for responsiveness. Confirm damage and elimination through server acknowledgements. A hit marker that means **damage dealt** appears only after confirmation; a light local impact cue may appear earlier but must look different.

For the precision hitscan weapon, keep a small server pose history and cap permitted hitbox rewind at **150 ms**. Validate the shot timestamp against measured latency and server time. Current static walls still block the shot. Do not rewind the map, accept arbitrary old timestamps, or extend range as compensation. Projectile weapons use server-simulated trajectories with client prediction, not client-declared impacts.

High latency should degrade feedback gracefully, not trigger an automatic cheat kick. Log rejection reasons with attempt counts so normal misses, blocking, immunity and true validation failures are distinguishable.

### 06.3 Elimination, credit and respawn

When health reaches zero, stop the victim's actions once, capture the last legal attacker, show a small original paint burst, and begin the four-second respawn. Do not create a scoring paint explosion on death. Existing accepted projectiles may resolve until their normal expiry within the same live round; their attribution must remain valid if their owner is dead or disconnected.

Credit one elimination to the final damaging enemy. An assist requires at least 20 damage from another enemy within the previous 5 seconds. Environmental elimination credits the most recent qualifying enemy hit within 5 seconds; otherwise no attacker receives credit. Record deaths, eliminations and assists once per `LifeId`.

Respawn at a validated friendly spawn point with full health and paint. Retain **50% of the ultimate charge held at elimination**, rounded down. Clear movement/action state, damage history and old input holds. The HUD and camera must rebind to the new character without duplicate connections.

### 06.4 Spawn protection

The protected base is non-scoring. Enemies cannot enter its protected volume or damage players inside it, and shots cannot pass through its protective boundary in either direction. Players must exit to attack the arena. Explain a blocked base shot with a short cue.

A newly respawned player also receives a maximum **2-second shield** that expires on its timer or immediately before their first legal offensive action. It is not renewed by crossing the base boundary or by opening a menu. Shielded players can be seen; attacks against them show a distinct shield cue and cause no damage or ultimate gain.

Each map provides four spawn positions and at least two useful exits. No opposing spawn-to-spawn sightline. Detect an invalid spawn volume at map validation, not during a live elimination.

---

## 07. Main weapon roster: seven complete sidegrades

All weapons are selected in the Free Armory before the round. **No random map pickups. No prices. No leveling to obtain a stronger weapon.** The selected kit remains fixed through death and respawn until intermission. A late joiner chooses before entering the live arena.

IDs are permanent; display names can change without rewriting saves. Weapons use original models and effects. The values here are initial balancing, to be adjusted only with a logged reason and regression results.

### 07.1 Shared units and interpretation

Damage is health points. Cost is paint units. Distances are studs. Cadence is the minimum time between legal attacks, measured by the server. All damage values are body damage. A projectile stops at the first blocking surface or its range/lifetime limit. Every projectile uses swept collision rather than relying on physical `Touched` events at high speed.

A paint radius describes the gameplay footprint on visible, valid surfaces, not an unbounded visual splash. Decorative droplets cannot claim cells beyond the footprint. Ground drips from a character impact may paint a valid supporting floor within 6 studs below it; they do not paint through the character's floor into another room.

### 07.2 Roster summary

| ID / name | Role and input | Core damage / cadence | Cost and reach |
|---|---|---|---|
| `sprayline` — **Sprayline** | Balanced automatic shooter. Hold Primary. | 24 per hit; 0.12 s between shots. | 1.8 per shot; 72-stud maximum trajectory. |
| `twin_jets` — **Twin Jets** | Mobile close-range dual sprayers. Hold Primary; Secondary dashes. | 18 per hit; 0.09 s between alternating shots. | 1.3 per shot; 50-stud reach. Dash costs 8. |
| `lane_roller` — **Lane Roller** | Broad floor control. Primary flick; hold Secondary to roll. | Flick 65 close / 40 far; 0.80 s attack cycle. Rolling contact 60 with per-target cooldown. | Flick 14; roll 12/second while moving. Flick reach 22. |
| `linecaster` — **Linecaster** | Telegraphed precision charger. Hold/release Primary. Secondary focuses view. | 35–110 depending on charge; 1.10 s full charge, 0.35 s recovery. | 20 per released shot; 120-stud hitscan reach. |
| `splash_pot` — **Splash Pot** | Lobbed arcs over low cover. Press/hold Primary at limited cadence. | 55 per volley; 0.65 s cadence. | 12 per volley; 52-stud trajectory limit. |
| `street_sweeper` — **Street Sweeper** | Fast short-range brush. Hold Primary; hold Secondary to push. | 32 per sweep; 0.22 s cadence. | 4 per sweep; 12-stud attack reach. Push costs 10/second. |
| `popshot` — **Popshot** | Slow explosive pressure. Press/hold Primary. | 70 direct OR 40–20 splash, never both; 0.80 s cadence. | 10 per shot; 56-stud trajectory limit. |

### 07.3 Per-weapon behavior

**Sprayline.** Projectile speed 180 studs/second; downward acceleration 44 studs/second²; starting spread 2.5 degrees. Each valid impact paints a radius of 2 studs. Sample the projectile's path at 4-stud intervals and allow a narrow radius-0.75 ground drip only where a downward trace finds visible floor within 6 studs; stop the trail at the first obstruction. No shooting through a roof to paint beneath it. Ideal body elimination needs five hits, or 0.48 seconds between first and fifth impact at perfect cadence. This is the baseline weapon, not a weak starter.

**Twin Jets.** Alternate left/right attachments, never two damage events for one paid shot. Projectile speed 180; downward acceleration 44; spread 3 degrees; impact radius 1.6. Secondary performs a 7-stud, 0.18-second lateral dash with a 2.5-second cooldown. Use movement input for direction, or camera-right if stationary. Dash stops at obstacles, gives no invulnerability, costs 8 paint and cannot be chained while climbing, gliding or launching. Six direct hits eliminate a full-health opponent. Both muzzle positions require cover checks.

**Lane Roller.** Primary has 0.18-second windup inside its 0.80-second cycle. Sweep a tested 70-degree forward fan: 65 damage inside 10 studs, 40 damage from there to 22 studs, with one hit per victim. Paint a clipped 14-by-8-stud forward footprint where the fan reaches legal surfaces. Secondary rolls a continuous 8-stud-wide ground strip at up to 12 studs/second. Roll contact deals 60 damage, at most once per victim every 0.65 seconds, with a swept body test and line of sight. Stationary rolling paints only its contact area once; it does not deal per-frame damage or drain paint forever. Primary exits rolling; resume only with a fresh Secondary hold after the attack lock.

**Linecaster.** Begin a charge only with at least 20 paint. Release after at least 0.15 seconds to fire; charge factor increases linearly from 0 to 1 across 0.15–1.10 seconds. Damage is `35 + 75 × chargeFactor`. Each released shot costs 20 regardless of charge. Releasing earlier cancels without firing or cost. Glide, climb, elimination and panel entry cancel stored charge; there is no charge storage. Secondary narrows FOV to 55 while held, without immobilizing the camera. Paint a 2-stud-wide ground trace only on independently visible supporting surfaces within 6 studs below the valid beam segments. Show an original charge glow and a line-of-sight-clipped aim warning. One full-charge hit can eliminate; this must be earned through charge time, aim and exposure.

**Splash Pot.** Launch three visible lobes as one volley, with horizontal angles of -7, 0 and +7 degrees. Starting velocity is the aimed direction times 80 studs/second plus 30 studs/second upward; downward acceleration 98.1. Stop each lobe at its trajectory limit or collision. Each lobe paints radius 3. **All three lobes share one attack ID: total direct damage to a victim from that volley is capped at 55.** Low cover may be cleared by the real arc, but tall cover blocks it. Do not implement a magical damage cone through walls.

**Street Sweeper.** Each sweep has a short 0.05-second windup inside the 0.22-second cycle. Use an occlusion-checked forward arc and paint a 10-by-5-stud footprint. One damage event per victim per sweep, with no ragdoll or stun lock. Secondary pushes a 3-stud-wide trail at up to 22 studs/second, but deals no contact damage. Enemy-paint speed restriction still applies until the path is repainted. Primary and push are mutually exclusive; transitions must not create free extra attacks.

**Popshot.** Projectile speed 80; downward acceleration 24; burst on first blocking collision or range expiry. Direct victim receives 70 total damage. Other enemies receive 40 damage within 3 studs of the burst, falling linearly to 20 at 8 studs; no damage beyond 8. Every affected target requires blast line of sight. Paint radius is 6 on eligible visible surfaces. A direct victim does not also receive splash damage. Its slow cadence and travel speed are intentional weaknesses.

### 07.4 Fixed kits

| Main weapon | Gadget | Ultimate |
|---|---|---|
| Sprayline | Splash Can | Color Burst |
| Twin Jets | Splash Can | Color Burst |
| Lane Roller | Paint Screen | Color Burst |
| Linecaster | Splash Can | Paintstorm |
| Splash Pot | Splash Can | Paintstorm |
| Street Sweeper | Paint Screen | Paintstorm |
| Popshot | Paint Screen | Color Burst |

Do not add a freeform gadget/ultimate builder in this release. The Armory displays a kit's complete behavior, not misleading "power" bars that imply later weapons are upgrades.

### 07.5 Balance acceptance

Test floor coverage per 10 seconds, time to empty/refill, direct elimination time, obstacle interaction, movement while firing, maximum reach and actual touch usability. Run close-, medium- and long-range duel scenarios. A weapon that dominates every scenario needs tuning; a weapon that only differs in color is not complete.

Numerical unit tests validate configured mechanics, not fun. Record short real playtest clips and observations for readability, frustration and counterplay. No claim of balanced human matchmaking can be made from dummy damage tests alone.

---

## 08. Gadgets, ultimates and Team Launch

### 08.1 Gadgets

**Splash Can** (`splash_can`). Cost 55 paint. A 0.15-second throw preparation, then a ballistic projectile with 1.2-second fuse starting at release. Starting throw velocity: aimed direction × 55 studs/second plus 20 upward; downward acceleration 98.1. Maximum one active can per owner. Minimum interval between releases 0.75 seconds, in addition to paint availability. Explosion deals 70 damage within 4 studs, falling linearly to 25 at 10 studs; no self/friendly damage, no damage through cover. Paint radius 8, clipped to visible eligible surfaces. One application per victim. Clear it at round end.

**Paint Screen** (`paint_screen`). Cost 55 paint. Place a 12-stud-wide, 8-stud-high temporary screen roughly 6 studs ahead on a legal floor. Lifetime 5 seconds, health 250, one active screen per owner. It blocks enemy projectiles and blast visibility, but not friendly shots. Characters may pass through it; it causes no contact damage. It is not paintable, climbable or scoring. Reject placement inside geometry, protected bases or another illegal surface before charging cost. Replacing an existing legal screen removes the old one. Minimum placement interval 1 second.

The screen's visible opening/closing animation cannot change its authoritative bounds or leave an invisible blocker after destruction. A shot that destroys it is consumed by that hit; that same shot does not also pass through and damage someone behind it.

### 08.2 Ultimate charge

A full meter is 100. Gain `changedEligibleArea / 16` meter from main-weapon or gadget paint that actually converts valid scoring cells from neutral/enemy to friendly. Repainting friendly floor, painting walls, practice paint, base paint and ultimate paint grant no meter. Limit gain to 6 points/second and do not credit the same cell to the same player more than once every 5 seconds. This is a match-only abuse limit, not a new progression system.

No meter for merely firing, missing or getting killed. Spend 100 atomically on a valid activation. An ultimate cannot charge itself. Death retains half of the remaining unspent meter. A late join starts at zero. All meter logic is server-owned.

### 08.3 Two original ultimates

**Color Burst** (`color_burst`). Activate to throw a clearly signaled large paint capsule after 0.25 seconds of preparation. Use Splash Can's trajectory with a 0.7-second fuse. Explosion paint radius 18; damage 80 within 5 studs and 40 outside that radius up to 12 studs, with line of sight. No self/friendly damage, no additional direct-hit damage and no invulnerability. It is a strong territory swing, not an unavoidable whole-map attack. Deduct the meter at accepted activation; elimination during preparation cancels the throw without refund. Once released, it continues until expiry or round end.

**Paintstorm** (`paintstorm`). Throw a beacon with the same throw preparation/trajectory and a 0.5-second fuse. On a valid floor impact, create a stationary storm with radius 18 for 6 seconds. Tick every 0.5 seconds. Each tick paints eligible ground under unobstructed downward rain rays and deals 5 damage to an enemy in the open storm volume. Roofs and solid overhead cover block rain; it never paints through upper geometry. Targets receive at most one damage tick per interval. Overlapping storms do not multiply damage above one storm tick per target per interval, although both may contest paint. The storm creates no ultimate meter. No moving cloud AI, homing or map-wide weather system.

If a storm beacon expires without a legal supporting surface, it fizzles with an explicit cue. Do not invent a floating scoring plane. A player can keep aiming and moving during both ultimates; only the short preparation locks weapon firing. Effects must remain readable at low visual quality.

### 08.4 Team Launch

Open the tactical map, select a living teammate or your base, and confirm. A teammate launch requires the requester to be alive, standing on friendly paint, out of an attack action and not damaged for the preceding 1.5 seconds. Channel for 1.0 second while stationary; movement over 1 stud, damage or another attack cancels it.

At departure, validate a clear landing floor near the selected teammate. Freeze that landing location for the transfer; do not endlessly chase a moving teammate. Show a visible enemy-readable landing marker for a 1.0-second transit. During transit the character cannot fire or be damaged. At arrival, allow only 0.25 seconds of landing protection, canceled by an offensive action. Apply an 8-second cooldown after successful departure.

If the target dies or the landing becomes invalid before departure, cancel without cooldown. If the frozen destination becomes invalid in transit, return to a validated friendly spawn and retain the cooldown. Base launch uses the same channel but may be initiated from any legal non-enemy floor. It is an escape with an interruptible delay, not an instant panic teleport.

The client sends only a teammate ID or Base choice. The server finds the location. Never accept a client-supplied teleport CFrame. Team Launch is core tactical movement; it is not a cross-server teleport or separate place system.

---
## 09. Two maps, fully specified for Codex

Claude builds the map loader, surface registration, validators and test fixtures. **Codex builds the actual map geometry and art.** Claude does not spend the coding pass creating finished arenas. The following briefs are binding content requirements, not permission to trace a reference map.

### 09.1 Common arena rules

All release gameplay geometry is anchored and static. No destruction, moving platforms, breakable paint surfaces or physical paint fluid. Use planar paintable floors, ramps and wall panels. Decorative geometry may be complex, but collision and paintable faces must remain deliberate and simple.

Target map footprint: approximately 40,000 square studs, with **no more than 50,000 valid scoring cells and 16,000 additional non-scoring wall cells**. Each scoring cell is one square stud. A release map may have up to 96 paint-surface patches initially; exceeding this requires a measured renderer-budget review. These are project budgets, not Roblox engine limits.

Use at least three meaningful routes into the center, two spawn exits per team, full-height cover and short open crossings. No lane should expose a player to every angle at once. Maximum intended uninterrupted combat sightline: about 90 studs. A 120-stud weapon is useful for angles, not for hitting the opposing spawn.

Required geometry guidelines: main routes at least 18 studs wide; secondary routes at least 12; ordinary full cover 7–9 studs high; half cover about 3.5; main climb walls no higher than 12; accessible ramps no steeper than 30 degrees. No required jump that the default character cannot make reliably at 30 FPS. No decorative object may seal a route after the blockout is approved by tests.

For this release, do not place two **scoring** surfaces directly above one another in X/Z. Raised platforms are allowed if the floor beneath is inaccessible and excluded. This makes the tactical map unambiguous and prevents hidden duplicate score. Walls remain separate paint surfaces. No ceilings or underside faces are scoreable.

Map borders have visible barriers. Use one out-of-bounds kill/recovery volume below the arena and explicit boundary volumes around inaccessible areas. Do not rely on an endless fall or an invisible surprise death near a legal route.

### 09.2 Map A — Switchyard

**ID:** `switchyard`  
**Theme:** an original outdoor equipment-testing yard with bold lane markings, utility cover and paint-sport equipment.  
**Footprint:** 240 × 160 studs; center at world origin; teams approach along the X axis.

| Landmark | Blockout specification |
|---|---|
| Team A base | Center near X = -108, Z = 0. Protected floor about 24 × 40 studs. |
| Team B base | Mirrored at X = +108. Same reachable area and exit timings. |
| Spawn positions | Four per side, at least 7 studs apart, with adequate character clearance. |
| Main engagement area | Approximately 64 × 56 studs centered at origin, divided by two offset full-cover islands. |
| Side lanes | Routes near Z = -48 and Z = +48, connected to center by two openings per side. |
| Spawn exits | Two per base, opening toward Z offsets around -16 and +16 rather than a single funnel. |
| Height changes | Two side platforms around 8 studs high, each with a ramp and one optional painted climb face. |
| Long-range positions | One per side, each with a flank access route and no direct protected-base sightline. |
| Nonpaintable material | Dark grating on selected connectors, never more than a short crossing; visibly distinct. |

The route graph must remain mirrored for the initial balance pass. Art dressing can differ on each side only if it does not change collision, paintable area, occlusion, concealment or travel distance. Name decorative landmarks clearly so future reports can identify locations.

**Map-specific tests:** both sides reach the center within 0.5 seconds of each other along equivalent routes; no protected spawn can see the other; both flank routes remain usable with a Paint Screen in the central opening; a short-range kit can reach useful cover without taking an unavoidable 90-stud straight crossing.

### 09.3 Map B — Canopy Courts

**ID:** `canopy_courts`  
**Theme:** original outdoor paint-sport courts with low terraces, small shade structures and court-side equipment.  
**Footprint:** 220 × 180 studs; teams approach along X; no reused Nintendo layout.

| Landmark | Blockout specification |
|---|---|
| Team bases | Centers near X = -98 and +98; same protected footprint and four spawn positions per side. |
| Central contest | A roughly 72 × 64-stud open court with staggered cover, not one unbroken firing box. |
| Side routes | Paths near Z = -58 and +58; one wider direct lane and one cover-rich lane, mirrored for both teams. |
| Raised terraces | Up to 10 studs high; no scoreable floor beneath; each has ramp access and a paint-climb option. |
| Canopies | Limited non-scoring overhead cover that intentionally blocks Paintstorm; do not cover most of the map. |
| Paintable walls | Clear, readable panels at the terraces; non-climbable outer fencing is visually different. |
| Center entrances | At least three per side, arranged so one screen cannot block every approach. |

This map tests a different cover pattern and rain obstruction while keeping the same mode. It is not a second ruleset. Preserve roughly equal reachable scoring area and timing on both sides.

**Map-specific tests:** Paintstorm cannot paint or damage through a canopy; Linecaster cannot shoot through a canopy support; every terrace has a non-climb route; map projection does not hide scoring floor; no mantle reaches an out-of-bounds roof.

### 09.4 Engineering fixture — not content

`paint_lab` is a code-generated test scene containing a floor, ramp, paint wall, neutral wall, thin cover panel, canopy, two spawn volumes and stationary damage capsules. Claude may generate these plain test objects in a development/test namespace because they are test infrastructure, not authored maps. They must not appear in the production map rotation.

The fixture can be duplicated at maximum surface budgets to benchmark paint. It may stand in for map A/B during loader-contract tests, but those tests must say **fixture**, not "both production maps tested."

### 09.5 Map content contract

Every Codex map contains:

- Root Model with `MapId`, `MapVersion`, `ContractVersion = 1` and a documented origin.
- `Geometry`, `PaintSurfaces`, `Spawns`, `Volumes`, `Markers` and `Decor` folders.
- Four valid A and four valid B spawn markers; protected-base volumes; out-of-bounds volumes; a staging return marker.
- Surface entries with a unique stable `SurfaceId`, local origin/basis, dimensions, legal-cell mask, `Scoreable`, `Climbable`, `SurfaceKind` and renderer-region mapping.
- A manifest of paintable area, initial ownership, expected cell counts, patch count, minimap projection and asset dependencies.

All ordinary scoring cells start neutral. Protected base cells may display their team color but are excluded from scoring and ultimate gain. No duplicate surface IDs, coincident scoring faces or "invisible" scored areas. Validate all masks against collision and surface normals before loading the map into a match.

---

## 10. Painting: the highest-risk system

### 10.1 Required result

A player's visible paint, movement permissions, refill state, tactical map and final score must agree. Painting the same location twice must not create extra score. Painting an enemy patch must remove it from that enemy and give it to the painter's team. A late joiner must see the existing paint, not a blank arena.

**Do not begin by spawning a new Part or Decal for every paint hit. Do not read rendered pixels back to determine the winner.** Establish a bounded authoritative ownership model and prove its rendering path before building the full arsenal.

### 10.2 Authoritative surface grid

Represent each supported face as a planar patch with an immutable orthonormal basis: origin, U, V and normal. Convert validated world impacts to local coordinates. Each valid one-stud cell stores ownership `0 = neutral`, `1 = A`, `2 = B`. Store the legal mask separately; a nonpaintable cell is not "neutral turf."

Use compact buffers/arrays, not one Instance or one remote per cell. Group cells into 16 × 16-cell chunks, padding invalid edge cells. Maintain per-patch and global owner counts incrementally. Read-only map metadata is shared; the server's ownership buffer is authoritative.

A paint stamp changes cells whose centers fall inside the defined clipped footprint. Each changed cell produces an old-owner/new-owner transition once. Scoreable transitions adjust totals; non-scoring wall transitions only update ownership. Maintain the invariant:

`A_area + B_area + Neutral_area = TotalScoringArea`

A rotated wall must use its own local grid, never the ground's X/Z grid. No painting spills through a thin wall just because two faces share similar coordinates. Unknown surfaces are rejected and logged as content errors.

### 10.3 Occlusion and brush projection

Start from a legal server-confirmed impact. Query nearby registered surface patches using a spatial index. Project the configured footprint onto candidates and verify facing, bounds and occlusion. For a blast, trace from the burst toward candidate cell/sample positions; a solid wall or enemy Paint Screen blocks propagation. For rain, trace downward from the storm's rain volume; overhead geometry blocks it.

Near edges, permit paint on an adjacent face only when that face is actually visible to the stamp origin and falls inside the configured radius. Never use a giant overlap box that paints everything on both sides of cover. A shot at a nonpaintable object creates a cosmetic impact but no false claim on hidden floor beneath it.

Trail weapons use swept samples with a maximum spacing tied to their footprint, so low FPS does not leave gaps. A teleport, correction or abnormally large movement delta must not draw a paint line across the arena. Clamp and validate the traveled path before applying a rolling trail.

### 10.4 Rendering decision and feasibility gate

Preferred experiment: **one shared runtime paint atlas per map on each client**, with registered planar patches referencing its regions. Use one- or two-pixel ownership cells initially and a separate visual edge treatment that does not misrepresent gameplay boundaries. Keep surface UV/region mappings fixed and let clients recolor ownership with their selected palette.

Roblox's EditableImage documentation describes published-experience enablement/verification requirements, restricted client memory budgets, a maximum image size of 1024 × 1024, and a one-displayed-image-update-per-frame limitation [R05]. These constraints make a small number of shared atlases preferable to an image per hit or per cell. **Studio success alone does not establish live availability.**

In Phase 02, confirm the actual experience's permitted API path, prove allocation and updates on a published private test where authorized, and measure atlas memory, redraw cost and patch rendering cost. Blank images must not depend on unauthorized source textures. Validate region borders, U/V orientation and atlas bleed on every face type.

The renderer is behind `IPaintRenderer`: `Initialize`, `ApplyChunk`, `SetPalette`, `Reset`, `Destroy`. The ownership/scoring system does not depend on EditableImage. If the API is unavailable, Claude may qualify a bounded native rendering alternative, such as chunk-merged colored rectangles, against the **same** accuracy and mobile performance tests. Do not silently drop cells, combine opposing colors into one color, exceed budgets or call a bad fallback done. Do not build two production renderers without a demonstrated need. If neither path passes, Phase 02 is blocked and dependent production work must not be falsely approved.

### 10.5 Incremental synchronization

Reliable state messages carry `MatchId`, `MapVersion`, chunk ID and monotonically increasing chunk version. Batch changed cells into chunk deltas at a starting rate of **10 updates/second**, while local cosmetic prediction may be immediate. Send the final round freeze/result reliably. UnreliableRemoteEvents are suitable only for disposable visual cues, not territory ownership or final results; Roblox documents that they may be lost or reordered and have bounded payload sizes [R04].

A client that detects a version gap requests a bounded resync. On late join, take a coherent snapshot at sequence S, buffer subsequent deltas, send chunked snapshot data, and replay changes after S. A buffer overflow restarts that snapshot; it never creates an arbitrarily large queue. Do not enable combat until map metadata and current paint are ready. Reject messages from an old match or map.

Initial project targets: paint snapshot no larger than 160 KiB including metadata; complete paint sync within 3 seconds under the standard 100 ms RTT test; steady paint traffic no more than 40 KiB/second/client under the defined eight-player stress case. These are targets to measure, not platform allowances. A renderer cannot solve an inefficient network protocol by hiding its updates.

### 10.6 Client prediction

Locally predicted paint is temporary presentation linked to a shot/action sequence. Authoritative chunks confirm or replace it. A denied action removes its prediction within 0.5 seconds of the denial arriving. There must be no permanent ghost paint after a rejected shot, respawn or reconnect.

Movement and ammunition use bounded local prediction with server correction; the local renderer never becomes a trusted gameplay source. Do not automatically kick a player for three corrections or for a bad frame/ping sample. Correlate sustained impossible movement with validated evidence and keep ordinary latency separate.

### 10.7 Reset and minimap

Round reset clears ownership buffers, cached counts, predicted strokes, pending deltas, ultimate-credit caches, render textures, map projection and all old-version state. Test repeated resets, not only the first load.

The tactical map is generated from registered scoring surfaces and the same ownership state. Show the local player, teammates, base and Team Launch choices. Do not provide live enemy positions through walls. Display paint at a modest 5 Hz refresh and actual final ownership at results. No separate scoring system may be hidden inside the minimap.

---

## 11. Code architecture and networking contracts

### 11.1 Architectural approach

Use typed Luau, data-driven definitions and a small number of cohesive services/controllers. Reuse a sound existing project structure when one is present. Do not introduce several frameworks or rewrite working infrastructure merely to match a fashionable pattern.

Server: round state, teams, validation, authoritative projectiles/hits, paint ownership, health, paint tank, ultimates, spawning and save operations. Client: input, camera, prediction, renderers, UI presentation, sound/VFX playback and local diagnostics. Shared: types, immutable definitions, pure math, serializable contracts and deterministic helpers. Roblox's data-model documentation describes the different replication roles of its containers [R09].

### 11.2 Suggested repository layout

```text
project-root/
  CLAUDE.md
  default.project.json
  rokit.toml
  docs/
    MASTER_GDD.md
    IMPLEMENTATION_STATUS.md
    DECISIONS.md
    VIDEO_OBSERVATIONS.md
    ASSET_CONTRACT.md
    UI_CONTRACT.md
    MAP_CONTRACT.md
    CODEX_HANDOFF.md
    QA_MATRIX.md
    qa/phase-00/ ... phase-10/
  src/
    shared/Types/ Config/ Math/ Protocol/ Contracts/
    server/Bootstrap.server.luau
    server/Services/
    client/Bootstrap.client.luau
    client/Controllers/
  content/
    maps/ weapons/ character/ ui/ effects/
    AssetManifest.luau
  tests/
    unit/ integration/ adversarial/ fixtures/
  tools/
    verify.ps1
    validate-content.ps1
    build-test-place.ps1
  build/
```

This is a proposed organization, not a command to overwrite another game's repository. `build/` and generated QA caches are excluded from source control as appropriate; retain compact reproducible evidence and reports. Raw secrets and personal tokens are never committed.

### 11.3 Required responsibilities

| Server component | Owns |
|---|---|
| RoundService | State machine, authoritative deadlines, final score freeze and reset orchestration. |
| TeamService | Ready roster, capacity, backfill, side assignment and vacancy rules. |
| MapService | Map loading, contract validation, surface manifest and lifecycle. |
| PaintService | Ownership buffers, legal stamps, scoring and snapshot/delta generation. |
| CombatService | Accepted actions, projectile simulation, hits, damage and attribution. |
| CharacterService | Spawn/life IDs, health, movement validation, protected zones and launches. |
| LoadoutService | Legal kit selection and paint/ultimate resources; may be split if justified. |
| SettingsService | Validated preferences and graceful persistence. |
| DiagnosticsService | Counters, timings, sampled metrics and clear test/production separation. |

Client controllers cover input, camera, character presentation, weapons/prediction, paint rendering, tactical map, UI, audio/VFX and diagnostics. Assign one owner to each responsibility. A character respawn must not start a second global controller stack.

### 11.4 Remote protocol

| Message | Direction / reliability | Validation and meaning |
|---|---|---|
| Ready / SelectLoadout | Client → server, reliable | Legal ID; allowed phase; no client prices/stats. |
| ActionRequest | Client → server, reliable | Match/life ID, sequence, bounded aim, action type and timestamp. No trusted target damage. |
| HeldAimUpdate | Client → server, expendable where appropriate | Validated limited-rate aim for held actions; stale input times out safely. |
| ActionResult | Server → requester, reliable | Accepted/rejected, reason, sequence and corrected resource/state values. |
| RoundState | Server → client, reliable | Match ID, state, authoritative deadlines, roster and map version. |
| PaintSnapshot / PaintDelta | Server → client, reliable | Versioned chunks; bounded payloads; no per-cell remote spam. |
| PaintResyncRequest | Client → server, reliable | Existing chunk IDs only; rate-limited; cannot force full-server rebuild. |
| ResourceState / DamageResult | Server → relevant clients, reliable | Authoritative health, paint, charge and elimination data. |
| EffectCue | Server → relevant clients, expendable | Whitelisted effect ID and validated parameters; never arbitrary asset IDs or scripts. |
| LaunchRequest | Client → server, reliable | Teammate ID or Base; server determines destination. |
| SettingsPatch | Client → server, reliable | Whitelisted keys, finite bounded values and small payload. |

A held-fire weapon may send a reliable start/stop and bounded aim updates, with the server enforcing cadence and a stale-input timeout. Alternatively use sequenced per-shot requests at actual shot cadence. Pick and document one approach per weapon family. Do not send a fire event every rendered frame.

Check types, table shape, finite numbers, bounds, alive/phase state, ownership, cooldown, paint, range, muzzle position and obstruction. Rate-limit requests server-side before expensive work [R03]. Never let a remote change an arbitrary Instance path or load a module/asset chosen by a client.

### 11.5 Failure and cleanup rules

Every live system has `Start`, `Stop` or equivalent lifecycle ownership and disposes its connections, tasks, tables, effects and Instances. Use cancellation tokens/state checks instead of attempting to cancel arbitrary already-finished threads. Do not hide recurring exceptions inside empty protected calls.

An asset timeout must return a useful fallback or error state. An unknown weapon ID selects the safe default only during loadout recovery, never during an active attack to gain different stats. Missing critical map metadata prevents match start. Missing decorative art may use a logged fallback during code testing, but cannot pass the final content gate.

Studio-only commands require a server-side development/test check. Production contains no exposed GiveUltimate, SetWinner, TeleportAnywhere or arbitrary code execution remotes. Test clients are not a substitute for real server validation.

### 11.6 Persistence: deliberately small

Save schema version, chosen loadout ID, control/settings preferences and whether the player dismissed onboarding. No cash, ownership purchases, rank or XP exists. Validate every preference and use bounded retries around service failures. Roblox documents server-side DataStore access, failure handling and update operations [R12].

If a read fails, allow a session with defaults and a visible non-blocking save warning, but **do not overwrite an unknown existing profile with defaults**. Save only dirty, validated changes; batch/debounce them rather than writing every slider tick. Test schema fallback and concurrent-session preference updates. Keep Studio test keys separate from live data. An in-memory test is not proof that the published save path works.

---

## 12. Complete UI specification

**Claude owns functionality, state, validation, bindings and tests. Codex owns the authored ScreenGuis, layouts, icons, typography, transitions and visual polish.** A production UI must be native interactive Roblox UI, not a single flattened screenshot with pretend buttons.

### 12.1 Screen inventory

| Screen | Required contents | Required behavior |
|---|---|---|
| Loading | Stage label, progress by actual stage, Retry/Back on recoverable failure. | Distinguish asset loading, map validation, paint sync and ready. Never display fabricated percentages. |
| Staging | Play/Ready, Unready, Armory, Controls, Settings; player-count/status line. | Show waiting/countdown/live-backfill/next-round status. Default kit is already selected. |
| Armory | Seven kit cards, selected state, role, numerical stats, gadget/ultimate descriptions, equip confirmation. | All free. Server-confirm selection. Disable changes during live participation. No Buy/Unlock button. |
| Controls | Device-specific bindings and three core instructions. | Dismissible and reopenable. Does not block the round indefinitely. |
| Match intro | Map name, team label/color and 3–2–1 cue. | No firing until Live; camera remains safe and controllable. |
| Combat HUD | Timer, A/B/neutral coverage, paint tank, health, kit icon, gadget cost/readiness, ultimate meter, reticle. | Authoritative state plus labeled prediction; no expensive full rebuild on each tick. |
| Touch controls | Move/look support plus Primary, relevant Secondary, Glide, Jump, Gadget, Ultimate, Map. | Multi-touch, safe-area placement and button-state feedback. |
| Tactical map | Current territory, local player, teammates, base, Launch choice, Confirm and Back. | No enemy ESP. Illegal launches show the specific reason. |
| Scoreboard | Team grouping, names, eliminations, assists, deaths and paint contribution. | Sort by paint contribution first; do not imply kills determine the winner. |
| Elimination | Attacker/weapon if known, respawn countdown, short protected-base explanation on return. | No broken spectate/killcam button. Rebind to new life when respawned. |
| Results | Coverage reveal, winner/draw/NoContest, neutral share and personal match stats. | Same frozen totals on all clients. Return automatically after 10 seconds. |
| Settings | Input sensitivity, invert-Y, glide mode, shoulder, palette, reduced effects, volumes. | Apply locally immediately where safe; save asynchronously. |
| System notices | Connection delay, loading failure, save failure, unavailable action and missing content. | Short, specific, rate-limited. No scary false cheat message for ordinary lag. |

A personal **Paint Contribution** stat counts newly converted scoring area during the match and can exceed the final arena area because territory can be reclaimed. Label it as contribution, not final owned area. It does not determine team victory. Include this distinction in the tooltip.

### 12.2 HUD placement intent

Top center: timer and compact A/B/neutral coverage bar. Center: reticle with charge/spread state and blocked-muzzle feedback. Bottom center/side: paint and health. Lower right on desktop: gadget and ultimate readiness. On mobile, these readouts sit above or beside the action buttons without covering the aiming region. Team/round notices appear above the reticle briefly, not over a target for several seconds.

Do not put a fake shop, rewards track or rank icon on the HUD. The strongest visual information is **where to paint, whether you can fire, and how the round is going**.

### 12.3 UI binding contract

Production root: `ColorClashUI`, `ContractVersion = 1`. Bind through unique `UIKey` attributes or equivalent validated references, not fragile visual hierarchy paths. Mandatory keys include:

```text
Loading.Root / Loading.Stage / Loading.Retry
Staging.Root / Staging.Ready / Staging.Unready / Staging.Status
Armory.Root / Armory.KitList / Armory.Equip / Armory.Close
Controls.Root / Controls.Close
HUD.Root / HUD.Timer / HUD.CoverageA / HUD.CoverageB / HUD.Neutral
HUD.Paint / HUD.Health / HUD.Reticle / HUD.Gadget / HUD.Ultimate
Touch.Primary / Touch.Secondary / Touch.Glide / Touch.Jump
Touch.Gadget / Touch.Ultimate / Touch.Map
Map.Root / Map.Image / Map.TargetList / Map.ConfirmLaunch / Map.Close
Scoreboard.Root / Scoreboard.TeamA / Scoreboard.TeamB
Elimination.Root / Elimination.Countdown
Results.Root / Results.Outcome / Results.Coverage / Results.Stats
Settings.Root / Settings.Close / Notices.Root
```

Dynamic kit/player rows use templates and a per-instance binding ID. The same `UIKey` must not accidentally bind two actionable controls. Store text in a string table. Validate button classes, text fields, templates and missing keys before allowing production UI activation.

Claude may generate a plain wireframe from this same contract for code tests. The production adapter must work when Codex's UI replaces it. Wireframes must be clearly flagged development-only; screenshots of them cannot pass final visual acceptance.

### 12.4 Interaction states and test sizes

Every action has idle, hovered/focused, pressed, disabled, pending and error feedback where relevant. Equip and Ready cannot double-submit. A controller can navigate, activate and close every screen without a mouse. Closing a panel restores the correct gameplay input context; it does not make the next click accidentally fire.

Test at minimum: 1920×1080, 1366×768, 1280×720, 1024×768, 844×390 and 740×360 logical viewport cases, including a safe-area cutout. Check long player names, 30% longer text, an empty roster, full eight-player results and a reconnect during a panel transition. Device emulation checks layout/input, not physical-device GPU or thermal behavior [R07].

---

## 13. Codex content handoff and ownership

### 13.1 Responsibility boundary

| Work | Claude | Codex |
|---|---|---|
| Combat, paint, networking, saves, match flow | Implement and test. | Do not rewrite. |
| Map layout specification and validation | Specify dimensions/contracts; generate test fixtures only. | Build and dress the two actual arenas to the contract. |
| Weapon/character models | Define sizes, pivots, attachments and state hooks. | Create original, optimized, importable models. |
| Animations | Own playback state, timing and authoritative movement/damage. | Author and implement animation assets and markers. |
| UI | Own controllers, wireframes, state and tests. | Build production native UI, layouts, icons and transitions. |
| Paint renderer | Own runtime ownership display and synchronization code. | Supply compatible surface geometry, UV/region layout and visual textures as needed. |
| VFX/audio | Own event timing, pooling, accessibility and budgets. | Create/source authorized effects and sound assets; implement assets in content. |
| Final integration | Validate all content; fix code-side integration; rerun full regression. | Correct content defects and preserve contracts. |

Codex may use temporary authoring scripts or import tools to build assets, but those tools must not become an alternate gameplay implementation. Animation root movement, damage and teleports remain code-owned. Do not bake forward launches into an animation that fights authoritative movement.

### 13.2 Required content inventory

- **World:** Switchyard; Canopy Courts; a small safe staging/practice area; cover, ramps, climb panels, boundary markers, spawn presentation and original environment materials.
- **Character:** one normalized athlete rig, team-readable materials, Paint Tank visual and glide presentation.
- **Weapons:** seven complete models, including separate left/right Twin Jets; two gadget models; two ultimate beacon/capsule models.
- **UI:** all 13 screen groups in Section 12; seven weapon icons, two gadget icons, two ultimate icons, input glyphs, team markers, reticles, shield/connection/error indicators and map representations.
- **Animations:** locomotion, jump/fall, glide entry/loop/exit, climb/mantle, weapon holds and attacks, charger states, dash, roller/brush secondary states, gadget throw/place, ultimate preparation, elimination and spawn. Share compatible base animations where appropriate; every needed state must be covered.
- **Effects:** muzzle/shot/impact variants, friendly/enemy paint readability, shield hit, low paint, charge ready, dash wake, screen damage/break, grenade warning/explosion, storm, launch marker/transit/landing and results cue.
- **Audio:** each weapon's fire/charge/empty/impact cues, glide/refill, gadget and ultimate warning/use, shield, elimination, spawn, countdown, final-30-second cue, round end and essential UI feedback. No copied reference-game soundtrack.

The inventory is core presentation, not a cosmetic store or collectible system. Reuse assets deliberately to meet budgets.

### 13.3 Model and animation contracts

Each weapon Model carries a stable `AssetKey`, `ContractVersion`, a documented pivot and a `Grip` attachment. Ranged weapons require `Muzzle`; Twin Jets require `MuzzleL` and `MuzzleR`. Add `EffectOrigin` and class-specific contact markers only where required. Cosmetic weapon parts are non-colliding and cannot become hitboxes. Avoid giant invisible Parts changing character physics.

Character animations may expose markers such as `Windup`, `Fire`, `Recover` and `Footstep`. Markers drive presentation and synchronization checks; **a missing client animation marker cannot prevent or grant authoritative damage**. The server uses configured attack times. A retiming change must be reflected in the content manifest and tested against the weapon definition.

Every published asset has an actual accessible asset ID, owner/permission record, purpose, source/license note and tested load status. Never invent IDs. Check permissions in the real experience, not only the uploader's Studio session. If publishing is blocked, native temporary assets may keep code testing moving, but the content is still incomplete until the required production asset is usable.

### 13.4 Visual quality and budget briefs

Use chunky original paint-sport equipment: distinct silhouettes, visible team paint, clean muzzle direction and readable attack preparation. Do not simply recolor a ripped reference model. Avoid heavy VFX layers that conceal actual paint or enemy silhouettes. Low-quality settings may reduce decorative particles, not hide warnings or ownership.

Starting authoring budgets: about 8,000 triangles or fewer per equipped weapon, prefer fewer; about 20,000 for the shared character; 512–1024 textures where adequate; compact material/mesh counts; static collision proxies. These are proposed budgets to validate, not claims about a universal Roblox cap. Scene-level profiling can require lower budgets even when an individual asset passes.

### 13.5 The shared-project handoff

Use **one project repository, one worktree/folder, one chosen work branch and one associated Rojo/Studio session for this game**. Claude and Codex take turns. They must not edit concurrently. Other games keep their own separate folders, ports and places. Nothing here authorizes touching `C:\MABG` or another existing project.

Before switching agents, the outgoing agent documents changes and records the exact commit plus any Studio-only assets. Commit only its own intended files. Push only to an already authorized repository/branch; no force push or automatic merge into someone else's main. The incoming agent reads the handoff, git status/diff/log, Rojo mapping and current place before editing.

Rojo's project and sync documentation define what filesystem content is mapped into Studio [R14, R15]. Do not assume Studio-only changes automatically flow back into Git, or that a broad sync cannot affect unmapped content. Export authored content into the agreed tracked representation, such as `.rbxm`/`.rbxmx`, and document external asset IDs. Establish ownership of every synced tree. Test the build from tracked files, not only from a lucky existing Studio session.

---

## 14. Performance, security and reliability targets

### 14.1 Measure on named environments

Record device model, operating system, Roblox/Studio version, graphics quality, resolution, build commit, active map, client count, network profile and test duration. A fast developer desktop with mobile emulation is not proof of mobile performance.

Select an actual Android phone, an actual iPhone/iPad-class device and a desktop available to the team as reference hardware. Do not claim untested devices or consoles are supported. Missing physical-device evidence blocks the corresponding release/platform claim, not all independent code work.

### 14.2 Initial budgets

| Metric | Acceptance target |
|---|---|
| Desktop steady combat | p95 frame time at or below 16.7 ms on the recorded reference desktop at the chosen target settings. |
| Mobile steady combat | p95 frame time at or below 33.3 ms on recorded reference mobile hardware. |
| Large combat hitch | Fewer than one frame over 100 ms per minute during steady combat, excluding declared map-load windows. |
| Game-owned server work | p95 game-script frame contribution at or below 8 ms in the eight-player stress case. |
| Paint renderer | Measured, bounded update time; target p95 at or below 3 ms on the reference mobile test. |
| Paint state | At most 50,000 scoring + 16,000 wall cells per map; no per-cell replicated Instances. |
| Combat entities | Initial cap 128 active simulated projectiles plus separately bounded gadgets/storms. Valid maximum-load play must not hit the cap. |
| Effects | Reused bounded pools; start with 192 transient visual objects and tune downward for mobile if needed. |
| Paint network | Steady-state target at most 40 KiB/s/client; coherent initial sync at most 160 KiB. |
| Memory stability | After warmup, no monotonic growth across 20 full rounds; ending idle memory within 5% of comparable warmed idle baseline. |
| Client memory | Initial planning target around 1 GiB or below on reference mobile; actual no-crash behavior and headroom must be measured. Not an engine limit. |
| Round reliability | 20 consecutive complete rounds on alternating production maps without state corruption or leaked gameplay entities. |

Use the MicroProfiler and explicit timing/counters rather than guessing from average FPS [R13]. Record distributions and worst spikes, not only an average. If an absolute budget proves inappropriate for the recorded hardware, log the cause, evidence and revised target before retesting. Do not quietly weaken a target solely to mark a phase complete.

### 14.3 Required stress situations

Eight clients firing continuously; eight simultaneous permitted ultimates in a controlled test; repeated Paint Screens; rapid deaths/respawns; sustained roller/brush repainting; worst-case alternating paint boundaries; join during heavy paint; disconnect during snapshot; palette switch mid-fight; 20 map resets; and resuming after focus loss.

The projectile/effect cap is a safety net, not permission to drop legitimate attacks at normal maximum player load. If reached, preserve deterministic resource accounting, log the overload and treat the test as failed. Do not spend paint for a silently discarded accepted shot.

### 14.4 Network and exploit cases

Test nominal RTT at roughly 50, 150 and 300 ms, plus a 600 ms degraded case. Test jitter, 1–5% packet loss and out-of-order disposable cues. Reliable ownership must converge. Higher latency may delay feedback; it cannot permanently duplicate damage, freeze a round, grant free ammunition or corrupt score.

Adversarial requests include oversized tables, unknown IDs, NaN/infinite coordinates, future/ancient timestamps, duplicate sequence numbers, impossible fire cadence, fake charge duration, firing while dead, cross-team launch, arbitrary target CFrames, excess snapshot requests and stale match/life IDs. Drop invalid requests cheaply, preserve state and record bounded diagnostics. Repeated malicious remote flooding may be addressed through a documented abuse policy; ordinary misses, correction counts or high ping are not sufficient evidence.

### 14.5 Error handling requirements

No unhandled server/client exceptions in normal play. No infinite `WaitForChild` on optional content. No background loop survives an old map. No coroutine crash on cancellation. No test dependency imported into production by accident. No access token in a local script, model, manifest or log.

A failed critical load prevents entry into combat with an actionable error. A failed noncritical sound/icon load has a small fallback and a diagnostic record. Final acceptance still requires production critical assets and intended UI to load.

---

## 15. Telemetry that answers useful questions

Instrumentation is core quality assurance, not a monetization/analytics expansion project. Implement a small, documented event schema and bounded local/server logs. Add platform analytics only when accessible and appropriate; never require an external webhook just to make the game run.

### 15.1 Event set

| Event | Why it exists |
|---|---|
| SessionStarted / LoadingStage / ClientReady | Separate actual data, asset, map and paint-sync delays. |
| FirstMove / FirstPaint / FirstGlide / FirstDamage | Measure whether a new player reaches the core loop. |
| ReadyChanged / MatchJoined / RoundStarted | Explain waiting, population and backfill behavior. |
| ShotAccepted / ShotRejected | Sample aggregate counts by weapon and reason; calculate rates using total attempts. |
| Eliminated / Respawned / SpawnBlocked | Check repeated deaths, attribution and spawn safety. |
| PaintResync / PaintHashMismatch | Find ownership divergence and join/reset failures. |
| UIAction / UIError | Verify useful actions, not just menu-open totals. |
| PerfSample / NetworkSample | Frame-time percentiles, hitch count, memory and network state with units/window. |
| RoundEnded / SessionEnded | Store frozen result or NoContest and an honestly known exit reason. |

Use a generated session ID and scoped match ID. Avoid secrets, raw chat content or unnecessary personal information. Use server timing for authoritative milestones and clearly label client-reported diagnostics. Unknown FPS or ping is `null`, not a fake zero.

**Do not label a departure "left because of lag" simply because FPS was low.** Store observed exit/kick reason separately from possible performance correlations. "Blocked," "shielded" and "missed" shots are not automatically broken hit registration. Distinguish attempted actions, legal rejections and implementation faults.

### 15.2 Core quality questions

Can a newcomer paint and refill without opening several menus? Do both teams get similar spawn-to-action times? Are touch players able to aim and shoot together? Does the paint they see match the movement they experience? Which attack rejects are expected? Does performance decay across rounds? Are players repeatedly eliminated before reaching a contested area?

Log the first-build baseline, then compare the same test scenarios after changes. Session duration alone is not proof of fun, stability or improved retention. Do not claim real-player retention gains from a handful of developer tests.

---

## 16. How Claude must use the one-hour gameplay video

**No gameplay video has been supplied with this GDD. There are no claimed video observations or measured timestamps yet.** The user intends to provide one to Claude later.

### 16.1 Review protocol

Identify the game/version and which mode each reviewed segment shows. Maintain `VIDEO_OBSERVATIONS.md` with actual viewed time ranges. Prioritize complete core PvP rounds, including entry, loadout, painting, movement, encounters, ammunition recovery, elimination, respawn and results. Rewatch short relevant actions rather than treating one quick glance as proof of the mechanic.

Log unrelated campaign, PvE, events, shops, gear progression and ranked sections as **outside scope**. Do not implement them. There is no requirement to reproduce the full video's surrounding menus or content.

For each useful observation record: timestamp/range, observable behavior, confidence, what cannot be inferred, corresponding GDD section, and whether it suggests a tuning experiment. A transcript can support spoken explanations but cannot by itself confirm animation timing, map geometry or hitboxes.

### 16.2 Questions to answer from observable play

How quickly does a player return to useful action? How is friendly paint distinguishable from hostile paint? What tells the player the tank is empty? How does the camera behave during movement and attacks? How readable are charge, grenade, shield and ultimate warnings? How much uninterrupted floor does a typical shot paint? How does a weapon communicate its strengths without a long explanation? How is the final winner revealed?

Do not claim exact source damage, network architecture, hitbox dimensions or hidden anti-cheat from footage alone. Compare visible feel with our configured values. Our four-minute timer, free kits, normalized character, enemy-paint simplification and original maps remain binding unless a documented in-scope tuning decision changes them.

### 16.3 Capability limitation

If the connected Claude environment cannot inspect video, record that limitation. Use accessible stills/transcript for the parts they actually support, and continue code work from this GDD where independent. Do not claim to have watched an hour, invent timestamps, or stop all code merely because the reference video is unavailable. A missing reference is different from a missing required runtime test tool.

---
## 17. Autonomous implementation phases

### 17.1 Rules for every phase

**Do the work, run the tests, fix failures, rerun affected regressions, record evidence, then continue. Do not ask "Should I continue?" or wait for user approval after an ordinary phase.**

Before each phase, read the latest status and relevant contracts. After it, record the files changed, test command/environment, commit/config version, expected and observed results, defects found and fixes applied. Use an executable test harness, not a Markdown checklist whose boxes were checked without execution.

Statuses:

| Status | Meaning |
|---|---|
| NOT STARTED | No implementation or evidence yet. |
| IN PROGRESS | Work/test execution underway. |
| FAIL | A required executed test failed. Fix before the dependent phase. |
| BLOCKED | Required capability, input, permission or external deliverable is missing. Describe it exactly. |
| PASS_CODE | This phase's required code/fixture tests passed on the recorded build. Does not claim final content integration. |
| PASS_INTEGRATED | Required tests passed with the actual intended content and required environments. |

A fixture substitution is allowed only where the phase explicitly calls for it. A simulation, mock save, device emulator or source review must be labeled as such. A real-client test cannot be replaced by claiming the code "should work."

On an external blocker, finish independent authorized tasks, write the smallest reproducible blocker and the exact missing capability, and stop only the dependent path. Do not request routine design approval, invent API results, delete features to get a green status, or mark an inaccessible test passed. Autonomous work still respects repository, publishing and credential permissions.

### Phase 00 — Protect the project and establish truth

**Owner: Claude.** Inspect the designated project, branch, dirty changes, README, existing scripts, toolchain, Rojo map and Studio connection. This is a new game's assignment; do not assume the active MABG repository is the target. Preserve all existing unrelated work. Do not run `rojo init` over an initialized repository. Do not use `git reset --hard`, `git clean -fd` or blanket restore commands.

Inventory actual capabilities: filesystem, git, Luau/lint tools, Studio read/write, runtime execution, multi-client tests, input automation, private-place publishing permissions, asset access and video inspection. Run a small canary test through available runtime tools instead of assuming the connection works. Keep one agent editing at a time.

Create the status, decisions, contracts, QA matrix and video-observation documents. Pin an intentional toolchain; install declared dependencies through the declared manager. An empty `Packages` folder is not proof that dependencies are installed. Select a free Rojo port; do not kill another game's server.

**Gate:** correct project/branch/Studio identity documented; prior changes preserved; test capability report written; canary result and build/dependency result recorded. A missing required runtime route blocks runtime phases, not documentation. Test IDs: ENV-01 through ENV-05.

### Phase 01 — Foundations, state and test harness

**Owner: Claude.** Implement shared types/configuration, bootstraps, lifecycle cleanup, semantic input contexts, protocol validation skeleton, round state machine, team/ready logic and the development wireframe adapter. Create pure tests and engine tests with a repeatable runner. Implement the tool scripts promised by the repository structure; document their actual invocation.

Use simulated score providers only in unit tests until real paint exists. A live round must not manufacture a winner from mock data. Create the plain `paint_lab` fixture and controlled test overrides. Implement safe character spawning and the default free loadout.

**Gate:** predictable boot, no duplicate services, correct round transitions under simulated time, safe start/stop, legal team capacities, input focus behavior and test controls inaccessible in production. Test IDs: FLOW-01 through FLOW-05, UI-01, SEC-01.

### Phase 02 — Prove painting before adding content

**Owner: Claude.** Implement surface manifests, masks, grid math, owner transitions, counts, paint stamps, occlusion, chunks, coherent snapshots and a renderer feasibility prototype. Verify floor/ramp/wall behavior and map-budget stress. Confirm the required rendering API works in the intended live context where authorized, or qualify an alternative.

Build a two-client test that paints, repaints, late-joins and resets. Compare authoritative buffers and rendered ownership at sampled cells. Test a wall with a paintable surface behind it and a ramp with rotated local axes.

**Gate:** deterministic score invariants; no through-cover paint; late join convergence; usable, bounded rendering; no unverified live-only API dependency concealed as complete. A failed renderer budget is a blocker to building the whole arsenal on that approach. Test IDs: PAINT-01 through PAINT-12, NET-01 through NET-03, PERF-01.

### Phase 03 — Movement, camera, paint tank and survivability

**Owner: Claude.** Implement the normalized rig's code setup, shoulder camera, legal aim/muzzle ray, glide, climb/mantle, paint refill, health regeneration and grounded/airborne state handling. Bind touch and gamepad through the same semantic actions. Use plain placeholders for animations and models.

**Gate:** own/neutral/enemy paint transitions match visible ownership; no wall clipping or flying; no camera lock during actions; resource accounting consistent; touch move/aim/fire infrastructure works simultaneously. Test IDs: MOVE-01 through MOVE-09, CAM-01 through CAM-03, UI-02.

### Phase 04 — First playable vertical slice

**Owner: Claude.** Implement Sprayline end to end: firing, predicted visuals, server projectile sweep, damage, tank costs, hit feedback, elimination, attribution, respawn, protection and frozen final results. Replace all live mock score providers with real paint. Complete one actual match, reset and play again with fixture content.

**Gate:** two real clients can fight, paint, eliminate, respawn and finish a correct round; an eight-client fixture test verifies capacity and replication. No double hits, firing from protected base or lingering dead-player input. This is the first functional game loop, not the final content milestone. Test IDs: COMBAT-01 through COMBAT-10, FLOW-06 through FLOW-08, NET-04.

### Phase 05 — Complete all seven main weapons

**Owner: Claude.** Implement the other six through shared attack primitives and immutable definitions. Add class-specific secondary actions and their device bindings. Complete Armory selection logic and fixed kits with placeholder icons. Keep every main weapon free and selectable.

**Gate:** all weapon-specific tests pass; costs, reach and damage match configuration; no shared volley double hits; dash/roll/push obey walls and paint restrictions; charge cannot be forged. Run the per-weapon balance scenario matrix and record actual findings. Test IDs: WEAPON-01 through WEAPON-09, COMBAT-11, UI-03.

### Phase 06 — Core tactical tools

**Owner: Claude.** Implement Splash Can, Paint Screen, Color Burst, Paintstorm, ultimate gain and Team Launch. Add the tactical map's functional data and selection logic. Test simultaneous use and all interruption/lifecycle paths.

All thrown gadget/ultimate capsules use swept ballistic collision and **stick at their first blocking world impact until their fuse expires**. They do not bounce unpredictably or attach to a moving character. Thrown capsules ignore character bodies during travel and collide with blocking world geometry or an enemy Paint Screen. Their explosion is the only damage source; there is no impact-hit bonus. Friendly screens are ignored by that owner's capsules. Paintstorm activates only with a legal supporting floor; the other capsules may burst at a valid wall impact, using clipped line-of-sight paint/damage.

**Gate:** gadgets/ultimates have visible functional warnings in wireframe form, meter cannot self-farm, screen never becomes invisible cover, launch destinations are server-validated, and old casts cannot affect a reset map. Test IDs: ABIL-01 through ABIL-10, MAP-01, SEC-02 through SEC-04.

### Phase 07 — Complete the player-facing loop

**Owner: Claude.** Finish all UI behaviors, loading/retry paths, results, Settings persistence, ready/unready, production-map loader contracts, backfill, vacancy pause, full reset and optional first-use guidance. Run these against contract fixtures until Codex provides the actual content. Do not create a cosmetic shop or decorative social hub.

**Gate:** a player can perform the entire join-to-next-round loop with keyboard/mouse, touch and gamepad via the wireframe; no dead buttons or wrong input contexts; late join and NoContest behavior are correct; both map manifest slots validate. Test IDs: FLOW-09 through FLOW-14, UI-04 through UI-10, DATA-01 through DATA-04, MAP-02 through MAP-04.

### Phase 08 — Harden, profile and prepare the Codex handoff

**Owner: Claude.** Run the full fixture regression, adversarial network suite and eight-client stress. Fix performance, leaks, validation gaps, camera/input bugs and telemetry ambiguities. Complete `ASSET_CONTRACT`, `UI_CONTRACT`, `MAP_CONTRACT`, `CODEX_HANDOFF` and the precise content inventory.

Run a 20-round fixture soak and record baseline timing/memory/network results. Leave a reproducible command/test procedure and a status report separating fixture results from unrun production-content/device results. Capture the relevant code commit and asset-contract version.

**Gate:** all required code/fixture tests pass; no known code-side core defects; complete content contracts; honest list of production tests still pending. Mark **CODE_READY_FOR_CODEX**. Test IDs: NET-05 through NET-08, SEC-05 through SEC-10, PERF-02 through PERF-05, OBS-01 through OBS-03, HANDOFF-01.

### Phase 09 — Production assets, maps and UI

**Owner: Codex. Claude does not take over asset creation.** Codex reads the GDD and handoff, confirms the same repository/branch/place, creates the original required content, implements it in the existing project, exports tracked assets and updates the manifest. Preserve code contracts and gameplay behavior.

Codex runs content validators and available visual/runtime checks, fixes map/UI/attachment problems and delivers a content report. It does not report code-side acceptance on Claude's behalf or quietly retune gameplay to fit a broken model. Broken content is repaired; a necessary contract change is versioned and handed back explicitly.

**Gate:** all required production assets exist, IDs/permissions work, both maps and UI satisfy contracts, original assets are tracked, content checks pass and no missing production item is hidden behind a placeholder. Test IDs: CONTENT-01 through CONTENT-08, HANDOFF-02.

**Handoff reality:** where an authorized agent-orchestration tool exists, the handoff may be executed through it. Otherwise Claude writes the complete handoff and reaches this milestone so the user can switch to Codex, as in the established sequential workflow. This is an external work handoff, not a request to approve each code phase. Claude must not claim to have run Codex automatically when it has not.

### Phase 10 — Claude verifies the actual game

**Owner: Claude, with content fixes returned to Codex when necessary.** Inspect the content diff and manifests, integrate code-side bindings, rerun **the complete matrix on both real maps with actual UI/models/animations**, and remove development-only content from the production path. Repeat network and eight-client stress because final art can change performance and visibility.

Run the 20-round production-content soak, the real-device matrix and an authorized private published smoke test. Verify live asset permissions, rendering, persistence, joining, round finish and replaying the next round. Do not publish over a live game or release publicly without the required publishing authorization.

**Gate:** all final acceptance requirements in Section 19 pass on the recorded release candidate. Mark **CORE_PVP_VERIFIED** only then. If an actual device/console/published test is inaccessible, report the precise remaining gate and do not make the corresponding readiness claim. Test IDs: FINAL-01 through FINAL-06 plus all prior applicable tests.

---

## 18. Executable QA catalog

This is the minimum required suite. Add regression cases whenever a new bug is found. The test ID belongs in the result log; the implementation determines the appropriate pure, engine, automated-input or physical-device runner. **The expected result is not an observed result.** No tests in this planning document have been run against a game yet.

### 18.1 Environment and round lifecycle

| ID | Test | Required result |
|---|---|---|
| ENV-01 | Inspect repository, branch, dirty work and connected place. | Correct new-game identity; no unrelated files or game overwritten. |
| ENV-02 | Build from tracked files and declared dependencies. | Reproducible build; no missing paths concealed by empty folders. |
| ENV-03 | Start server/client canary through available tools. | Real output/evidence; missing capabilities correctly marked. |
| ENV-04 | Reconnect Rojo with existing Studio content. | Defined ownership respected; content not unexpectedly removed. |
| ENV-05 | Start/stop tools while another game's port is active. | Free project port used; other game untouched. |
| FLOW-01 | One player joins. | Safe practice/waiting; no fake public match or forced purchase. |
| FLOW-02 | Four ready players begin countdown. | 20-second start and 2v2 assignment. |
| FLOW-03 | Eight ready during countdown. | Remaining time shortened to at most 5 seconds; teams 4v4. |
| FLOW-04 | Ready count drops below four before loading. | Countdown canceled once; no orphan timer. |
| FLOW-05 | Start with five/seven and repeatedly restart. | Capacity respected, size difference at most one, no duplicated rounds. |
| FLOW-06 | Complete timed live round with known cell counts. | Winner matches frozen server area, not kills. |
| FLOW-07 | Fire just before deadline, impact after it. | Late impact excluded; all clients show same result. |
| FLOW-08 | Two exact-area ties and a rounded-display near-tie. | True ties draw; raw-count winner preserved in near-tie. |
| FLOW-09 | Join mid-round with more than 60 seconds left. | Synced before combat; assigned legally to smaller team. |
| FLOW-10 | Join with 60 seconds or less remaining. | Staging until next round unless vacancy grace applies. |
| FLOW-11 | Entire team leaves, replacement joins within 15 seconds. | Combat/clock pause then resume correctly. |
| FLOW-12 | Entire team leaves without replacement. | NoContest and safe reset; no false win. |
| FLOW-13 | Reconnect during loading/results/reset. | Correct current state, no stale-life actions or blank permanent paint. |
| FLOW-14 | Alternate maps and reselect kits through 20 rounds. | Clean complete loop; free selection and correct per-round resets. |

### 18.2 Painting and movement

| ID | Test | Required result |
|---|---|---|
| PAINT-01 | Paint a known 10×10 valid scoring region. | Exact expected ownership; counts preserve invariant. |
| PAINT-02 | Repaint that region with the same team. | No score inflation or extra ultimate credit. |
| PAINT-03 | Opponent repaints half. | Exact transfer from old team to new team. |
| PAINT-04 | Paint wall, ceiling, protected base and hidden floor. | Only permitted wall ownership changes; no invalid score. |
| PAINT-05 | Paint rotated ramp and wall at corners. | Correct U/V orientation and no opposing-face leakage. |
| PAINT-06 | Blast one side of a thin wall. | No paint/damage through the wall. |
| PAINT-07 | Paint adjacent visible faces near an edge. | Allowed clipped coverage without painting occluded neighbors. |
| PAINT-08 | Run alternating-color worst-case pattern at map budget. | Correct rendering and bounded allocations; no lost ownership detail. |
| PAINT-09 | Switch local palette during a fight. | All paint/UI/effects agree; server team state unchanged. |
| PAINT-10 | Freeze results, then deliver old paint messages. | Frozen outcome unchanged. |
| PAINT-11 | Reset map while prediction/snapshot is pending. | Old-match state completely discarded. |
| PAINT-12 | Deny a locally predicted shot. | Ghost paint removed after acknowledgement within specified tolerance. |
| MOVE-01 | Walk/glide across friendly, neutral and enemy cells. | Correct speed and refill without boundary jitter. |
| MOVE-02 | Fire while gliding. | Legal exit-to-fire timing; camera still controlled. |
| MOVE-03 | Climb a friendly wall, then repaint it hostile. | Legal climb, then safe detach; no airborne lock. |
| MOVE-04 | Mantle to a blocked ledge or outer roof. | No clipping, illegal teleport or out-of-bounds shortcut. |
| MOVE-05 | Empty tank with every refill condition. | Rates/delays match config; no negative or free paint. |
| MOVE-06 | Charge/roll/push while trying to refill. | Mutually exclusive rules honored. |
| MOVE-07 | Reset/death while keys or touch buttons are held. | No persistent movement/fire loop in new life. |
| MOVE-08 | Dash/roll with low frame rate and large delta. | Swept collision; no wall passage or paint across teleport gaps. |
| MOVE-09 | Damage, wait, damage again during health refill. | Regen delay restarts; no extra regen from client manipulation. |
| CAM-01 | Aim around shoulder cover with blocked muzzle. | Shot blocked correctly; no wall penetration. |
| CAM-02 | Charge, gadget, ultimate, glide and climb while rotating view. | Continuous player camera control. |
| CAM-03 | Swap shoulder/resize viewport near walls. | Safe camera and accurate crosshair; no persistent clipping. |

### 18.3 Combat, weapons and abilities

| ID | Test | Required result |
|---|---|---|
| COMBAT-01 | Fire at legal enemy and friendly target. | Enemy damage only; exact paint cost. |
| COMBAT-02 | Re-send same attack sequence. | At most one accepted attack/damage/cost. |
| COMBAT-03 | Fire through static thin cover/accessory. | Cover blocks; non-hitbox accessory does not change damage shape. |
| COMBAT-04 | Hold fire with empty tank. | No damage/projectiles; rate-limited empty cue. |
| COMBAT-05 | Eliminate two players simultaneously. | Correct life-ending and independent attribution. |
| COMBAT-06 | Damage from two attackers, then elimination. | Final hitter credited once; assist threshold/window honored. |
| COMBAT-07 | Respawn while old projectile still exists. | Correct old attack attribution; new life cannot be hit as old life. |
| COMBAT-08 | Shoot into/out of protected base. | Protection blocks both directions as specified. |
| COMBAT-09 | Respawn shield then attack. | Shield removed before legal attack; no invulnerable offense. |
| COMBAT-10 | Fall out of bounds after an enemy hit. | Single elimination and correct recent-hit credit. |
| COMBAT-11 | Re-equip between rounds and respawn repeatedly. | Correct locked kit; no stacking weapon listeners/models. |
| WEAPON-01 | Sprayline cadence, range, five-hit body test. | Stats and paint trail match config. |
| WEAPON-02 | Twin Jets alternating attachments and dash into cover. | Single paid shot; dash bounded/no invulnerability. |
| WEAPON-03 | Roller stationary, moving, corner contact and flick. | No per-frame double damage; correct costs/footprints. |
| WEAPON-04 | Charger early release, full charge, cancel and fake duration. | Legal damage/cost only; no stored/forged charge. |
| WEAPON-05 | Splash Pot's three lobes hit same victim. | At most 55 direct damage for the volley. |
| WEAPON-06 | Brush primary/push spam at low FPS. | Mutual exclusion; no illegal speed or extra sweeps. |
| WEAPON-07 | Popshot direct plus blast overlap. | Direct victim takes 70 total, not 70 plus splash. |
| WEAPON-08 | Every class against walls, ramps, screens and shields. | Consistent obstruction and expected rejection reasons. |
| WEAPON-09 | Close/medium/long-range and 10-second paint trials. | Measured strengths/weaknesses; deviations documented and tuned. |
| ABIL-01 | Splash Can fuse, cost and duplicate request. | One paid can, correct fuse/damage and one result per victim. |
| ABIL-02 | Screen invalid placement and legal replacement. | Invalid placement free; legal state/cost atomic; old screen removed. |
| ABIL-03 | Destroy screen while firing through it. | Destroying shot consumed; no invisible blocker remains. |
| ABIL-04 | Ultimate credit on own floor, walls and ultimate paint. | Zero forbidden gain; changed-area and rate limits respected. |
| ABIL-05 | Die during ultimate preparation and after release. | Defined cancellation/continuation and no refund exploit. |
| ABIL-06 | Paintstorm below canopy and overlapping storms. | Cover works; damage does not multiply above defined tick cap. |
| ABIL-07 | Team Launch to legal teammate/base. | Server-selected safe landing and correct channel/cooldown. |
| ABIL-08 | Damage/move during launch channel. | Channel canceled; no unearned teleport. |
| ABIL-09 | Target dies or landing becomes invalid. | Correct predeparture cancel or in-transit base fallback. |
| ABIL-10 | Round ends with every ability active. | All old combat entities/tasks harmless and cleaned. |

### 18.4 UI, maps and content

| ID | Test | Required result |
|---|---|---|
| UI-01 | Bootstrap wireframe and switch input contexts. | Single UI root; no duplicate handlers. |
| UI-02 | Multi-touch move + aim + fire + glide transition. | All intended controls work without unintended drag/fire. |
| UI-03 | Select each free kit and spam Equip. | One server-confirmed selection; live changes disabled. |
| UI-04 | Entire flow with gamepad only. | Every screen reachable and escapable; correct glyphs. |
| UI-05 | All listed viewport/safe-area tests. | No clipped buttons, unreadable key text or overlap with system UI. |
| UI-06 | Long names/text and eight-player scoreboard/results. | Correct wrapping, scrolling and team grouping. |
| UI-07 | Open/close map and launch-selection errors. | Clear legal state; no enemy ESP or stuck input. |
| UI-08 | Loading, save failure, high latency and retry. | Honest, useful messages; no endless spinner/fake percentages. |
| UI-09 | Death/reconnect during modal transition. | Correct screen stack and new-life HUD. |
| UI-10 | Swap wireframe for production UI using same keys. | All bindings work; no dependency on old visual hierarchy. |
| MAP-01 | Tactical projection versus known floor ownership. | Same scoreable surfaces and ownership; no hidden second layer. |
| MAP-02 | Missing/duplicate surface ID or malformed mask. | Map rejected with a precise validation report. |
| MAP-03 | Spawn counts, symmetry and cover-route tests. | Both sides usable and no direct opposing-spawn sightline. |
| MAP-04 | Invalid/out-of-bounds climb, spawn and scoring areas. | No hidden score or escape route. |
| CONTENT-01 | Validate both actual map manifests. | All required folders/markers/masks/IDs/counts correct. |
| CONTENT-02 | Load every actual model/icon/audio/animation in target place. | Real accessible assets; no invented/private inaccessible IDs. |
| CONTENT-03 | Verify grips, muzzles and normalized character. | Visual and authoritative action geometry agree. |
| CONTENT-04 | Compare animation markers to configured attack times. | Readable synchronized presentation; damage independent of missing marker. |
| CONTENT-05 | Test production UI's mandatory keys/classes/templates. | No missing key or dead button; native interactive controls. |
| CONTENT-06 | Low-quality/team-palette warning readability. | Gameplay information remains visible and consistent. |
| CONTENT-07 | Build/import from tracked content into clean test place. | Same playable content without hidden Studio-only dependencies. |
| CONTENT-08 | Review originality/source/permission manifest and budgets. | Authorized original content; budget exceptions evidenced, not hidden. |

### 18.5 Network, security, saves and performance

| ID | Test | Required result |
|---|---|---|
| NET-01 | Paint snapshot with ongoing changes. | Coherent snapshot plus replay; no missing/newer-overwritten chunks. |
| NET-02 | Stale/gapped/reordered chunk versions. | Old data ignored; bounded resync restores exact state. |
| NET-03 | Disconnect during snapshot then join next round. | No retained old-match buffer or permanent blank paint. |
| NET-04 | Two/eight clients compare hits, paint and results. | Same authoritative state; expected prediction differences only. |
| NET-05 | 50/150/300 ms RTT, jitter and loss. | Convergence and bounded resource use; no duplicated attacks. |
| NET-06 | 600 ms degraded connection. | Clear degraded state; no automatic kick based solely on latency. |
| NET-07 | Charger rewind at/outside time bounds. | Capped legal rewind; static cover still blocks. |
| NET-08 | Saturated legal fire and resync under load. | Target traffic and sync budgets; no unbounded queue. |
| SEC-01 | Invoke development commands in production configuration. | Server refuses; no public debug control. |
| SEC-02 | Send arbitrary launch CFrame/enemy target. | Rejected; no position change. |
| SEC-03 | Fake gadget cost/ultimate meter/weapon stats. | Ignored/rejected; server definitions authoritative. |
| SEC-04 | Invoke damage/paint from a dead or old life. | Rejected with no mutation. |
| SEC-05 | Unknown IDs and oversized malformed payloads. | Cheap rejection, no exceptions or arbitrary loading. |
| SEC-06 | NaN/infinity and impossible origin/range. | Rejected before math/physics work corrupts state. |
| SEC-07 | Duplicate/future/ancient attack sequences/timestamps. | No replay, extra shots or unbounded rewind. |
| SEC-08 | Spam fire/ready/equip/resync requests. | Rate limiting, bounded logging and no denial-of-service cascade. |
| SEC-09 | Teleport movement during roll/glide. | No paint streak across map; lawful correction/diagnostics. |
| SEC-10 | Scan client-accessible code/content/logs. | No credentials, unsafe arbitrary remotes or unintended server secrets. |
| DATA-01 | Load, edit, rejoin with chosen kit/settings. | Valid preferences survive on actual permitted save path. |
| DATA-02 | Force read failure before default session. | Game usable; old unknown profile not overwritten. |
| DATA-03 | Unknown schema/invalid preference/concurrent sessions. | Safe defaults/merge policy; no destructive broad overwrite. |
| DATA-04 | Rapid sliders and shutdown/disconnect. | Debounced bounded writes; explicit success/failure status. |
| PERF-01 | Maximum supported grid and worst boundary pattern. | Correct and bounded renderer; actual live API path demonstrated. |
| PERF-02 | Eight clients, continuous fire, all ultimates/screens. | Meets recorded frame/network/entity budgets. |
| PERF-03 | 20-round soak after warmup. | No monotonic leaks; cleanup and memory target achieved. |
| PERF-04 | Actual mobile devices with production content. | Frame-time/hitch/readability targets; no thermal-memory crash in soak. |
| PERF-05 | Resize/palette/focus loss under combat load. | No big permanent allocation spike or stuck input state. |
| OBS-01 | Inspect milestone timings with known test clock. | Units/windows correct; unknown values remain null. |
| OBS-02 | Normal block/miss/shield versus invalid request. | Rejection categories and denominators distinguish them. |
| OBS-03 | Voluntary leave, explicit kick and poor FPS correlation. | Known exit fact separate from inferred cause. |

### 18.6 Handoff and release

| ID | Test | Required result |
|---|---|---|
| HANDOFF-01 | Claude-to-Codex handoff review. | Exact commit, contracts, inventory, fixture evidence and pending real-content tests. |
| HANDOFF-02 | Codex-to-Claude handoff review. | Exact content commit, asset permissions, changes and content test evidence. |
| FINAL-01 | Full matrix on both actual maps and production UI. | All applicable core tests pass; no wireframe substitution. |
| FINAL-02 | Real input/platform matrix with actual devices. | Evidence for each advertised supported platform. |
| FINAL-03 | Private published smoke test where authorized. | Actual assets, paint rendering, saves and multiplayer work outside Studio. |
| FINAL-04 | Clean tracked build then two complete rounds. | Reproducible playable release candidate. |
| FINAL-05 | Audit scope, open defects and debug controls. | No excluded systems, no known unresolved core defects, no exposed test tools. |
| FINAL-06 | Final status/evidence audit. | Readiness claims match what actually ran; missing access never labeled PASS. |

---

## 19. Final definition of done

The release candidate is **CORE_PVP_VERIFIED** only when all of the following are true on a named build:

1. A player can join, use the Armory, ready up, play, be eliminated, respawn, see correct results and enter the next round without operator intervention.
2. Both original maps are functional and fairly traversable from both sides. Spawn, climb, cover, boundaries and score masks pass validation.
3. All seven weapons, two gadgets, two ultimates and Team Launch work with actual models, timing and UI; every kit is free and a meaningful sidegrade.
4. Painting is visible and consistent with authoritative movement/refill/scoring. There is no through-wall claim, duplicate score, persistent ghost paint or late-join desynchronization.
5. Four-versus-four multiplayer, low-population fallback, odd counts, backfill, vacancy pause, NoContest and round-end cutoff all behave as specified.
6. Desktop, touch and gamepad UI/input flows pass. Actual device evidence supports mobile claims; actual console evidence supports console claims.
7. The complete actual-content regression and 20-round soak pass, with recorded performance/network/memory results and no known unresolved in-scope defect.
8. A clean tracked build reproduces the intended game, and an authorized published test verifies runtime-only requirements and asset permissions.
9. Development controls, fixtures and fake data cannot leak into production gameplay. No out-of-scope monetization/progression/content systems were added.
10. The final report includes the commit/config/content versions, executed tests, recorded devices, results, known limitations and the exact readiness status.

Do not write "fully tested," "zero bugs" or "ready for all devices" without the corresponding evidence and scope. Where access is missing, the correct deliverable is a precise release-candidate report with the remaining gate, not a false completion claim.

**The end of this GDD is the end of the current assignment. Do not begin PvE, ranked, cosmetics, events or any other expansion after the core passes. Those require a separate future scope.**

---

## 20. Required project reports and agent start messages

### 20.1 Phase report template

```text
Phase ID / title:
Status: PASS_CODE | PASS_INTEGRATED | FAIL | BLOCKED
Project / place / branch:
Commit / configuration / content contract version:
Implementation completed:
Files changed:
Tests executed (IDs + actual invocation):
Environment / client count / device / network settings:
Expected results:
Observed results:
Evidence paths:
Defects found and fixes:
Regressions rerun:
Unrun tests or external blockers:
Next automatic step:
```

`IMPLEMENTATION_STATUS.md` lists every phase, status, latest evidence and current blocker. `DECISIONS.md` records a changed specification, reason, alternatives, measured consequence and affected tests. `QA_MATRIX.md` links each test to its latest actual result. These are maintained during the work, not reconstructed from memory at the end.

### 20.2 Message to start Claude

> Read `Color_Clash_Master_GDD.md` completely and use it as the authority for this project. Build only the core PvP release described there. You own code, gameplay, networking, functional UI controllers, integration and testing. Codex owns the actual maps, models, animations, UI layouts, icons, VFX and audio assets. Use plain development fixtures/wireframes where the GDD permits; do not spend the coding pass producing art. Work through Phases 00–08, testing and repairing each phase before continuing automatically. Do not stop for my routine review or approval. Preserve existing work and use the designated project only. Keep the status, decisions, contracts and test evidence current. At the end, deliver the complete Codex handoff and mark CODE_READY_FOR_CODEX, not game complete. After Codex implements content, resume Phase 10 and verify the actual game. Never claim a video was watched, a test passed or a device was verified when it was not. Do not build any excluded extra systems.

### 20.3 Message to start Codex

> Read the master GDD, current implementation status and Claude's CODEX_HANDOFF before editing. Continue in the same designated project, repository, work branch and established Rojo/Studio setup; do not start a second project or overwrite gameplay. You own Phase 09: create and directly implement the two original arenas, normalized character, seven weapon models, gadget/ultimate assets, animations, production native UI, icons, VFX and authorized audio. Follow the asset, map and UI contracts exactly. Preserve IDs, attachments, timings and code-owned behavior. Test your content, keep it within the measured budgets, export tracked representations and record real asset IDs/permissions. Do not add shops, cosmetics systems, ranked, PvE or other excluded features. Finish with a complete content report and return the project to Claude for final integration verification.

### 20.4 Message to resume Claude after Codex

> Read the latest GDD/status, Codex's content report, git changes and current Studio content. Run Phase 10 against the real production maps, UI, models and animations. Validate every contract, repair code-side integration issues and identify any content defects precisely for Codex. Rerun the complete applicable matrix, eight-client stress, 20-round soak and authorized published/device tests. Continue without routine approval requests. Mark CORE_PVP_VERIFIED only when the evidence supports it; otherwise report the exact remaining gate. Do not expand beyond the core PvP assignment.

---

## 21. Primary-source register and verification notes

Sources were checked on 29 September 2026. API availability can depend on the actual experience, permission and Studio version; Claude must verify those conditions during Phase 00/02. Source notes support platform/reference facts. **The design decisions and proposed values in this GDD are our specifications, not quotations or extracted source-game data.**

| Ref | Primary source | Relevant verified fact |
|---|---|---|
| R01 | Nintendo — Splatoon 3 official product/gameplay page | Paint, dive/swim and combat loop; main/sub/special weapon kits; variety of main weapon types. |
| R02 | Nintendo Support — How to Start a Local or Online Multiplayer Game, Splatoon 3 | Standard online battle fills to eight players; distinguishes matchmaking from party size. |
| R03 | Roblox Creator Hub — Securing the client-server boundary | Server-side validation of requests, values, targeting, resources and request rates. |
| R04 | Roblox creator-docs — UnreliableRemoteEvent API | Unreliable/unordered delivery and bounded payloads; unsuitable as the sole source of persistent territory truth. |
| R05 | Roblox creator-docs — EditableImage API | Runtime image creation/display, memory constraints, published enablement, size and update limitations. |
| R06 | Roblox Creator Hub — Input Action System | Actions, bindings and input contexts for device-independent control logic. |
| R07 | Roblox Creator Hub — Studio testing modes | Client/server, multi-client, device and network testing capabilities; verify available automation in the actual environment. |
| R08 | Roblox Creator Hub — Raycasting | Spatial ray queries, filters and collision/query behavior. |
| R09 | Roblox Creator Hub — Data model | Roles of shared, server and client containers. |
| R10 | Roblox Creator Hub — Size modifiers and constraints | Responsive sizing, automatic sizing and size/text/aspect constraints. |
| R11 | Roblox Creator Hub — ScreenGui | Screen insets and safe-area-related properties. |
| R12 | Roblox Creator Hub — Data stores | Persistent server-side storage operations and error handling. |
| R13 | Roblox Creator Hub — MicroProfiler | Profiling frame execution and diagnosing performance work. |
| R14 | Rojo — Sync Details | Filesystem-to-instance synchronization and supported representations. |
| R15 | Rojo — Project Format | Explicit project trees, paths and synchronization configuration. |

### Source links

- **R01:** [Nintendo Splatoon 3](https://www.nintendo.com/us/store/products/splatoon-3-switch/)
- **R02:** [Nintendo multiplayer support](https://en-americas-support.nintendo.com/app/answers/detail/a_id/59459/)
- **R03:** [Roblox client-server boundary](https://create.roblox.com/docs/scripting/security/client-server-boundary)
- **R04:** [Roblox UnreliableRemoteEvent source documentation](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/UnreliableRemoteEvent.yaml)
- **R05:** [Roblox EditableImage source documentation](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/EditableImage.yaml)
- **R06:** [Roblox Input Action System](https://create.roblox.com/docs/input/input-action-system)
- **R07:** [Roblox Studio testing modes](https://create.roblox.com/docs/studio/testing-modes)
- **R08:** [Roblox raycasting](https://create.roblox.com/docs/workspace/raycasting)
- **R09:** [Roblox data model](https://create.roblox.com/docs/projects/data-model)
- **R10:** [Roblox UI size modifiers](https://create.roblox.com/docs/ui/size-modifiers)
- **R11:** [Roblox ScreenGui](https://create.roblox.com/docs/reference/engine/classes/ScreenGui)
- **R12:** [Roblox Data stores](https://create.roblox.com/docs/cloud-services/data-stores)
- **R13:** [Roblox MicroProfiler](https://create.roblox.com/docs/performance-optimization/microprofiler)
- **R14:** [Rojo Sync Details](https://rojo.space/docs/v7/sync-details/)
- **R15:** [Rojo Project Format](https://rojo.space/docs/v7/project-format/)

---

**END OF CORE PVP SCOPE · Build it, test it, integrate the real content, verify it — then stop.**
