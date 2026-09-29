# Video Observations — Colorclashvideoreference

Status: **INITIAL REVIEW COMPLETE** (2026-09-29). Re-open specific windows as later phases need them.

This file follows GDD Section 16 and START_HERE B/C. Entries separate **OBSERVED** (visible in an extracted image),
**INFERENCE** (reasoned, not directly shown) and **PROPOSED** (an experiment or change for our game). The footage is a
feel/behaviour reference only. Our four-minute timer, free kits, normalized character, enemy-paint simplification and
original maps stay binding (GDD 16.2). Nothing here changes a GDD value unless recorded in `docs/DECISIONS.md`.
Nintendo presentation (characters, judge mascot, "GAME!" tape, squid glyphs, maps, audio) is **not** to be copied.

## 1. Source and method

| Field | Value (ffprobe, 2026-09-29) |
|---|---|
| Path | `C:\Color-Clash\Colorclashvideoreference.mp4` (the user also named `C:\ColorClash`; that path does not exist) |
| Container | MP4, 1,827,420,759 bytes, 4.39 Mb/s |
| Duration | 3332.27 s (00:55:32); video stream 3332.18 s |
| Video | H.264 High, 1920×1080, 60/1 fps constant (r_frame_rate = avg_frame_rate), 199,931 frames, start 0 |
| Audio | AAC LC 44.1 kHz stereo. **Not processed or listened to.** No transcript available. |
| Original | Never modified, re-encoded or uploaded. Frames were decoded locally with ffmpeg. |

- Tools: `tools/extract_video_frames.py` (overview / window / sheets modes), `tools/check_manifest.py`,
  `tools/crop_frames.py`. Python 3.12.10 venv `tools/.venv` + Pillow 12.3.0, ffmpeg/ffprobe (WinGet).
- Timestamps are real source PTS from ffmpeg `showinfo` with `-copyts` (not sequence numbers). Overview: 335 frames,
  every 10 s from 0 to 3330 s plus a tail frame at 3331.283 s; max |PTS − requested| = 0.011 s; PTS strictly increasing.
- **Playback speed verified 1.0×:** in both detailed rounds, "GO!" → "GAME!" spans 180 s of PTS time, matching the
  3:00 on-screen round timer (Urchin 09:32→12:31; Blackbelly 28:19→31:19). A 0.5 s window at source rate
  (`windows/bb_fire_60fps`) produced 30 distinct PTS values → true 60 fps content.
- Evidence root (git-ignored, regenerate with the script): `reference/video_review/`
  - `overview/` 335 frames + `sheets/` 38 contact sheets (3×3)
  - `windows/round_urchin_0915/` 220 frames @1 fps (09:15–12:54) + 19 sheets
  - `windows/round_blackbelly_2805/` 220 frames @1 fps (28:05–31:44) + 19 sheets
  - `windows/bb_respawn_10fps` (29:23–29:33), `bb_refill_10fps` (28:34–28:41), `bb_climb_10fps` (30:41–30:47),
    `bb_results_5fps` (31:19–31:34), `bb_fire_60fps` (28:20.0–28:20.5)
  - `crops/refill_gauge.jpg` (full-resolution crop of the swim tank gauge)
- Who looked: every overview sheet and both 1 fps rounds were opened and inspected by model reviewers (Claude
  subagents, one batch each, with per-sheet notes in `docs/video_review/*.md`). The 10/5/60 fps windows and crops were
  inspected directly by the main Claude session. Image analysis runs on the model service, not offline.
- Coverage honesty: sampled coverage only. The overview is 1 frame / 10 s; two rounds at 1 fps; five short windows at
  5–60 fps. Not every frame of the hour was watched. Anything shorter than the sampling interval may be missed.

## 2. Identification and scope map

**OBSERVED** 00:00:00 title screen with a Wii U badge (`overview/ov_0000*`): the original 2015 Wii U *Splatoon*.
Confidence high. Mode names on intro cards: "Turf War / Ink the most turf to win!".

| Range | Content | Scope |
|---|---|---|
| 00:00:00–00:01:00 | Title, loading pattern, character select, story dialogue | Out of scope |
| 00:01:00–≈00:09:00 | Single-player movement tutorial (shoot, swim, wall swim, dash-jump prompts) | Out of scope (tutorial course); informs our 3 onboarding lines |
| ≈09:15–12:54 | **Turf War 1** — Urchin Underpass, orange vs teal, defeat 34.6% vs 50.7% | **In scope** (reviewed @1 fps) |
| ≈13:34–16:50 | **Turf War 2** — probably Blackbelly Skatepark, orange vs blue, victory 56.0% vs 33.0% | In scope (overview only) |
| 17:00–19:20 | Plaza, shops, gear, level-up | Out of scope (shops/cosmetics/progression) |
| ≈19:57–23:10 | **Turf War 3** — Blackbelly Skatepark, pink vs green, defeat 36.5% vs 48.1% | In scope (overview) |
| ≈24:15–27:30 | **Turf War 4** — Urchin Underpass, orange vs teal, victory 48.0% vs 38.3% | In scope (overview) |
| 28:05–31:44 | **Turf War 5** — Blackbelly Skatepark, blue vs orange, victory 59.4% vs 27.6% | **In scope** (reviewed @1 fps + 10/5/60 fps windows) |
| 31:50–33:00 | Rewards, stage news, plaza | Out of scope |
| ≈33:34–36:50 | **Turf War 6** — offshore rig (probably Saltspray Rig), magenta vs lime, victory | In scope (overview) |
| ≈37:27–40:40 | **Turf War 7** — same rig, pink vs turquoise, defeat 32.9% vs 50.0% | In scope (overview) |
| 40:50–46:30 | Rewards, level-up, loading, hat/clothing/shoe shops, gear ordering | Out of scope |
| 47:10–54:40 | Octo Valley story mode and mission 1 | Out of scope (PvE/story) |
| 54:50–55:31 | Plaza, then the video creator's webcam outro / end card | Out of scope |

No ranked modes (Splat Zones, Tower Control, Rainmaker) were identified in the samples. All seven rounds are 4v4 Turf
War with a 3:00 timer. Per-batch detail: `docs/video_review/batch_A_002-010.md` … `batch_D_029-037.md`.

## 3. Observations by mechanic

Evidence paths are relative to `reference/video_review/`. "BB" = Blackbelly round (Turf War 5), "UU" = Urchin round (Turf War 1).

### 3.1 Round flow, start and final seconds — GDD 03.1, 03.2, 03.4, 12.1

- **OBSERVED** (UU 1 fps, `windows/round_urchin_0915/w_00000…w_00017`): lobby "BATTLE TIME!" → iris wipe + ~4 s
  black loader → ~4 s stage fly-over card (mode, one-line objective, map name) → own team, then enemy team pop out on
  spawn pads with name tags → "Ready?" (~2 s) → "GO!" with HUD appearing at 3:00. Intro card → GO ≈ 12–13 s.
  BB matches (`w_00002…w_00014`). Confidence high.
- **OBSERVED**: "1 minute left!" banner and timer turns yellow at 1:00 (UU `w_00137`, BB `w_00134`). Final 10→1 large
  outlined numerals centre-screen at 1 per second (UU `w_00186…w_00195`, BB `w_00184…w_00193`). "GAME!" freeze ~3–4 s.
- **OBSERVED**: first contact with enemy paint ≈ 25–35 s after GO in both rounds (UU `w_00043–w_00051`; BB
  `w_00040`). **INFERENCE**: those players painted home turf first; a direct route would be faster. Not a measure of
  map size. After respawn, BB reached the first contested bowl ~3–4 s after leaving the pad (`w_00085…w_00089`).
- GDD link: our Intro is 3 s (no fly-over), Live is 240 s, final cue at 30 s (timer/colour/audio only).
  **PROPOSED test**: FLOW-06 instrument spawn→first-contested-cell time per team on each map (target 8–12 s, GDD 03.1).

### 3.2 Results reveal — GDD 03.3, 12.1 (Results, "Coverage Reveal")

- **OBSERVED** (BB 5 fps, `windows/bb_results_5fps/sheets/sheet_001*, sheet_002*`): GAME! tape until 31:23.6 →
  orthographic top-down map of all paint 31:23.8–31:25.0 → both teams' bars count up **in lockstep** from 0.0%
  (31:25.2) to 26.0% (31:27.6) → ~0.6 s hold → winner's bar jumps to 50.3% then 59.4% (31:28.4–31:28.6) while the loser
  stays at 27.6% → winner flag → "VICTORY!" splash 31:29.2–31:29.4. Each side also shows team points (908p / 423p).
- **OBSERVED**: 59.4% + 27.6% = 87.0%. The remaining ~13% unclaimed floor is **never displayed**.
- **OBSERVED**: then per-player scoreboard with points, splats, times splatted (UU `w_00212`, BB `w_00211…w_00216`),
  then cash/XP rewards (out of scope).
- GDD link / PROPOSED: our Coverage Reveal keeps the readable suspense structure — top-down map, then lockstep
  count-up to the lower team's value, short hold, winner continues — but **always shows the neutral share** and
  decides from frozen raw counts (GDD 03.3). Total reveal ≈ 5–6 s fits inside our 10 s Results. No rewards screen.

### 3.3 Friendly vs enemy paint readability — GDD 04.4, 10, 12

- **OBSERVED**: two saturated complementary team hues on a desaturated grey/white/black level palette. Colour pairs
  change per round: orange/teal, orange/blue, pink/green, blue/orange, magenta/lime, pink/turquoise. Newer paint
  overwrites older with a hard edge. Blobby outlines with droplets. Glossy highlights (UU `w_00025`, `w_00100`; BB `w_00042`, `w_00114`).
- **OBSERVED**: walls take paint like floors (UU `w_00087`; BB `w_00030`, `w_00159`). During a large wall paint the
  points counter barely moved (UU 10:39–10:42, 0294→0295). **INFERENCE**: walls are not scored. Consistent with our
  zero-score walls (GDD 03.3).
- **OBSERVED**: grates stay unpainted between bars (UU `w_00023`). Matches our non-paintable grating connectors.
- **INFERENCE** splat size: one shooter impact ≈ 1 character width; walk-and-fire lane ≈ 1–2 character widths (UU
  `w_00111…w_00119`, BB `w_00025`). Our Sprayline radius-2 impacts (4 studs) plus drips on a ~2-stud-wide rig give a
  comparable lane. **PROPOSED test**: WEAPON-09 10-second coverage trial and a screenshot comparison.
- GDD link: we store ownership as team IDs and recolour locally (04.4 palette). The reference's per-round colour pairs
  support our client palette approach. Not copied: glossy fluid rendering. Our renderer draws flat per-cell
  ownership (D-004).

### 3.4 Paint tank and refill — GDD 05.3, 12.1 HUD

- **OBSERVED**: no permanent tank bar on the HUD. Three signals: (1) a diegetic tank on the character's back that
  empties to white (UU `w_00100` empty, `w_00122` ~1/3); (2) a "Low ink!" tag with red tank icon under/behind the
  character (UU `w_00036`, `w_00103`; BB `w_00031`, `w_00106`, `bb_refill_10fps` #19 at 28:35.9); (3) a small capsule
  gauge beside the reticle **only while swimming**.
- **OBSERVED (10 fps + crop, `crops/refill_gauge.jpg`)**: low-ink dive at 28:36.7 → gauge empty 28:37.0 → ~15%
  37.4 → ~35% 37.8 → ~70% 38.6 → ~95% 39.0 → full ≈ 39.4 → player surfaces and resumes painting ≈ 39.7 (points
  0109→0110 at 39.9). **Empty-to-full while swimming ≈ 2.4 s; dive-to-resumed-fire ≈ 3.0 s.** Confidence medium-high
  (±0.1 s from 10 fps). Fill during the first ~0.3 s was not visible, so the exact start delay is uncertain.
- **OBSERVED**: typical BB cycle ≈ 15–17 s of mostly continuous fire → "Low ink!" → 2–4 s swim → fire again.
- GDD link: our Own paint + Glide refill is 30/s after 0.35 s → empty-to-full ≈ 3.68 s (slower than the reference ~2.4 s).
  **PROPOSED tuning experiment (not applied)**: after Phase 05, measure time-to-empty per weapon. If refill downtime
  feels punishing in playtests, trial Glide 40/s (full in 2.85 s) and log it as a decision. Test: MOVE-05.
  Our HUD keeps a visible paint meter (GDD 12.1 requires HUD.Paint). The contextual gauge near the reticle while gliding
  and the "Low paint" warning below 20 are good presentation notes for Codex.

### 3.5 Camera — GDD 04.2

- **OBSERVED**: third-person behind and above; character roughly centred horizontally with no clear shoulder offset;
  standing character ≈ 20–27% of screen height; reticle just above screen centre, above the head (UU `w_00184`;
  BB `w_00097`, `w_00114`).
- **OBSERVED**: while swimming the camera sits lower and closer to the surface (UU `w_00041`, `w_00081`). Looking down,
  the camera rises over the head. Looking up, it drops below/behind (BB `w_00016`, `w_00118`).
- **OBSERVED (10 fps, `bb_climb_10fps` 30:42.1–30:43.2)**: during a wall swim the camera stays behind the player and
  pitches up. It does not rotate onto the wall plane. Matches GDD 05.2 ("Do not rotate the whole camera onto the wall").
- **OBSERVED**: near walls the camera slides along the wall; thin geometry can pass between camera and player (BB
  `w_00144`); foliage fades (UU `w_00025`).
- GDD link: our camera keeps the specified right shoulder offset (1.75) with shoulder swap. That's a deliberate
  difference for aiming around cover. **PROPOSED**: a slightly lower camera while gliding (presentation only;
  CAM-02 must still show continuous control). FOV feels ~70–80°; our 75° default is consistent (INFERENCE).

### 3.6 Movement: swim/glide, enemy paint, climb, jump — GDD 05.1, 05.2

- **OBSERVED**: in own paint the swimming character is nearly invisible — ripple/wake and splash only (UU `w_00081`;
  BB `w_00033`, `bb_refill_10fps` #26–#39). In enemy paint the swimmer is fully exposed and splashed (UU `w_00148`;
  BB `w_00121`, `w_00178`). Speed differences cannot be measured from these samples.
- **OBSERVED (10 fps, `bb_climb_10fps`)**: "Low ink!" 30:41.5 → dive 41.9 → swims up a blue-painted wall 42.1–42.6
  (wall ≈ 1.5 character heights) → tops out with a splash 42.7–43.0 → walking on the ledge 43.2 → taking fire 43.5.
  The climb is only on own-colour paint (UU `w_00090`, `w_00091`). Confidence medium (climb speed not measured precisely).
- **OBSERVED**: surfacing jump throws a tall ink column (UU `w_00157`). The tutorial teaches a swim dash-jump
  (overview 00:02:30–00:02:50).
- GDD link: our Paint Glide is a low stance, not invisibility (05.2 — deliberate). Wake readability is a Codex VFX
  note. Enemy-paint slow applies to everyone (05.1). **Tests**: MOVE-01 (speeds per ownership), MOVE-03 (climb then
  hostile repaint detaches), MOVE-04 (mantle clearance).

### 3.7 Damage, elimination, respawn — GDD 05.4, 06.3, 06.4, 12.1 Elimination

- **OBSERVED**: damage feedback is an ink-splatter vignette around the screen edges that grows with damage and clears
  a few seconds after escaping. UU shows it in enemy colour. BB shows it red/magenta (`bb_respawn_10fps` #0–#19,
  `bb_climb_10fps` #25+). No HP bar. No numbers.
- **OBSERVED (10 fps, `bb_respawn_10fps`)**, precise chain for one death:
  - 29:24.2 elimination burst (white flash + enemy-colour burst); a ghost-squid glyph rises by 24.6
  - 25.0–26.0 kill-cam pans to the attacker
  - 26.2 bottom-right "Respawn in 4" banner; 26.3 "Splatted by .52 Gal!" card + attacker's gear panel
  - 29.0–29.5 "Respawn in 1"; 29.6 camera cuts behind the own spawn pad; 30.0–30.5 player flies in from the sky
  - 31.0–31.5 character stands on the pad; 31.6 dives into own paint; ≈31.9 moving under control
  - **Elimination → control ≈ 7.7 s** (the 1 fps estimates of 5–7 s were low). Confidence high (±0.1 s).
- **OBSERVED**: roster icon of an eliminated player turns dark with X eyes (BB `w_00042`, `w_00079`). A held special
  gauge dropped from full to ≈ half on death (UU 10:13→10:17, `w_00062`).
- **OBSERVED**: no visible spawn-protection effect in any sample (06.4: nothing to compare).
- GDD link: our 4 s respawn (06.3) is much faster than the reference's ~7.7 s. Keep 4 s (binding). **PROPOSED**:
  keep an ~1 s attacker-identification beat inside the 4 s (Elimination screen shows attacker + weapon + countdown,
  GDD 12.1); no kill-cam camera takeover. Death retains 50% of ultimate — matches the reference's visible
  halving (INFERENCE). **Tests**: COMBAT-05/06/07, UI-09.

### 3.8 Specials, sub-weapons, super jump — GDD 08.1, 08.3, 08.4

- **OBSERVED**: special gauge = ring around an icon at top-right, filling with painting. When full: "Charged!" text,
  button prompt and an aura burst on the character (UU `w_00046`, `w_00098`; BB `w_00055`, `bb_climb_10fps` #0–#4).
  Activation shows a banner with the special's name and the user's portrait. The ring becomes a draining duration
  timer (UU `w_00141`, `w_00143`; BB `w_00064`). Teammates' activations use the same banner. A player can bank a
  charged special (~35 s in BB).
- **OBSERVED**: enemy charger aim line visible to its target (thin straight line; BB `w_00042`, `w_00062`, `w_00162`).
- **OBSERVED**: only an enemy-placed sprinkler-like device (BB `w_00048`) and a dotted throw arc with landing ring in
  story mode (overview 00:50:20, out of scope). **No PvP sub-weapon throw, bomb explosion or throw preview was
  captured** in the reviewed samples.
- **INFERENCE only**: a golden ring + ally name + "3" at the player's feet (UU `w_00185`, `w_00187`) may be a super
  jump landing marker. **The super jump itself was not observed.**
- GDD link / PROPOSED: our Linecaster needs its line-of-sight-clipped aim warning (07.3) — the reference confirms that
  a visible aim line is readable. Ultimate HUD: ring fill + "ready" callout + activation banner is a good wireframe
  pattern (HUD.Ultimate). Team Launch marker must be enemy-readable (08.4). No reference timing exists for it.

### 3.9 HUD layout — GDD 12.2

**OBSERVED** (1280×720 positions, UU `w_00021`, BB `w_00016`):

| Element | Position | Our equivalent |
|---|---|---|
| Timer (stopwatch + m:ss, yellow ≤ 1:00) | top-left | HUD.Timer — GDD puts it **top centre** with the coverage bar (keep GDD) |
| 4 vs 4 roster icons, X when eliminated | top-centre | Scoreboard/HUD team strip (functional wireframe) |
| Personal points counter | top-right | Not a HUD element for us (Paint Contribution lives on the scoreboard, labelled as contribution) |
| Special ring gauge + "Charged!" / button prompt | far top-right | HUD.Ultimate (GDD: lower right on desktop) |
| Reticle (circle + 4 spread ticks while firing; hit "X" flash) | just above centre | HUD.Reticle with spread/charge state; confirmed-hit marker distinct from local cue (06.2) |
| "Low ink!" tag | under the character | low-paint warning < 20 |
| Kill notice "Splatted <name>!" | bottom-centre, ~4–5 s | brief notice above reticle (12.2) |
| Death card, attacker gear, "Respawn in N" | centre-top / left / bottom-right | Elimination.Root / Elimination.Countdown |
| Damage vignette | all edges | presentation note (reduced-effects setting must still keep it readable) |

- **OBSERVED**: **no minimap on the TV HUD** in any PvP sample. The original shows it on the Wii U GamePad; that screen
  isn't in the recording. The only full-map view is the post-game top-down (BB `w_00199`). Our tactical map (10.7)
  has no direct reference. The top-down reveal is a style note only.

### 3.10 Weapons seen — GDD 07

- **OBSERVED**: the POV player used a compact automatic shooter throughout (UU/BB): continuous blob stream, warm muzzle
  flash, arcing fall-off. Range feel ≈ 6–8 character lengths on flat ground (INFERENCE). Enemies/allies used a heavier
  automatic (".52 Gal" per kill cards), a roller ("Squished by…"), a charger with aim line and a junior shooter.
- Not observed: dual pistols, lobber (slosher), brush, blaster. Nothing about damage values, hitboxes or netcode can
  be inferred, and none is claimed.

## 4. GDD 16.2 questions answered

| Question | Answer from the footage | Confidence |
|---|---|---|
| How quickly does a player return to useful action? | Elimination → control ≈ 7.7 s; pad → first contested area ≈ 3–4 s on BB | High / medium |
| How is friendly paint distinguished from hostile paint? | Two saturated complementary hues per round on a neutral grey level; hard overwrite edges | High |
| What tells the player the tank is empty? | Diegetic back tank turning white + "Low ink!" tag; swim gauge by the reticle | High |
| How does the camera behave during movement and attacks? | Centred third-person; lower while swimming; pitch-dependent height; no roll onto walls | Medium-high |
| How readable are charge/grenade/shield/ultimate warnings? | Charger aim line readable; special "Charged!"/banner clear; grenade warnings **not captured** | Medium / not observed |
| How much uninterrupted floor does a typical shot paint? | ≈ 1 character width per impact; 1–2 widths per walking lane | Low-medium (inference) |
| How does a weapon communicate its strengths? | Distinct silhouettes and spray patterns; kill cards name the weapon | Medium |
| How is the final winner revealed? | Top-down map → lockstep count-up → loser stops → winner continues → VICTORY/DEFEAT; neutral hidden | High |

## 5. Required GDD mechanics absent from (or not captured in) the recording

Team Launch launch/transit/landing (only a possible marker). Paint Screen and any placeable wall-type gadget. Grenade
throw preview, fuse warning and explosion in PvP. Paintstorm-like rain ultimate. Color Burst-like capsule ultimate. Dual
weapon dodge-dash. Lobber, brush and blaster play. Roller rolling paint strip (only kill notices). Tactical map/minimap
(on the GamePad, not recorded). Spawn protection/shield. Base boundary blocking. Late join, backfill, vacancy pause and
NoContest. 4-minute rounds, 2v2/odd populations. Touch/gamepad control layouts for our platforms. Settings and
accessibility palette. Audio cues (not processed). These must be designed and verified from the GDD alone.

## 6. Visual-reference notes for Codex (original art only)

- Keep a **neutral, desaturated arena palette** so both team colours pop; paint needs strong contrast on floors and walls.
- Make **grating/non-paintable** surfaces visibly different (reference grates stay unpainted).
- Readable glide wake in own paint; a clearly exposed/splashed look when a player is in enemy paint.
- Elimination: short paint burst + small rising glyph (original design), no long ragdoll.
- Respawn: a readable arrival on the base pad (the reference uses a sky drop — ours must not delay the 4 s timer).
- Results: an original top-down/coverage reveal with a lockstep count-up and a clear winner flourish, **including
  neutral share**.
- Do not reuse the judge mascot, caution-tape "GAME!", squid glyphs, map layouts, HUD art or colour sets.

## 7. Limitations

- Sampled review only; no claim that every frame of the hour was seen.
- Audio not processed; no transcript.
- Map names for Turf War 2, 6 and 7 are inferred (no name card in the sample).
- Movement speeds, damage, ranges and hitboxes cannot be measured from footage and are not claimed.
- Two of seven rounds were reviewed at 1 fps; five short windows at higher rates.
