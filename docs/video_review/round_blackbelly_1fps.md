# Round review — Blackbelly Skatepark, Turf War (1 fps sampled)

Source: original Wii U *Splatoon* (2015) gameplay reference. Feel/behaviour reference only; no assets copied.
Frames: `C:\Color-Clash\reference\video_review\windows\round_blackbelly_2805\w_<idx>_<HH-MM-SS.mmm>.jpg` (1280x720, 1 fps).
Sheets: `...\round_blackbelly_2805\sheets\sheet_NNN_*.jpg` (4x3, 12 frames each).
Coverage caveat: 1 fps sampling. Anything happening between samples was NOT seen. Audio not processed.
Notation: **OBS** = visible in frames; **INF** = inference.

---

## Running notes per sheet

### Sheet 000 (00:28:05–00:28:16)
- OBS 00:28:05–06 (#0–1): black screen, small purple ink-blob loading glyph bottom-right-centre (w_00000, w_00001). Load/transition.
- OBS 00:28:07–11 (#2–6): map flyover of Blackbelly Skatepark (high aerial camera, slow pan). Overlay text: mode name small ("Turf War"), large objective line ("Ink the most turf to win!"), map name bottom-right. Unpainted map = grey concrete/white ramps. #6 fades to white (w_00006) = transition.
- OBS 00:28:12–14 (#7–9): intro camera on BLUE team spawn pad (circular pad filled with blue ink, ringed metal base). #7: pad alone with blue ink; #8: 4 players appear as blue squid forms on pad with name tags floating above (e.g. "Tommy", "Cesar", "ZackScott"...). #9: they pop into humanoid (kid) form holding weapons (one roller visible). Name tags small white text with small down-arrow above each head.
- OBS 00:28:15–16 (#10–11): same presentation for ORANGE team pad (pad empty → players appear with name tags). Colours this round: **blue (purple-blue) vs orange**.
- INF: Intro shows own team first, then opposing team, ~2 s each. Team colour is baked into spawn pad fill = instant team identification.
- GDD 03 (round flow): map card ~5 s (07–11) + team reveal ~4 s (12–16) before gameplay.

### Sheet 001 (00:28:17–00:28:28)
- OBS 00:28:17 (#12, w_00012): orange team on pad, still intro.
- OBS 00:28:18 (#13, w_00013): gameplay camera behind own player on spawn pad; large white "Ready..." text upper-left/centre; "You" label with down-arrow over own player; teammates' name tags ("Cesar", "Tommy", one in Japanese). No HUD yet.
- OBS 00:28:19 (#14, w_00014): large "Go!" centre-top; HUD appears with timer **3:00** top-left (stopwatch icon + white digits on black pill), team roster top-centre (4 blue squid icons "vs" 4 orange squid icons on a black bar), points counter top-right "0000p" (four black boxed digits + small "p"), special gauge ring right of it (dark ring with humanoid icon in blue disc), three small round icons below the ring (look like gear-ability icons), and a "C'mon! / d-pad / Booyah!" signal hint bottom-left. Player is already firing: blue ink splashes in front. "You" tag still shown.
  - INF: Ready→Go ≈1 s apart at 1 fps (18→19); timer starts at 3:00 on "Go!".
- OBS 00:28:20 (#15): 2:59, points 0011→… player moving forward off pad, leaving blue trail. Reticle = small white circle with centre dot, roughly screen centre slightly above middle (≈ x640, y~350 on 1280x720; see w_00016 reticle at ~(655,355)).
- OBS 00:28:21–22 (#16–17, w_00016): camera pitched steeply DOWN; player's head (white headband ring, pink tentacles) fills bottom-centre — camera sits close behind/above head; wall on left heavily painted blue, floor blue with spray splashes, white unpainted patches visible. Points 0020, 0026.
  - Special gauge (zoom, w_00016): arc of the ring fills with team blue clockwise from 12 o'clock; tiny blue segment at 0020p.
- OBS 00:28:23–28 (#18–23): player (roller? no — shooter; looks like a squat blaster/shooter with muzzle flash at chest) walking forward along a wall-side ledge painting; points 0031→0039→0051→0062→0066→0072.
  - **Ink tank (w_00018 zoom):** worn on the character's BACK, a vertical transparent cylinder with scale ticks and a red marker; ink fill visible in team colour. There is NO ink meter in the TV HUD — tank level is read from the character model. (Wii U GamePad also shows it; not in this footage.)
  - Camera: third-person, directly behind, character bottom-centre, occupying ~1/5 of screen height when standing (w_00018 character ≈ 150 px tall of 720). Not visibly shoulder-offset — character roughly centred horizontally (slight offset right at times).
- OBS 00:28:28 (#23, w_00023): top roster: blue icons turn to darker/“x”? — the 4 blue icons look dimmer; left team icon set changes appearance (INF: an icon greys out when that player is splatted; check later).
- Paint visuals: own team paint = saturated blue-violet, glossy with specular highlights, irregular blobby edges with droplets; covers walls (vertical) as well as floors. Unpainted = light grey concrete / white ramps → very high contrast.
- Time from spawn to first contact: player leaves pad at ~00:28:19–20; still in own half at 00:28:28 (2:51) painting.

### Sheet 002 (00:28:29–00:28:40)
- OBS 00:28:29 (#24): camera pitched down, head fills bottom of screen again while painting a wall — camera does NOT pull back when looking down; it moves closer/over the head.
- OBS 00:28:30–35 (#25–30): painting walls of a narrow corridor; tall walls get covered with blue ink up to ~2x character height (vertical ink = climbable surface, INF). Points 0089→0105 (slowing: most local turf already inked).
- OBS 00:28:34 (#29): reticle shows four small diagonal tick marks around the circle (visible when firing near a surface, INF: hit/aim bracket).
- **OBS 00:28:36 (#31, w_00031): "Low ink!" warning** — white bold text with a small red/pink tank icon, drawn next to the character's back/tank (screen ≈ x580–710, y≈550), i.e. attached to the character, not in a HUD corner. Timer 2:43, points 0108. Reticle here is a dot with 4 corner brackets forming a square (~180 px wide) — larger than when shooting (INF: aiming indicator/spread or an "ink-empty" idle reticle).
  - The olive/yellow-green drips on the right wall (w_00030–31) appear to be a painted mural/graffiti texture ("HAPPENING"), NOT enemy ink (enemy this round is orange).
- **OBS 00:28:37–39 (#32–34, w_00033): swimming (squid form) in own ink.** Character model is essentially invisible — only a small dark splash/ripple wake at the swim position (w_00033 ≈ x560, y430) and a **floating vertical ink-tank gauge** (small capsule bar ≈ 30x100 px) appears beside the squid (x≈760,y≈400) showing ink level refilling. Camera lowers (closer to floor, lower pitch) — the horizon line is higher, floor fills lower 2/3 of screen. Reticle still visible at centre.
  - Points unchanged while swimming (0109) — swimming does not paint.
  - The swim path runs into a skate halfpipe: ramps are white unpainted with blue ink pushed up the curve.
- OBS 00:28:40 (#35): player back in kid form at the bottom of the halfpipe, firing up the ramp; 0111.
- INF (tank, GDD 05.3): low-ink warning appears ~17 s after "Go!" of near-continuous fire; then player swims ~3 s to refill (37–39) and resumes firing. Empty/low signal = contextual text+icon at the character, plus the on-back tank and the floating gauge while swimming.

### Sheet 003 (00:28:41–00:28:52)
- OBS 00:28:41–44 (#36–39): moving through skate bowls/halfpipes, painting ramp faces; kid form runs up the curved ramp surface normally (#39, w_00039: character on ramp near a wooden quarter-pipe). Swim at #38 (squid not visible, just ripple).
- **OBS 00:28:45 (#40, w_00040): first enemy (ORANGE) ink visible** — orange bands on the far halfpipe and floor, plus an orange tracer/laser streak from the left. Timer 2:34 → **≈25–26 s after "Go!" to reach contested territory** (centre of map).
- **OBS 00:28:47 (#42, w_00042): roster change** — 2nd blue icon top-centre becomes a dark grey squid with "X" eyes = that teammate is splatted. Also a thin straight yellow-white line crossing from the left edge toward the lower centre = enemy long-range (charger-type) aim line/tracer (INF). Orange ink drops splash on blue wall (enemy shots landing, droplets bouncing).
  - Friendly vs enemy paint (w_00042): blue-violet vs saturated orange-yellow; complementary hues, both glossy with same "ink" shader. Boundaries are irregular, blobby, with overlaps (new ink paints over old); walls take both colours too. No outline/edge stroke on paint boundaries — contrast between hues does the work.
- OBS 00:28:48 (#43): swimming through blue on a ramp that is mostly orange; points 0139 stuck while swimming.
- OBS 00:28:49 (#44, w_00044): swimming in own ink up a channel between two wooden ramps, floating tank gauge beside the reticle again (x≈745,y≈320–420) — gauge fill visibly ~3/4 (light blue fill inside dark capsule) → refill feedback while swimming. A small line/stick connects the squid position to the gauge (w_00044 ≈ x650–740,y415). Reticle stays at centre while swimming. Yellow rectangle behind orange icons 1–2 in the roster: likely a world object behind semi-transparent HUD, NOT a HUD state (uncertain).
- OBS 00:28:50–52 (#45–47): back in kid form firing; orange enemy territory on the right/ahead; points 0145→0152. #47 (w_00047) an orange enemy visible top-centre-left in distance near a yellow crate.

### Sheet 004 (00:28:53–00:29:04)
- OBS 00:28:53 (#48, w_00048): an orange cylinder with a green curved nozzle stands on a ledge ahead (INF: enemy-placed sprinkler-type sub/gadget, in enemy colour). A bright white-cyan diagonal streak crosses the reticle area (INF: own shot/tracer glint or a hit spark; can't confirm at 1 fps). Camera again low over the head (head ring bottom-centre).
- OBS 00:28:54 (#49): orange enemy visible on the ledge in front of the yellow crate (small, ~40 px), player advancing up an orange-painted ramp.
- **OBS 00:28:55–00:29:01 (#50–56, w_00050): damage indicator = red/crimson ink-splat vignette** — round red blots scattered around ALL screen edges (dense at corners, sparse toward centre), which grow into large magenta-red splotches by 00:28:57–29:00 (w_00052, w_00055). Colour is red/magenta, NOT the enemy's orange (observed). Vignette persists ~6 s at 1 fps sampling while the player stays in the fight → INF: represents accumulated damage, fades slowly/regens.
  - Same frames: roster now shows 2 blue icons X'd (w_00055: icons 2 and 3 dark with X eyes) — two teammates down.
- OBS 00:28:58 (#53, w_00053): swim, floating tank gauge visible.
- **OBS 00:29:00 (#55, w_00055): "Charged!" text** (white bold) left of the special ring + small "Press R" button prompt at the ring's lower-right. Ring now fully blue. A blue-white cross-shaped flash/sparkle over the player (INF: special-ready sparkle on the character). Timer 2:19. Special charged ≈41 s after Go at ~185p of personal turf.
- OBS 00:29:01–04 (#56–59): "Charged!" remains (00:29:01); from 00:29:02 only the "Press R" prompt stays under the ring (visible through 29:04). Player keeps shooting instead of activating. Damage vignette gone by 00:29:02 (#57). Roster 29:03–04: one blue icon dark + one orange icon dark (w_00058/59 top-right orange icon greyed) → an enemy got splatted.

### Sheet 005 (00:29:05–00:29:16)
- OBS 00:29:05–07 (#60–62): contested bowl; teammate "Tommy" visible in blue kid form with name tag (tags are drawn at an angle, following the surface — w_00061/62 "Tommy" label rotated). "Press R" still visible under the special ring.
- OBS 00:29:07 (#62): straight thin yellow-green line across upper-left (INF: enemy charger aim line again).
- OBS 00:29:08 (#63, w_00063): player standing in ORANGE ink at the foot of a wall that is partly blue (vertical stripe), heavy red damage vignette (strongest yet: large red + magenta blots in all corners, top-edge magenta). Reticle has 4 corner brackets. Enemy on the wall top with an orange burst/explosion effect. "Press R" still shown. INF: player is in enemy ink (slowed) and taking damage — good moment to check slow-in-enemy-ink at high fps.
- **OBS 00:29:09 (#64, w_00064): SPECIAL ACTIVATED — "Bubbler".** Player is enclosed in a translucent blue-violet hex-patterned sphere (~2x character height). A right-side banner appears: dark-blue slanted strip with white italic "Bubbler" text + portrait of the activating player (squid-kid face icon) at ≈ x985–1235, y230–295. Special ring now drains (blue arc shrinking, dark ring with red inner rim). "Press R" gone. Between 00:29:08 and 00:29:09 → activation happened in that 1 s gap.
  - Same frame: a large yellow round burst on a yellow stalk hits the bubble on the left (INF: enemy shot/sub explosion absorbed by bubble). Damage vignette still on.
- OBS 00:29:10 (#65, w_00065): huge flat yellow angular shards sweep across the lower-right of the screen, partly occluding the view (INF: an enemy special or a large projectile in the orange team's colour, rendered yellow; can't identify at 1 fps). Reticle shows a bold X/hit-marker overlay (white cross lines through circle) aimed at an orange enemy (≈ x620,y320) → **INF: hit-confirm reticle**.
  - Roster now: 2 orange icons X'd.
- OBS 00:29:11–13 (#66–68): "Bubbler" banner persists through 00:29:11; bubble around player still at 00:29:12–13; at 00:29:13 (#68) a second bubble appears on a teammate nearby (INF: Bubbler spreads to nearby allies — visible two bubbles). Bubble visible ~5 s (29:09–29:13) at 1 fps.
  - Damage vignette gone at 00:29:11 (#66): cleared ~2 s after bubble activation.
- **OBS 00:29:14–16 (#69–71, w_00069): kill notice "Splatted Ken!"** bottom-centre (≈ x500–780, y650–685): small dark pill with a squid/skull icon at left + white text. Stays ≥3 s. Roster: orange icons 2 and 3 X'd.
- Points 0198 (29:05) → 0267 (29:16).

### Sheet 006 (00:29:17–00:29:28) — PLAYER SPLATTED
- OBS 00:29:17–21 (#72–76): pushing into enemy half on ramps; "Splatted Ken!" notice still up at 00:29:17–18 (so kill notice ≈ 5 s: 29:14–29:18). Enemy ink-armour/bubble? At 00:29:21 (#76) an orange/gold ring-sphere on an enemy near the yellow crate (INF: enemy Bubbler in their colour).
- OBS 00:29:22 (#77): player firing across orange floor; small orange blobs incoming (enemy shots, lozenge-shaped droplets); red vignette starting on the left edge.
- **OBS 00:29:23 (#78, w_00078): heavy damage** — red/orange vignette now covers most of the screen border with a ragged hole in the middle; teammate "Cesar" visible on the ledge above. Player's tank visible at bottom centre (camera pressed against a wall on the left: the grey wall fills the left half — camera does not clip through; it pushes in close to the character when backed against geometry).
- **OBS 00:29:24 (#79, w_00079): SPLAT moment** — own-colour (blue) ink explosion burst where the player was, blurred/radial view, screen tinted by the vignette; roster: player's icon (leftmost blue) becomes dark with X eyes. Timer 1:55.
- OBS 00:29:25 (#80): camera cuts/pans to the killer: an orange-team player ("tito") framed with a gold/orange ring effect (bubble-like shield) — kill-cam.
- **OBS 00:29:26–28 (#81–83, w_00081): death screen content**:
  - Centre-top: black spiky splat-shaped burst containing killer's weapon icon + an orange ink-splat icon + a "squid-X" icon, then two-line white text "Splatted by / .52 Gal!" (killer's WEAPON name, not player name).
  - Killer name tag over the killer in the world ("tito", orange arrow).
  - Left-centre: dark translucent panel (≈ x200–520, y405–625) showing killer's gear: 3 rows (headgear, clothing, shoes), each with gear image + main ability icon + sub-ability icons.
  - Bottom-right: black arrow-shaped banner "Respawn in 4" → "3" (29:27) → "2" (29:28), counting down once per second.
  - HUD (timer, roster, points, special ring) remains visible throughout the death screen; damage vignette remains as a frame.
  - Kill-cam keeps following the killer, who moves on (29:27 shows them rolling/shooting: a roller visible in #82).
- INF (GDD 06.3): splat at ~00:29:24; countdown shown starting at 4 → respawn expected ~00:29:30 (continue next sheet).

### Sheet 007 (00:29:29–00:29:40) — RESPAWN + revenge splat
- OBS 00:29:29 (#84): death screen still up, "Respawn in 1".
- **OBS 00:29:30 (#85, w_00085): respawned on own spawn pad** (timer 1:49). Pad surface pulses with a bright white halftone dot pattern over blue; player appears as a squid shape sunk into the pad (small, at pad centre). Camera placed high behind pad looking out over the map toward the centre; teammate name tags ("Tommy", "Cesar", Japanese name) visible in the distance through walls. No "Ready" text, no invulnerability indicator visible. Damage vignette cleared.
  - **Splat→respawn ≈ 6 s at 1 fps** (splat 00:29:24 → on pad 00:29:30; countdown "Respawn in 4…1" visible 00:29:26–29; kill-cam 00:29:25). Our GDD 4 s respawn is shorter than this (≈ countdown length only).
  - Special ring at respawn shows only a small blue arc at the top (INF: special gauge partly lost on death, or reflects post-Bubbler level; cannot separate at 1 fps).
- OBS 00:29:31 (#86, w_00086): kid form standing up out of the pad (tank visible, pad still glowing). Right-side banner "Killer Wail" + teammate portrait (same slanted blue strip style as "Bubbler") → **team special-activation notice** is shown for teammates' specials too.
- OBS 00:29:32–33 (#87–88): "Killer Wail" banner still (≈2–3 s); player runs/swims off pad; spawn → back in mid-map bowl by 00:29:33–34 (~3–4 s) — Blackbelly spawn is short distance to first bowl.
- **OBS 00:29:35 (#90, w_00090): player splats enemy "tito"** — large blue (own colour) ink explosion sphere with radial streaks where the enemy was, plus a white spiky "splat" starburst with a small squid glyph at its centre (≈ x750,y380). Notice "Splatted tito!" bottom-centre fading in (translucent at 29:35, full at 29:36). Enemy roster icon greys (X). Player standing on a ramp in mixed blue/orange ink shooting horizontally ~6–8 body-lengths.
- OBS 00:29:36–37 (#91–92): the white starburst marker remains floating at the splat spot for ~2+ s (INF: splat-location marker). "Splatted tito!" persists to at least 00:29:40 (≈5 s).
- OBS 00:29:38–40 (#93–95): painting in mid; points 0332→0342.

### Sheet 008 (00:29:41–00:29:52)
- **OBS 00:29:41 → (#96+, crop of w_00096): "Danger!" tag in the roster** — orange italic text on a yellow starburst attached to the right end of the enemy icon row (next to the 4th orange icon, which is X'd/grey at that moment). Persists through 00:29:52+. INF: flags an enemy threat state (in the original, an enemy with a charged special); for us: a roster badge for "enemy ultimate ready" (GDD 08.3/12).
  - A small orange ink-splat decoration sits just right of "vs" before the first orange icon (INF: marks the team whose member splatted most recently? uncertain).
- OBS 00:29:43 (#98): orange enemy shots arriving as a flame-like orange spray streak on the right; own shot tracer white-blue.
- **OBS 00:29:44 (#99): another kill** — white starburst splat marker on the ground bottom-right (≈ x1760/1920 on sheet) and notice "Splatted てるお!" bottom-centre; persists through 00:29:48 (≈5 s).
- OBS 00:29:45 (#100): a starburst "splat marker" floating next to a teammate on the left (INF: teammate got a splat, or marker of a death location).
- OBS 00:29:48 (#103): long orange streak crossing the screen horizontally at mid-height (INF: enemy charger shot/tracer) aimed near an orange enemy on the left.
- OBS 00:29:49–50 (#104–105): teammates "Cesar", "Tommy" with tags; team pushing into orange side.
- **OBS 00:29:51 (#106, crop): second "Low ink!" warning** — dark rounded label with red-X tank icon + white "Low ink!" text at the character's back, while camera is looking down (head ring at bottom). 29:52 (#107) the player is swimming (ripple + floating gauge) → low-ink → swim-to-refill loop again, ~16 s after respawn (29:30→29:51).
- Points 0351 → 0412.

### Sheet 009 (00:29:53–00:30:04)
- OBS 00:29:53–54 (#108–109): swimming with floating gauge (refill), "Danger!" still on roster.
- OBS 00:29:55 (#110): close-quarters: player next to teammate "Cesar" at the yellow crate.
- **OBS 00:29:59 (#114, w_00114): teammate special banner animating in** — the right-side strip is dark with scrambled/partial text and the portrait already in place (≈ x985–1235,y230–295) → banner slides/wipes in over ~1 s; at 00:30:00 it reads "Bubbler" (blue strip). Teammate "Cesar" is inside a bubble (left). Banner visible ~3 s (29:59–30:01).
  - **Reference standard framing (w_00114):** character centred horizontally (x≈640), feet at y≈615, head top y≈425 → character ≈ 190–200 px ≈ 27% of screen height; camera just above head height, slight downward pitch, horizon ≈ y190. No visible shoulder offset (centred). FOV feels wide (~70–80° H, INF) — whole courtyard visible.
  - **Ink tank on back (w_00114): mostly WHITE/empty with only a green base band** → the tank fill level is a live ink indicator on the model (compare blue-filled tank in w_00018).
- **OBS 00:30:03 (#118, w_00118): aiming UP** — camera drops below/behind the head (head ring bottom-centre, sky fills 2/3 of screen), reticle (dot + 4 corner brackets) at ≈ (645,297). Ink stream goes up in an arc — blue droplets fall back (range feel: short arc, lobs visibly).
- OBS 00:30:04 (#119): red damage blots at top-left corner (being hit again); orange enemy on the right side.
- Roster at 00:30:03: 3 of 4 orange icons X'd (w_00118) → team wipe moment for orange; all 4 blue alive.

### Sheet 010 (00:30:05–00:30:16) — SECOND SPLAT + RESPAWN
- OBS 00:30:05 (#120): heavy red vignette; orange enemy close on the right.
- **OBS 00:30:06 (#121, w_00121): player in SQUID form is VISIBLE** lying on/in a patch where orange and blue meet (blue squid body with green-capped tank on its back, ≈200 px long, clearly exposed). INF: when swimming isn't possible/concealment is lost (enemy ink / surfacing), the squid is shown. Enemy (orange-team kid) is inside a GOLD/orange Bubbler sphere (enemy's bubble is rendered in their team colour) and fires orange pellet shots — shots are ~20 px oval droplets arcing toward the player. Vignette covers ~40% of screen edges.
- **OBS 00:30:07 (#122, w_00122): death presentation** — a translucent blue "ghost squid" with X/closed eyes floats upward from the death spot (≈ x680,y290), glowing outline; player's leftmost roster icon X'd. Small debris (green/blue bits) scatter on the floor. Camera still from player's vantage, slightly raised. Splat ≈ 00:30:07 (timer 1:12).
- OBS 00:30:08 (#123): camera moves toward the killer (enemy still in bubble), start of kill-cam.
- **OBS 00:30:09–11 (#124–126): death screen** — "Splatted by / Splattershot Jr.!" (killer "Natalia"), gear panel left, "Respawn in 3" (30:09) → "2" (30:10) → "1" (30:11). Kill-cam follows killer, who leaves the bubble at 30:10.
- **OBS 00:30:12 (#127): respawn on pad** (timer 1:07): pad lit with white halftone; camera looks down onto pad from above/behind. 00:30:13 (#128) squid rising in pad with small ring/bubble particles; 00:30:14–16 (#129–131) kid form stands, runs off.
  - Splat 00:30:07 → pad 00:30:12 ≈ **5 s** (first death measured ≈6 s; with 1 fps error ±1 s → ~5–6 s total, of which the numbered countdown shows 4→1).
- Roster at 30:12: blue player icon restored; "Danger!" tag still on orange side.

### Sheet 011 (00:30:17–00:30:28) — 1 MINUTE WARNING
- OBS 00:30:17–18 (#132–133): leaving spawn pad (camera behind, pad ring visible bottom); timer 1:02, 1:01 in WHITE digits (crop of w_00133).
- **OBS 00:30:19 (#134, w_00134): "1 minute left!"** — large white outlined text with a stopwatch glyph, horizontally across the upper-middle of the screen (y≈270), animated in with a sweeping/halftone dissolve (letters partially masked in this frame). **Timer digits switch to YELLOW at 1:00** and stay yellow afterwards (0:59, 0:57, 0:53… on this sheet). Text still visible at 00:30:20 (#135) (≈2 s).
  - Same frame: player is standing in own ink with **camera looking steeply down**, reticle overlays the character's head (character x≈650,y≈430–600) → camera stays above head when pitched down.
- OBS 00:30:21–22 (#136–137): passing the big yellow inflatable crate — camera pushes very close when the crate is between camera and player? (#137 crate fills right third; the camera did not pull in, crate is just near). Name tags of teammates visible through geometry.
- OBS 00:30:23 (#138): an orange streak of enemy ink crossing a blue ramp (thin line painted by a roller/charger shot).
- OBS 00:30:24 (#139): orange-red explosion burst on the top-left ledge (INF: enemy bomb or splat explosion). Player shooting up a halfpipe wall.
- OBS 00:30:25–28 (#140–143): mid-map fight; red damage blot at top-left at 00:30:26; points 0451→0453. A teammate with a squid-shaped blue swirl (INF: splatted teammate's ink burst) at 00:30:25.

### Sheet 012 (00:30:29–00:30:40)
- **OBS 00:30:29 (#144, w_00144): camera occlusion** — a blue-painted halfpipe edge/pillar sits between camera and player and is drawn OPAQUE in the foreground (occupies left-centre third); player still visible beside it. Bottom-left white geometry covers the "C'mon/Booyah" hint. INF: camera does not fade occluders; it sometimes lets thin geometry pass in front rather than snapping in. Roster at 0:50: 2 blue X'd, 2 orange X'd (big trade).
- OBS 00:30:30–33 (#145–148): player running up/along halfpipe walls painting; character stays upright on the curved ramp (walks on ramps, no special halfpipe move visible at 1 fps).
- OBS 00:30:34–36 (#149–151): long run down an alley toward the yellow crate, standard framing.
- OBS 00:30:37–40 (#152–155): enemy half now largely repainted blue with orange patches; points 0491→0508. Timer yellow (0:42→0:39).
- No deaths of the POV player in this sheet.

### Sheet 013 (00:30:41–00:30:52) — WALL CLIMB, special held
- **OBS 00:30:41 (#156): "Charged!" + "Low ink!" at the same time** — "Charged!" by the special ring (top-right) and "Low ink!" tag at the character's tank. Special ready again (second charge; ~29 s after respawn at 30:12).
- OBS 00:30:42–43 (#157–158): "Press R" persists; player swims to refill (floating gauge at 30:42).
- **OBS 00:30:44 (#159, w_00159): WALL CLIMB in squid form** — player swims UP a vertical wall painted with a blue stripe (the wall is otherwise orange). The squid IS partly visible on the wall: a blue squid head with big white eyes and a small splash at the wall surface (≈ x620–670,y380–470), plus the floating tank gauge at right (≈ x740,y310–400). Camera stays behind at the base looking up the wall, reticle above the squid. Damage vignette on the edges (under fire while climbing). INF: climbing is only possible along own-colour ink on walls; the orange parts beside the stripe are not climbable (GDD 05.2).
- OBS 00:30:45–46 (#160–161): on top of the ledge, heavy red/magenta damage vignette; firing at enemy.
- **OBS 00:30:47 (#162, w_00162):** thin white/grey straight aim line from the left side to an orange enemy at the top of the ramp (INF: enemy charger laser sight) — player fires at enemy on the ramp crest; reticle shows a pinkish hit-flash X at the enemy (≈ x610,y365). "Bubbler" banner (teammate's special, same generic portrait style) at right. "Press R" still visible → POV player is holding special. Character's tentacles appear magenta/red-tinted (INF: on-model damage tint).
- OBS 00:30:48 (#163, w_00163): camera looks UP a steep blue ramp toward the enemy at the crest; head/tank bottom-centre, character's tentacles pink-tinted; white sparkle star at bottom (special-ready sparkle).
- OBS 00:30:49 (#164): player swimming up the ramp (only splash visible, gauge floating).
- OBS 00:30:50–52 (#165–167): near yellow crate, orange enemy engaged; at 00:30:51 a blue-white impact burst with "Tommy" nearby. Points 0547→0552.

### Sheet 014 (00:30:53–00:31:04) — final 30 s, squid exposed in enemy ink
- OBS 00:30:53 (#168): camera very close to a light-grey wall on the left (wall fills 45% of frame) — camera hugs the wall rather than passing through.
- OBS 00:30:54–56 (#169–171): character's tentacles still pink/magenta tinted; "Press R" still shown (special still unused since 30:41).
- **OBS 00:30:57 (#172, w_00172):** swim splash in own ink with a small blue cylinder (green end cap) and a pink glow lying at the splash (≈ x600–750,y450–510). INF: either the squid-form body/tank breaching or a thrown sub-weapon; no throw-arc preview visible in any sampled frame. Needs high-fps check.
- OBS 00:30:58 (#173): camera pitched down over head, looking along the floor; sparkle star at bottom right.
- OBS 00:30:59–31:00 (#174–175): running/painting in mixed ink; "Danger!" returns on roster at 31:00.
- OBS 00:31:02 (#177): small red damage blots appear at the top-left edge.
- **OBS 00:31:03 (#178, w_00178): squid form in ENEMY (orange) ink — fully exposed** big squid with large white eyes and blue hood, orange ink splashing over it (orange droplet splashes on the body), floating tank gauge beside it (≈ x735,y360–465, ~1/5 full). Enemy orange pellets flying past. INF: this is what "stuck in enemy ink" looks like — visible, slowed, can't hide (GDD 05.1). Timer 0:16.
- OBS 00:31:04 (#179): back in own ink swimming beside yellow crate. Points 0598.

### Sheet 015 (00:31:05–00:31:16) — FINAL COUNTDOWN
- OBS 00:31:05–08 (#180–183): fighting around the big yellow crate at 0:14–0:11; "Press R" still up. Points 0598→0604.
- **OBS 00:31:09 (#184, w_00184): final 10-second countdown** — a huge hollow/outlined digit "10" (white outline, translucent interior, ≈ 500 px tall) drawn over the centre of the screen, over the gameplay; the timer pill also reads 0:10 (yellow). Digits then 9 (31:10), 8 (31:11), 7 (31:12), 6 (31:13), 5 (31:14), 4 (31:15), 3 (31:16) — one per second, positions vary slightly (centre to centre-right), all outline-only so gameplay remains readable.
  - Same frame: "Low ink!" tag at character + floating swim gauge (squid in own ink next to crate).
- OBS 00:31:13–14 (#188–189): teammate "Killer Wail" banner at right during countdown (≈2 s).
- OBS 00:31:15 (#190): red damage vignette returns strongly.
- **OBS 00:31:16 (#191, w_00191): POV player activates Bubbler at 0:03** — player inside bubble, "Bubbler" banner (right), special ring drained with red inner rim, "Press R" gone; "Low ink!" also shown. Activation between 00:31:15 and 00:31:16. (Special was held from 30:41 to 31:16 ≈ 35 s.)
- Roster at 0:03: 2 orange icons X'd; all blue alive.

### Sheet 016 (00:31:17–00:31:28) — END OF ROUND + JUDGING
- OBS 00:31:17 (#192): countdown "2" over screen, POV player still in Bubbler, heavy damage vignette, "Bubbler" banner.
- OBS 00:31:18 (#193): countdown "1"; blue ink explosion + white starburst splat marker just above the player → **"Splatted Natalia!"** notice (kill at 0:01 while bubbled).
- **OBS 00:31:19 (#194, w_00194): "GAME!"** — the whole HUD (timer, roster, points, special ring, signal hint) disappears instantly; screen is covered by 5 crossing bright yellow-green "caution tape" bands with repeated black "GAME!" lettering (one band horizontal near the bottom, others diagonal). Gameplay frozen/slowed behind (player still in bubble). Kill notice "Splatted Natalia!" remains under the tape.
  - Timer went 0:01 at 31:18 → GAME at 31:19: no "0:00" frame sampled.
- OBS 00:31:20–22 (#195–197): tape holds on screen (≈4 s total, 31:19–31:22); background scene static.
- OBS 00:31:23 (#198): background cuts to black while tape remains → transition.
- **OBS 00:31:24 (#199, w_00199): top-down orthographic view of the whole map** showing final ink coverage: blue vs orange (orange renders as yellow-orange from above), unpainted areas grey/white; spawn pads visible at far left (blue) and far right (orange/yellow). Every painted surface readable as a flat map — **direct reference for GDD 10.7 minimap** (team-colour fill on a top-down plan, no fog).
- **OBS 00:31:25–28 (#200–203, w_00203): judge reveal** — a large mascot judge character (a cat; do NOT copy — we need our own original judge) stands centre over the top-down map. Bottom: a black rounded bar with team names above it — left "Good Guys" (blue outlined text), right "Bad Guys" (orange). Bar fills from BOTH ends toward the middle:
  - 00:31:25: 0.0% / 0.0% (0p / 0p)
  - 00:31:26: 7.8% / 7.8% (119p / 119p) — both sides count up at the SAME rate (suspense)
  - 00:31:27: 25.4% / 25.4% (388p / 388p)
  - 00:31:28: **50.3% (769p) vs 26.0% (398p)** — orange side stopped; blue continued. A white spark/flash sits at the meeting point of the two fills (x≈830). Judge raises a flag with a squid emblem toward the blue side (winner indicated by flag direction).
  - Numbers shown: team % of map inked (large, white) + team turf points (small, dark, "p" suffix) per side.
  - INF: 50.3 + 26.0 = 76.3% of the map inked; the rest unpainted. Points ≈ 15.3 p per 1% (769/50.3 ≈ 398/26.0 ≈ 15.3) → points are the same quantity as area.

### Sheet 017 (00:31:29–00:31:40) — RESULT + SCOREBOARD
- **OBS 00:31:29 (#204): final numbers 59.4% (908p) Good Guys vs 27.6% (423p) Bad Guys**; big blue ink-splat banner top-left "VICTORY!" appears; judge holds squid flag toward the blue side. (So the bar continued past 50.3% between 31:28 and 31:29: the loser's side stops first, then the winner's side finishes. Total inked 87.0%.)
  - INF from 31:28 → 31:29: the orange side's number also crept 26.0→27.6 → both sides stop near their finals at slightly different times; the reveal is ~4 s from 0.0% (31:25) to final (31:29).
- OBS 00:31:30–31 (#205–206): sparkle/star particles over the blue bar; judge celebrates.
- **OBS 00:31:32 (#207): "Win bonus! +300p"** label on a dark slanted strip next to VICTORY!; the map fades/blurs and the four WINNING team characters appear posing in a row with name plates above them (Tommy, ZackScott, Cesar, りゅう); bar remains at bottom. Poses animate 31:32–31:35.
- **OBS 00:31:36 (#211): personal points card** — top-left big "950p" in white over the blue splat; POV character alone in a pose on the left; scoreboard slides in from the right (partially visible at 31:36).
- **OBS 00:31:37–40 (#212–215, w_00212): scoreboard** (right half of screen):
  - Header "VICTORY!" on a blue ink splat, then 4 blue rows; header "DEFEAT" on an orange splat, then 4 orange rows.
  - Each row (slanted/arrow-shaped strip, team colour): "Level N" badge, player portrait, weapon icon, player name, points (e.g. "1011p"), and two small stats stacked: splat-icon ×N (kills) and "splatted"-icon ×N (deaths).
  - Rows sorted by points within each team. The POV player's row (ZackScott, Level 3, 950p, ×4 / ×2) is shifted LEFT, sticking out of the column, to highlight "you".
  - Values: Victory — Cesar 1011p (4/2), Tommy 1003p (10/5), ZackScott 950p (4/2), りゅう 807p (3/5); Defeat — Natalia 826p (3/5), tito 633p (6/4), Ken 553p (3/5), てるお 292p (2/7).
  - Cross-check with this review: POV kills seen = Ken 29:14, tito 29:35, てるお 29:44, Natalia 31:18 = **4** ✓; POV deaths seen = 29:24, 30:07 = **2** ✓. 950p = ~650p turf + 300 win bonus (HUD counter showed 0640+ at 31:18).

### Sheet 018 (00:31:41–00:31:44) — REWARDS
- OBS 00:31:41 (#216): scoreboard still shown.
- OBS 00:31:42–44 (#217–219): points bank into rewards: the big "950p" counts DOWN (920p → 20p → 0p) while right panel shows "Cash" counter (coin icon, 0003185 → 0003965 → 0004135) and "Level" panel (green splat badge "3", bar 785/2600 → 1565/2600 → 1735/2600), plus a "Gear" panel with 3 gear cards (headgear/clothing/shoes) with ability slots. INF: points convert 1:1 into XP (785+950=1735 ✓) and to cash (3185+950=4135 ✓).
- Sampled window ends 00:31:44 (results still on screen).

---

# Synthesis (answers to GDD 16.2)

Frame path prefix below: `C:\Color-Clash\reference\video_review\windows\round_blackbelly_2805\`. Pixel positions are for 1280x720 frames. Source seconds = HH*3600+MM*60+SS (00:28:05 = 1685 s). All timings are ±1 s (1 fps sampling).

## a) Round structure — GDD 03
| Phase | Source time | Evidence | Notes |
|---|---|---|---|
| Load | 00:28:05–06 | w_00000, w_00001 | black + small ink-blob loader |
| Map card / flyover | 00:28:07–11 (~5 s) | w_00002…w_00006 | mode name, one-line objective, map name; fade to white |
| Team reveal on pads | 00:28:12–17 (~6 s) | w_00007…w_00012 | own team first (blue), then enemy (orange); squid→kid pop, name tags |
| "Ready…" | 00:28:18 | w_00013 | camera behind own player on pad, "You" tag, no HUD |
| "Go!" + HUD on, timer 3:00 | 00:28:19 | w_00014 | player already firing on this frame |
| Contested territory reached | ≈00:28:45 (2:34) | w_00040, w_00042 | first enemy ink seen ≈25–26 s after Go; first teammate splat by 00:28:47 |
| Respawn → mid bowl | 00:29:30 → ~00:29:34 | w_00085…w_00089 | only ~3–4 s from pad back to first bowl |
| "1 minute left!" | 00:30:19–20 (1:00) | w_00134 | timer digits turn yellow from 1:00 on |
| Final countdown 10→1 | 00:31:09–00:31:18 | w_00184…w_00193 | huge outline digits centre screen, 1 per s |
| "GAME!" | 00:31:19–22 (~4 s) | w_00194…w_00197 | HUD vanishes; caution-tape bands; action frozen; black at 00:31:23 |
| Top-down map | 00:31:24 | w_00199 | whole-map coverage, orthographic |
| Judge reveal | 00:31:25–29 (~4 s) | w_00200…w_00204 | bar fills from both ends at equal speed, then loser stops; final 59.4% (908p) vs 27.6% (423p) |
| VICTORY + Win bonus | 00:31:29 / 00:31:32 | w_00204, w_00207 | "Win bonus! +300p"; winning team poses |
| Personal points + scoreboard | 00:31:36–41 | w_00211…w_00216 | 8 rows: level/portrait/weapon/name/points/kills/deaths; own row offset |
| Rewards | 00:31:42–44 | w_00217…w_00219 | points tick into Cash and Level XP; gear panel |

- Numbers shown at results: per team **% of map inked** and **team turf points**; per player **points, splats (xN), times splatted (xN), level**; personal **total p incl. win bonus**, then **Cash** and **Level XP** gains.
- Round length check: Go 00:28:19 → GAME 00:31:19 = 180 s.

## b) Friendly vs enemy paint — GDD 07 / 12
- OBS: two complementary hues (blue-violet vs orange); both glossy with specular highlights and slight surface ripples; no outlines on paint edges — organic blob edges with droplets (w_00042, w_00114). Unpainted ground is light grey/white → paint pops strongly.
- OBS: walls take paint exactly like floors (w_00030, w_00159). From the top-down view orange reads as yellow-orange (w_00199).
- OBS: enemy projectiles and specials are in enemy colour (orange pellets w_00121/w_00178; enemy Bubbler rendered gold w_00121/w_00122). Own splat explosions are own colour (w_00079, w_00090).
- INF splat size (w_00025, w_00016): one sustained burst paints a wall patch ≈1.5–2 character heights wide; floor trail while walking+firing ≈1–1.5 character widths.
- OBS: damage vignette is red/magenta, NOT the enemy's ink colour.

## c) Paint tank — GDD 05.3
- OBS: no ink bar in the TV HUD. Ink is shown (1) on the tank on the character's back — transparent cylinder with ticks, fill in team colour, white when empty (w_00018 near full; w_00025 ~1/3; w_00114 near empty); (2) a **floating mini tank gauge** beside the squid while swimming, showing refill (w_00033, w_00044, w_00178, w_00184); (3) a **"Low ink!" tag** (red tank icon + white text on dark pill) at the character's back (w_00031, w_00106, w_00184, w_00191).
- OBS: Low-ink at 00:28:36, 00:29:51, 00:30:41, 00:31:09–16. Typical cycle: ~15–17 s of mostly continuous fire → Low ink → 2–4 s swim → fire again.
- OBS: "Low ink!" and "Charged!" can show at the same time (00:30:41).

## d) Camera — GDD 04.2
- OBS standard framing (w_00114, w_00097): character horizontally centred (no clear shoulder offset), feet at y≈615, ~27% of screen height; camera slightly above head, gentle downward pitch; horizon y≈190. Reticle ≈(650,350), just above screen centre, above the character's head.
- OBS looking down (w_00016, w_00024, w_00134): camera rises over the head — head/headband fills bottom-centre; reticle can overlap the character.
- OBS looking up (w_00118, w_00163): camera drops behind/below the head; sky fills 2/3 of screen.
- OBS swimming (w_00033, w_00044): camera lower/closer to the surface; squid mostly invisible → unobstructed view.
- OBS near walls (w_00078, w_00168): camera slides along the wall (wall fills 45–50% of frame); thin geometry can pass between camera and player opaquely (w_00144) — no occluder fading seen.
- INF FOV: wide (~70–80° horizontal feel). Ally name tags visible through walls give orientation.

## e) Movement — GDD 05.1 / 05.2
- OBS swim in own ink: character hidden, only a ripple/splash wake + floating gauge (w_00033, w_00044, w_00109). Swimming adds no points (counter frozen, e.g. 0109 at 00:28:37–39).
- OBS wall climb: swims up a vertical own-colour stripe; squid head/eyes partly visible on the wall (w_00159, 00:30:44).
- OBS in enemy ink: squid fully visible (big eyes, orange ink splashing on it) (w_00121 00:30:06, w_00178 00:31:03). INF: slowed + exposed; speed not measurable at 1 fps.
- OBS ramps/halfpipes: kid walks up curved ramp faces normally (w_00039, w_00145–w_00147); squid swims up ramps (w_00164). No trick/grind state visible.
- Jumping: not clearly identifiable at 1 fps (possible airborne frames 00:29:05, 00:31:17).

## f) Weapon — GDD 07
- OBS: POV player (ZackScott) uses a chunky shooter-type gun (big barrel, hip-held; results pose w_00212); same weapon icon as Cesar on the scoreboard. Fire = continuous stream of blobs with a warm muzzle flash at chest height (w_00018, w_00097); stream arcs and falls off (visible aiming up, w_00118).
- INF range: ~6–8 character lengths on the flat (hits at w_00162, w_00090); continuous paint trail on the floor while firing.
- Other weapons seen: enemy charger aim line (thin straight yellow/white line visible to the target, w_00042, w_00062, w_00162); enemy roller (w_00097, w_00082); kill cards name ".52 Gal" and "Splattershot Jr." (w_00081, w_00124).

## g) Combat readability — GDD 05.4, 06.3, 06.4, 08.4
- Hit feedback: reticle shows 4 corner ticks while firing and a white X/cross flash on hit (w_00065, w_00162). Enemy splat = big own-colour burst + white starburst marker with squid glyph lingering ~2 s (w_00090, w_00193).
- Damage taken: red/magenta ink-blot vignette on all edges, growing with damage (w_00050 → w_00063 → w_00078); clears a few seconds after escaping (gone by 00:29:02 and 00:29:11). Tentacles look pink-tinted while hurt (w_00162–w_00163, INF).
- Kill notice: "Splatted <name>!" bottom-centre pill, ~4–5 s (w_00069, w_00090, w_00194). Only the POV player's own kills appear.
- Roster: splatted player's icon turns dark with X eyes (w_00042, w_00079); "Danger!" badge on enemy side (w_00096).
- Own death: own-colour burst (w_00079) or ghost squid rising (w_00122) → ~1 s kill-cam pan to killer → death card "Splatted by <weapon>!" + killer gear panel + "Respawn in N" bottom-right (w_00081, w_00124).
- **Respawn timing: splat 00:29:24 → pad 00:29:30 (≈6 s); splat 00:30:07 → pad 00:30:12 (≈5 s). The numbered countdown shows 4→1 (or 3→1) inside that.** Ours (4 s) is ~1–2 s faster; keep a ~1 s kill-cam beat inside it.
- Respawn presentation: camera behind the pad, pad lights with a white halftone pulse, squid sinks into the pad, kid stands ~1 s later (w_00085, w_00086, w_00127–w_00131). No spawn-protection indicator visible.
- Super jump: **not observed** in sampled frames.

## h) Sub / special — GDD 08.1, 08.3
- Special gauge: ring right of the points counter, fills clockwise in team colour (w_00016). Full → "Charged!" + "Press R" + sparkle on the character (w_00055). Charged at 00:29:00 (≈41 s after Go) and 00:30:41.
- Activation (Bubbler) at 00:29:08→09 and 00:31:15→16: translucent team-colour hex sphere (~2x character height), right-side banner with special name + portrait (w_00064, w_00191), ring drains with a red inner rim. Teammates' specials show the same banner ("Killer Wail" w_00086, "Bubbler" w_00114). Bubble spreads to a nearby teammate (00:29:13, w_00068). Special banked ~35 s (00:30:41→00:31:16).
- Subs: enemy sprinkler-like device in orange (w_00048). No throw-arc preview in any sampled frame; possible own sub at w_00172 (unconfirmed).

## i) HUD layout (1280x720) — GDD 12, 10.7
| Element | Position | Evidence |
|---|---|---|
| Timer (stopwatch + m:ss, black pill; yellow at ≤1:00) | top-left x≈50–215, y≈28–72 | w_00014, w_00134 |
| Team roster (4 icons "vs" 4 on black bar; X when splatted; "Danger!" badge) | top-centre x≈385–895, y≈20–72 | w_00042, w_00096 |
| Personal turf points (4 boxed digits + "p") | top-right x≈935–1120, y≈30–78 | w_00016 |
| Special gauge ring (centre icon) | top-right corner, centre ≈(1172,85), r≈60 | w_00016 |
| "Charged!" / "Press R" | left of / under ring, y≈100–145 | w_00055 |
| 3 gear-ability icons | under ring x≈1100–1235, y≈160–200 | w_00016 |
| Special-activation banner (name + portrait) | right edge x≈985–1235, y≈230–295 | w_00064 |
| Reticle (circle+dot; 4 ticks when firing) | ≈(650,350) | w_00016, w_00031 |
| Low-ink tag | at character's back ≈(570–710, 535–565) | w_00031 |
| Floating swim tank gauge | ~100 px right of squid | w_00044 |
| Kill notice | bottom-centre x≈500–780, y≈650–685 | w_00069 |
| Signal hint (C'mon!/Booyah!) | bottom-left x≈55–135, y≈600–690 | every gameplay frame |
| Big announcements (Ready/Go/1 minute left/countdown) | upper-centre / centre | w_00013, w_00014, w_00134, w_00184 |
| Death card / gear panel / respawn countdown | centre-top / left-centre / bottom-right | w_00081 |
| Damage vignette | all four edges | w_00078 |

- **No minimap on the TV HUD** (OBS). The only map view is the end-of-round top-down (w_00199) — good style template for our 10.7 minimap.
- No ink bar, no HP bar, no kill feed of other players' kills (OBS).

## Moments for high-frame-rate inspection
(source seconds; 00:28:05 = 1685 s)
1. **1697–1702 s (00:28:17–00:28:22)** — "Ready…" → "Go!" → HUD pop-in, first shots, leaving the pad.
2. **1715–1720 s (00:28:35–00:28:40)** — "Low ink!" appears → kid→squid → floating gauge refill → squid→kid + resume firing.
3. **1746–1752 s (00:29:06–00:29:12)** — standing in enemy ink under fire (slow + vignette growth) → Bubbler activation (button frame between 1748 and 1749) → banner slide-in.
4. **1752–1756 s (00:29:12–00:29:16)** — splat of "Ken": hit-marker, burst, starburst marker, kill-notice pop-in.
5. **1762–1772 s (00:29:22–00:29:32)** — POV splatted: damage build-up → burst → kill-cam pan → death card → "Respawn in 4…1" → pad respawn (squid→kid). Measure exact respawn delay.
6. **1805–1813 s (00:30:05–00:30:13)** — second death: exposed squid in enemy ink, enemy bubble, ghost squid rising, respawn at ~1812.
7. **1818–1821 s (00:30:18–00:30:21)** — "1 minute left!" animation and timer colour switch.
8. **1842–1846 s (00:30:42–00:30:46)** — wall climb up an ink stripe (camera tilt, squid visibility, exit at top).
9. **1856–1865 s (00:30:56–00:31:05)** — possible sub-weapon object (~1857) and squid fully exposed in enemy ink (~1863): what is the green-capped cylinder, how slow is enemy-ink movement.
10. **1874–1893 s (00:31:14–00:31:33)** — final countdown 5→1, Bubbler at 0:03, last-second splat, "GAME!" tape (1874–1884), then top-down map, judge bar fill, VICTORY, win bonus (1884–1893).

## GDD mapping summary
- **03 round flow/scoring/results:** intro ~13 s (card + team reveal + Ready), 180 s match, 1-min warning, 10-s outline countdown, GAME ~4 s, top-down map, ~4 s suspense bar (equal-speed fill then split), team % + points, win bonus +300, per-player points/kills/deaths scoreboard, XP/cash payout.
- **04.2 camera:** centred third-person, character ~27% of screen height, pitch-dependent height (over head looking down, low looking up), low while swimming, no occluder fade.
- **05.1–05.3:** hidden swim in own ink, exposed in enemy ink, wall climb on own ink only; no HUD ink bar — tank on back + floating gauge while swimming + contextual "Low ink!".
- **05.4:** no HP bar; damage = edge vignette (+ character tint); clears within a few seconds out of combat.
- **06.3:** ≈5–6 s splat→respawn incl. ~1 s kill-cam; numbered countdown; killer's weapon + gear shown. Ours is 4 s.
- **06.4:** no visible spawn-protection effect at 1 fps.
- **07:** stream-type shooter, range ~6–8 body lengths, continuous floor trail; charger aim lines visible to targets.
- **08.1:** enemy-placed device seen (sprinkler-like); no throw preview captured.
- **08.3:** ring gauge → "Charged!"/button prompt → team-wide activation banner; can be banked.
- **08.4:** no super jump observed this round.
- **10.7:** no in-match minimap; end-of-round top-down map is the style reference.
- **12:** layout table above.
- IP note: judge mascot, caution-tape "GAME!" motif, squid icons and names are Nintendo's — use only as behaviour/structure reference, design our own equivalents.
