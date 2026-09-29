# Round review: Urchin Underpass (Turf War) — 1 fps sampled

Source: `Colorclashvideoreference.mp4`, 00:09:15 (555 s) → 00:12:54 (774 s).
Frames: `C:\Color-Clash\reference\video_review\windows\round_urchin_0915\w_<idx>_<HH-MM-SS.mmm>.jpg` (1280x720, 1 fps, 220 frames).
Frame index N == source second 555+N.
Sheets: `...\round_urchin_0915\sheets\sheet_NNN_*.jpg` (12 frames each).

Method: every sheet opened in order, key full frames opened individually. Sampling is 1 fps, so anything shorter than ~1 s may be missed entirely.
Reference only — original Splatoon (2015) feel/behaviour; nothing here is to be copied as an asset.
OBSERVED = visible in a frame. INFERENCE = my reasoning. No audio was processed.

---

## Running notes per sheet

### Sheet 000 (09:15–09:26, frames #0–#11)

OBSERVED
- #0 09:15 (`w_00000_00-09-15.000.jpg`): lobby/matchmaking screen, green-yellow paint-splat background. Left: player Level 1, 0/700 XP, coins, rank/"Chill" gear panel; "Mode: Turf War"; "Stages: Urchin Underpass, Blackbelly Skatepark" (two-stage rotation). Right: "BATTLE TIME!" header with an 8-player list (level + name bars).
- #1 09:16: transition — lobby panel drawn inside a squid-silhouette mask that shrinks (iris-wipe in the shape of the mascot).
- #2–#4 09:17–09:19: black screen, a small purple ink blob appears lower right (#3, #4 small drip/blob animation) = loading indicator.
- #5–#8 09:20–09:23: stage fly-over / establishing shot of the map from a high angle, slow camera pan. Overlaid white text with dark outline: "Turf War" (mode), "Ink the most turf to win!" (rule sentence, large, centred), "Urchin Underpass" (stage name, lower right). Colour palette of stage is neutral grey/white concrete with purple and orange accent props — no ink on the map yet.
- #9 09:24: white flash / fade-to-white transition.
- #10 09:25 (`w_00010`): spawn pad close-up: circular metal pad with glowing yellow-orange dotted surface (team colour), 4 small squid-shaped ink blobs sitting on it (players in squid form), metal ring with lights. Camera is behind/above looking at pad.
- #11 09:26 (`w_00011_00-09-26.000.jpg`): the four teammates pop up from squid to humanoid form on the pad, orange ink splashing; name tags above each head in white text with a small downward triangle ("みかど", "Sabby", "Ackey", "ZackScott"). Our player (foreground) is carrying a stubby blaster-style weapon with a flame decal (INFERENCE: this is the recording player; a Blaster-type / slow heavy shot). Team colour = orange.

INFERENCE
- Intro structure: lobby → mascot iris-wipe → ~3–4 s black loading → ~4 s stage fly-over with mode/rule/stage cards → white flash → team spawn pad pop-in.
- Friendly players get nametags in intro; team colour is established on the pad glow before any gameplay.

GDD mapping: 03 round flow (intro card with rule sentence), 06.4 spawn (spawn pad has team-colour glow), 12 UI (text overlay style).

### Sheet 001 (09:27–09:38, frames #12–#23)

OBSERVED
- #12 09:27: own team (orange) still on spawn pad posing, nametags visible.
- #13–#14 09:28–09:29 (`w_00013`, `w_00014`): cut to ENEMY team intro on their pad: teal/cyan ink, same pad model with cyan dotted glow, backdrop banners turn dark green. Enemy names shown (Japanese + "Afro"). Enemy team has a roller-type (large flat roller) and a charger/long gun visible.
- #15 09:30 (`w_00015`): back to own pad, over-shoulder view behind the team. Large "Ready?" text animating in (orange letters + a squid-mascot glyph), "You" label above own player in white, teammate names small above others.
- #16 09:31: "Ready..." text finishing; still on pad.
- #17 09:32 (`w_00017_00-09-32.000.jpg`): **"GO!"** large white/grey 3D-block letters, upper centre. HUD appears simultaneously: timer "3:00" top-left, 4 orange squid icons "vs" 4 teal squid icons top-centre, points counter "0003" top-right, special gauge ring + 3 small icons below it (right). "C'mon! / d-pad / Booyah!" callout hint bottom-left. Players are already off the pad and have painted a sizeable orange swath in front of the pad in the same second (INFERENCE: control is granted at/just before "GO!" appears; players start moving immediately).
- #18–#23 09:33–09:38: player runs forward shooting; timer 2:59 → 2:54 ticks 1/s. Points counter rises 0003 → 001x → 0023 → 003x → 004x → 005x → 0066 (odometer-style rolling digits; last digit often blurred mid-roll).
- Special gauge ring (top-right, around orange circle with a white humanoid icon) fills clockwise from 12 o'clock in orange: small at 2:58, about a quarter at 2:56 (`w_00021`).
- #21 09:36 (`w_00021_00-09-36.000.jpg`): walls painted by own shots — orange ink on vertical concrete wall with ragged irregular splat edges; a faint purple/lavender stain also on a wall at left (INFERENCE: pre-existing decorative stain, not team ink — it is not teal). Reticle = small white circle with pink/red centre ring plus 4 short tick marks at a wider radius (spread indicator) — centred slightly above screen centre (~x640,y370).
- #23 09:38: player walks over a grated floor section: paint only lands on the solid tiles, grate gaps stay unpainted — paint conforms to geometry.
- Player's weapon (seen from behind): small stubby gun; shots produce thick blob splats on floor ~1–1.5 character widths.

INFERENCE
- Ready?→Go! is roughly 2 s (Ready at 09:30, Go at 09:32). Timer displays 3:00 on the GO frame and begins counting on the next second.
- The points counter top-right is the player's personal inked-turf points (it only counts up, starting at 0 at GO).
- There is no on-screen ink-tank bar on the TV HUD in these frames; ink level must be read elsewhere (see later sheets).

GDD mapping: 03 (Ready?/GO! countdown, 3:00 timer, personal points counter), 12 (HUD layout), 07 (reticle with spread ticks), 08.3 (special gauge ring fills from painting).

### Sheet 002 (09:39–09:50, frames #24–#35)

OBSERVED
- Timer 2:53 → 2:42; points 0070 → 014x (roughly +6–8 points per second while painting uncontested ground).
- Player pushes forward from spawn through a tree planter, ramps and a narrow corridor with grated metal floor, painting a continuous orange lane behind.
- #25 09:40 (`w_00025_00-09-40.000.jpg`): paint surface is glossy — sunlight hits it with bright yellow specular sheen, so the same orange looks yellow in lit areas and deep orange in shadow. Paint edges are irregular blobby shapes with small satellite droplets and some "star" splash decals where shots land. Unpainted floor = dark grey asphalt/black, giving strong contrast. Own character is rendered semi-transparent/ghosted while foliage is between camera and player (camera-occlusion fade).
- Camera (all frames): third-person, fairly high and behind, looking down roughly 25–35°; character occupies about 1/10 of screen height, positioned bottom-centre, slightly left of the reticle column. Reticle sits a few character-heights ahead on the floor.
- #29 09:44, #31 09:46: player fires at a wall/floor while walking; shot impacts create a bright orange burst ~1 character wide.
- #33–#35 09:48–09:50: teammate "Sabby" nearby; player reaches mid-map buildings (vending machines, glass). No teal ink seen yet in own lane.
- No enemy seen, no damage.

INFERENCE
- ~15–20 s after GO the player is still in own half; contested mid not yet reached (see next sheets).
- Paint readability relies on a high-saturation team colour against a desaturated grey/white level palette.

GDD mapping: 04.2 camera (high 3rd person, occlusion fade), 07 (paint splat size/trail), 03 (points rate), 12.

### Sheet 003 (09:51–10:02, frames #36–#47) — LOW INK, SWIM REFILL, SPECIAL CHARGED

OBSERVED
- #36 09:51 (`w_00036_00-09-51.000.jpg`, timer 2:41): **"Low ink!"** notice appears just below the player (screen ~x640,y550): dark translucent rounded box with a yellow/black hazard-stripe border, a small empty-battery-style tank icon at left and white text "Low ink!". Points counter frozen at 0148 from 2:41 to 2:36 (player stops painting).
- #37 09:52: player transitions into squid form (character mostly gone, splash at feet).
- #38 09:53 (`w_00038_00-09-53.000.jpg`): **squid form** — a small orange squid with a big white eye, low to the floor, splashing through own ink (wake of lighter orange ripple/droplets). A **vertical ink-tank gauge pops up beside the reticle** (right of it, ~x750,y360): dark rounded rectangle with a thin leader line/tick connecting to the reticle area; fill is a small yellow segment at the bottom.
- #39 09:54 (`w_00039`): tank gauge fill ~50% (pale yellow fill); squid visible as orange blob with lighter spray wake behind it.
- #41 09:56 (`w_00041_00-09-56.000.jpg`): camera lower and closer to floor while swimming (horizon higher in frame, floor fills more of view). Tank gauge now nearly full (filled orange to near the top). Squid body not distinguishable — only ripples/sparkles on the ink surface where it swims (INFERENCE: squid is effectively hidden in own ink).
- #42–#45 09:57–10:00: back to humanoid, shooting again; points resume 0149 → 0162. First **teal enemy ink** patches appear on the floor (#43 `w_00043`, #44, #45) — flat cyan/turquoise, clearly separate hue from orange; small patches ~1 character wide.
- #46 10:01 (`w_00046_00-10-01.000.jpg`, timer 2:31): **special gauge full** — ring complete, "Charged!" text slides in beside it (white, italic, with ghosted motion-trail copy), "Press R" button prompt appears under the ring's right side, and a **golden circular shock-ring / glow** bursts around the player's body.
- #47 10:02: "Charged!" still shown; player shooting; purple graffiti wall art ("…APPENING") visible — part of level art, not ink.

INFERENCE
- Tank empty → refilled from ~10% to ~full in about 3 s of swimming (09:53→09:56). Only 1 fps so refill-rate is approximate.
- The ink gauge is contextual: shown next to the reticle while swimming/refilling (and presumably low), hidden otherwise — no permanent tank bar on HUD. The character's back-tank is also a diegetic indicator (not legible at this resolution).
- Special took ~29 s of play (GO at 2:60 → full at 2:31) for ~175 points of painting.

GDD mapping: 05.3 tank (contextual gauge near reticle, "Low ink!" toast, swim refill), 05.1 swim form, 04.2 camera lowers when swimming, 08.3 ultimate charged presentation (ring full + text + button prompt + player aura), 12 HUD.

### Sheet 004 (10:03–10:14, frames #48–#59) — FIRST CONTACT, DAMAGE VIGNETTE, SPLATTED

OBSERVED
- #48–#50 10:03–10:05: player enters contested mid; lots of teal ink on floors, ramps and railings. "Charged!" + "Press R" persist (special held, not used).
- #51–#55 10:06–10:10: fighting in mixed orange/teal area. Teal ink blotches begin to **creep in from the screen edges** (top-left/top-right/bottom corners), dark-teal paint splats layered over the view (`w_00053_00-10-08.000.jpg`). Teammate "Ackey" close by.
- #56 10:11 (`w_00056_00-10-11.000.jpg`, 2:21): heavy **teal screen-edge splatter vignette**: nearly the whole frame border is covered in enemy-colour ink, with an irregular "hole" in the centre; enemy (teal, holding a gun) visible ahead on a ledge at ~10–12 m. Player's own body shows orange flash/particles.
- #57 10:12 (`w_00057`, 2:20): top-centre roster: leftmost ORANGE squid icon has turned **dark grey with an X** (teammate splatted). In world, a pale orange **sad-faced squid ghost icon** floats up where the teammate died (~x560,y190). Player now standing in teal ink with teal splashes on body; vignette still heavy.
- #58 10:13 (`w_00058_00-10-13.000.jpg`, 2:19): **player splatted** — own body is gone; the weapon lies dropped on the teal floor, a thin ring/ripple where the player was. Roster now shows 2 orange squids X'd (positions 1 and 4). Enemy nametag "べかちぅ(かり)" visible in the middle distance.
- #59 10:14 (`w_00059_00-10-14.000.jpg`, 2:18): **splat/kill-cam screen**: camera swings to look at the killer (teal inkling with a chunky gun, nametag above). Centre-top: black spiky speech-burst with killer's weapon icon + skull glyph and text "Splatted by .52 Gal!" (weapon name). Left: a dark panel with the killer's **gear** (hat, shirt, shoes) each with a main-ability icon and "?" unknown sub-ability slots. Bottom-right: black arrow-shaped banner "Respawn in 3". Teal vignette remains around frame edges. HUD (timer, roster, points, special ring) remains visible during death.

INFERENCE
- Damage feedback = enemy-colour ink covering the screen edges, thicker as damage accumulates; visible for ~6 s of this exchange (10:06→10:12) — suggests this player was being chipped and also standing in enemy ink (which in the game slows/damages; not directly measurable here).
- Roster squid icons double as a live alive/dead indicator for all 8 players.
- The "Respawn in N" counter starts at 3 about 1 s after the death frame; see sheet 005 for respawn time.
- Special was charged but NOT used before death.

GDD mapping: 05.4 health (screen-edge enemy-colour vignette as damage indicator), 06.3 elimination (kill-cam: killer + weapon name + killer loadout + respawn countdown), 12 (roster alive/dead icons), 08.3 (charged ultimate lost/kept on death — check next sheet).

### Sheet 005 (10:15–10:26, frames #60–#71) — RESPAWN SEQUENCE

OBSERVED
- #60 10:15 "Respawn in 2", #61 10:16 (`w_00061_00-10-16.000.jpg`) "Respawn in 1": kill-cam continues. At #61 the killer has himself been splatted (his nametag now floats at floor level, a teal ink canister/weapon lies on the floor; roster shows a teal squid X'd). A right-side callout panel "Killer Wail" with an inkling portrait slides in under the special gauge (INFERENCE: notification that a player — probably a teammate — activated the Killer Wail special).
- Death frame #58 (10:13) → countdown 3/2/1 at 10:14/10:15/10:16 (1 number per second).
- #62 10:17 (`w_00062_00-10-17.000.jpg`): **respawn presentation** — camera placed high behind the own spawn pad looking out over the map; the player comes down from the sky as a glowing orange squid-shaped projectile with a red/pink contrail, heading to the pad. HUD intact. **Special gauge now only about half full** (ring from 12 to ~6 o'clock) and "Press R" is gone.
- #63 10:18 (`w_00063_00-10-18.000.jpg`): player lands on pad as an orange squid, splashing and popping up; sparkle particles around pad.
- #64 10:19: player standing, running forward off the pad; points resume 0240. Roster: 3 orange X'd, 1 teal X'd at 2:13 — heavy losses for own team at that moment.
- #65–#71 10:20–10:26: player repaints own base area (ramps, walls near spawn) while heading back out; points 0240 → 0275.
- Camera on respawn: after the pad drop it snaps back to normal over-shoulder follow.

INFERENCE
- Death → back in control ≈ 5–6 s (10:13 death frame → 10:18 landing → 10:19 moving). Visible countdown is 3 s, then ~1–2 s of drop-in animation. Compare Color Clash 4 s respawn (06.3): total downtime in reference is ~5–6 s including the drop.
- Charged special is partially lost on death (full → ~50%): a death penalty on the ultimate meter.
- Respawn uses the same "launched squid" visual language as the super jump (fly in from sky onto a marked pad).

GDD mapping: 06.3 elimination/respawn (3-2-1 banner, kill-cam, total ~5–6 s), 06.4 spawn (drop-in on team pad), 08.3 ultimates (meter penalty on death; "special used" callout with portrait), 08.4 Team Launch visual language, 12.

### Sheet 006 (10:27–10:38, frames #72–#83)

OBSERVED
- 2:05 → 1:54. Player moves back toward mid through own-painted base lanes, alternately walking+shooting and swimming.
- #75 10:30 (`w_00075_00-10-30.000.jpg`, 2:02): large glowing **yellow-orange dome/blob** at left with light-ray streaks radiating around it (INFERENCE, uncertain: an ally special effect — e.g. a protective bubble or an ink-burst special — shown in team colour; could also be a large ink explosion). Player is swimming at the time: tank gauge next to reticle is low (small yellow fill), a dotted leader line runs from the swimmer to the gauge. Roster at 2:02: orange 1 X'd, teal 3 X'd (own team just won a fight).
- #76 10:31: swimming, gauge visible; camera very low, floor dominates bottom half.
- #77 10:32 / #79–#83: swimming up ramps and along walls; tank gauge filled (orange) while swimming, hidden when standing and shooting (#78 humanoid: no gauge).
- #81 10:36 (`w_00081_00-10-36.000.jpg`), #82 10:37 (`w_00082_00-10-37.000.jpg`): swimming through own ink, the swimmer shows only as a **translucent orange splash plume** rising from the ink surface (no clear body); a **thin white/pink straight line** crosses the view diagonally (INFERENCE: a charger's aiming laser from another player). Reticle keeps 4 spread tick marks while swimming. Gauge is a tall rounded capsule, dark outline, filled orange ≈ full at #81.
- Walls painted in blotchy orange patches with large unpainted gaps: players paint walls only where they deliberately shoot them.
- Points 0275 → 0294.

INFERENCE
- Tank gauge colour: yellow/pale while low/refilling, full orange when full (possibly team colour at full). Needs higher fps to confirm the colour shift.
- Swim form in own ink is nearly invisible to the viewer except for a splash plume + wake; strong stealth read.

GDD mapping: 05.1 swim (plume/wake, low camera), 05.3 tank (gauge next to reticle during swim), 04.2 camera, 08.3 (ally special visual — uncertain).

### Sheet 007 (10:39–10:50, frames #84–#95) — WALL PAINT + WALL CLIMB

OBSERVED
- #84–#87 10:39–10:42 (1:53–1:50): player stands at the base of a tall wall and **shoots it upward**, painting a large orange sheet over it. `w_00087_00-10-42.000.jpg`: camera pitched up toward the wall; the character is seen from behind/above at the bottom-centre, large in frame (camera pushed in close because the wall is right behind the aim point). Each shot leaves a ring-shaped splash (bright ring of spray ~1 character-head wide) on the wall. Points barely rise while painting the wall (0294 → 0295) — **wall paint does not appear to count for turf points**.
- #88–#89 10:43–10:44: continues painting the wall and floor; teal ink visible on the far side of a fence.
- #90 10:45 (`w_00090_00-10-45.000.jpg`, 1:47): **wall climb in squid form** — a small orange/pink squid with big white eyes is on the vertical orange wall, ~1.5 m up; the ink-tank gauge (capsule, ~full orange) pops up next to the reticle with a leader line to the squid. Squid on the wall IS visible (unlike when swimming on floor it read mostly as a plume). Camera follows lower/closer and faces the wall.
- #91 10:46 (`w_00091_00-10-46.000.jpg`): squid near the top lip of the wall; camera tilts up so the sky/overpass fill the top half; squid shows as a yellow glowing blob with a spray trail below it. Gauge still shown.
- #92–#95 10:47–10:50: player back in humanoid form (INFERENCE: climbed over / dropped onto the upper ledge), shooting and moving; wall paint with the unpainted pale patches clearly visible.
- Roster: one orange squid X'd throughout 1:50–1:46.

INFERENCE
- Climb takes roughly 1–2 s for a ~2-storey wall (between 10:44 and 10:46), requires the wall to be own-colour.
- Camera orients to face the wall during climb and tilts up as the player nears the top.

GDD mapping: 05.2 climb (wall must be painted first; squid visible on wall; camera tilt), 07 (wall painting pattern, ring splashes), 03 (wall paint not scored — needs confirmation), 04.2.

### Sheet 008 (10:51–11:02, frames #96–#107) — SPECIAL CHARGED AGAIN, LOW INK AGAIN

OBSERVED
- #96–#97 10:51–10:52: pushing into a teal-heavy corridor, painting over teal floor with orange (orange overwrites teal directly; mixed patches with hard irregular borders, no blending).
- #98 10:53 (`w_00098_00-10-53.000.jpg`, 1:38, points 030x): **special gauge full again** — big golden circle drawn around the player (≈ half screen diameter) with two crossing light beams and 4-point star sparkles; ring on HUD gets a glowing outline; "Charged!" + "Press R" text again.
- #99 10:54: "Charged!" still showing; player overlooks a teal area.
- #100 10:55 (`w_00100_00-10-55.000.jpg`, 1:36): clear view of the player from behind: inkling holding a green-trimmed compact shooter at hip height, boxy **ink tank on the back** that looks almost empty (white/translucent box, only a sliver of colour at the bottom). Ahead in the corridor floats an object framed by a **green diamond outline with red corner dots** (INFERENCE, uncertain: a thrown sub-weapon/device highlighted by the game, e.g. an enemy placeable).
- #101–#102 10:56–10:57: shooting, painting a teal ramp orange; points 0322 → 0334.
- #103 10:58 (`w_00103_00-10-58.000.jpg`, 1:33): **"Low ink!"** toast again under the player; icon = tank outline with red interior and red "spark" lines around it; box has brown/black hazard-stripe top edge. Player standing in a teal/orange border area.
- #104–#106 10:59–11:01: swimming (tank gauge beside reticle, small yellow fill rising); points frozen at 0335.
- #107 11:02: humanoid again, shooting. Special still held ("Press R").

INFERENCE
- Special re-charge after death: ~50% at 10:17 → full at 10:53 ≈ 36 s, ~60 points of painting.
- Back tank on the model is a diegetic ink level indicator (clear/white when empty). The HUD toast "Low ink!" + the reticle-side gauge are the explicit signals.
- The player's usage pattern: shoot until "Low ink!", swim ~3–4 s to refill, repeat.

GDD mapping: 05.3 tank (diegetic back tank, "Low ink!" toast, refill), 08.3 ultimate (charged FX: big ring + beams around player), 07 (weapon silhouette), 08.1 (possible highlighted gadget — uncertain).

### Sheet 009 (11:03–11:14, frames #108–#119)

OBSERVED
- 1:28 → 1:17; points 0335 → 0384. Player swims (#108–#109, gauge beside reticle) then walks forward shooting through a contested zone with lots of mixed teal/orange on floors and walls.
- #109–#110 11:04–11:05: "Killer Wail" callout panel (text + inkling portrait) again at right under the special ring (INFERENCE: another player's special activation notice; which team is not legible at 1 fps).
- `w_00109_00-11-04.000.jpg`: points digits caught mid-roll — the counter is a **mechanical odometer** (digits scroll vertically), with a small "p" suffix. Ring still "Press R".
- #111–#119: humanoid run-and-gun, thick orange trail directly under/behind the player; the weapon paints a lane roughly 1.5–2 character-widths wide while walking forward and firing. Walls get sporadic orange patches from stray shots.
- Roster (#114–#117): 1–2 teal squids X'd — enemies being splatted by teammates off-screen.
- No hits taken (no vignette).

INFERENCE
- Walking + firing forward yields a continuous paint lane: the core "paint trail" feel. The player keeps the special charged but does not fire it (holding it for ~50 s by now).

GDD mapping: 07 (paint lane width), 03 (points), 08.3 (special notices), 12 (odometer counter).

### Sheet 010 (11:15–11:26, frames #120–#131)

OBSERVED
- 1:16 → 1:05; points 0387 → 0394 then frozen at 0394 from 1:13 to 1:05 (mostly swimming).
- #122 11:17 (`w_00122_00-11-17.000.jpg`, 1:14): **light damage vignette** — scattered round teal droplets only along the left and top edges (compare the heavy border at 10:11). Back tank on the model shows an orange fill line about 1/3 up — the diegetic tank level is readable from behind. Roster: 1 orange X'd, 2 teal X'd.
- #123 11:18 (1:13): "Low ink!" toast again (third time this round).
- #124–#131 11:19–11:26: long swim/refill + reposition through own ink; tank gauge beside reticle visible in every swim frame (fill grows from yellow-low to orange-full). #126 11:21 (`w_00126_00-11-21.000.jpg`): large splash of orange and teal droplets in the foreground as the swimmer passes from a teal patch into orange — splash particles take the colour of the surface ink.
- #131 11:26: an enemy (teal inkling) visible up on a ledge at the far end.

INFERENCE
- Damage indicator intensity scales with damage (few droplets = light hit; full border = near death). The vignette fades within ~1–2 s when not taking more hits (gone by #123).
- Swim-to-refill from low to full appears to take ~4–6 s here (11:19 → ~11:24), consistent with earlier ~3–4 s.

GDD mapping: 05.4 health (scaled vignette + regen fade), 05.3 tank, 05.1 swim (splash colour = surface colour).

### Sheet 011 (11:27–11:38, frames #132–#143) — 1 MINUTE LEFT, SPECIAL ACTIVATION (BUBBLE SHIELD)

OBSERVED
- #132 11:27 (1:04): swimming up a ramp, gauge beside reticle.
- #133–#136: running and shooting with teammate "みかど" nearby; points 0394 → 0400.
- #137 11:32 (`w_00137_00-11-32.000.jpg`): **"1 minute left!"** — large white semi-transparent halftone text with a clock glyph, sliding across mid-screen; **timer digits turn YELLOW** at 0:59 (white until 1:00 at #136). Text persists ~2 s (still partly visible sliding out at #138 "ft!").
- #140 11:35 (0:56): last frame with "Press R".
- #141 11:36 (`w_00141_00-11-36.000.jpg`, 0:55): **special activated** — player encased in a glowing golden/orange translucent sphere with a honeycomb/halftone surface and bright rim; an orange **callout banner "Bubbler"** with an inkling portrait slides in at right, under the special ring. The HUD ring is now **draining**: orange only from ~1 to ~7 o'clock (it has become a duration timer). "Press R" gone.
- #142 11:37: bubble still around player; teammate close by.
- #143 11:38 (`w_00143_00-11-38.000.jpg`, 0:53): **both the player and teammate "みかど" are inside bubbles** (the teammate's bubble is brighter/newer) — INFERENCE: the shield spreads to nearby allies. Ring drained further (~1–5 o'clock). A spiky yellow/red **"Danger!"** burst label is attached to the right end of the teal roster (above the 4th enemy icon) — INFERENCE: warns that an enemy has a special active/ready.
- Earlier "Killer Wail" callouts (#61–#62, #109–#110) use the same banner format as "Bubbler" (special name + portrait).

INFERENCE
- Activation happened between 11:35 and 11:36; the player held the charged special ~1 min before using it. Duration visible from ~11:36 to at least 11:38; see next sheet for end.
- Special-activation feedback: world FX on the player (sphere), name banner on HUD, HUD ring converts to a countdown.

GDD mapping: 03 (1-minute warning + timer colour change), 08.3 ultimates (activation banner, ring→duration timer, ally-sharing shield), 12 (special banner position under ring; enemy "Danger!" tag on roster).

### Sheet 012 (11:39–11:50, frames #144–#155) — SHIELD ENDS, SECOND DEATH, SECOND RESPAWN

OBSERVED
- #144 11:39 (`w_00144_00-11-39.000.jpg`, 0:52): player swimming inside the shield — a bright golden arc (the bubble's rim) sweeps across the camera because the camera sits partly inside the sphere. Ring nearly drained (~1–4 o'clock).
- #145 11:40: bubble still visible around humanoid player; ring almost empty.
- #146 11:41: no bubble visible; ring grey/empty. => **Shield duration ≈ 5 s** (11:36 → ~11:40/41).
- "Danger!" tag stays on the teal roster from 11:38 to ~11:48.
- #147 11:42 (`w_00147_00-11-42.000.jpg`, 0:49): enemy (teal, holding a chunky gun) at point-blank range (~2 m) directly ahead; player is shooting; top-down-ish camera (camera pitched down more steeply because player is on a slope looking down).
- #148 11:43 (`w_00148_00-11-43.000.jpg`, 0:48): player turned into **squid inside ENEMY (teal) ink** — squid is fully exposed/visible (orange squid with eyes sitting on top of teal surface, not submerged) right beside the enemy. Heavy teal vignette with a **halftone dot pattern** at its inner edge.
- #149 11:44 (`w_00149_00-11-44.000.jpg`, 0:47): **splatted** — only a ripple ring and the dropped orange weapon remain on the teal floor; vignette at max. Roster: 2 orange X'd.
- #150 11:45 "Respawn in 3", #151 11:46 "Respawn in 2", #152 11:47 "Respawn in 1" — kill-cam on the same enemy (".52 Gal!" again, same gear panel). Enemy's shot visible as a thick teal stream/spray from the gun (#150).
- #153 11:48 (`w_00153_00-11-48.000.jpg`, 0:43): high camera over the own spawn pad looking toward mid; pad empty (player about to land). A large orange egg-shaped squid-face object with dark X-like eyes floats upper-left near teammate tags (INFERENCE, uncertain: teammate death/ghost marker seen close up, or a teammate mid-launch).
- #154 11:49: player on pad (landing splash); #155 11:50: running off pad.
- Special ring after respawn: empty (it had been used).

INFERENCE
- Second death→control: 11:44 death frame → 11:49 on pad → 11:50 moving ≈ 5–6 s again (3 s counted + ~2 s drop-in). Consistent with first death.
- Squid form in enemy ink is visibly exposed (no stealth) — strong readability cue for "you're in enemy territory". Movement slowing can't be measured at 1 fps.

GDD mapping: 08.3 (shield duration/ring as timer), 05.1 (squid exposed in enemy ink), 05.4 (vignette halftone edge), 06.3/06.4 (respawn 3-2-1 + pad drop, ~5–6 s total), 12 ("Danger!" roster tag).

### Sheet 013 (11:51–12:02, frames #156–#167) — SQUID JUMP, ALLY KILLER WAIL

OBSERVED
- 0:40 → 0:29 (timer yellow). Points 0427 → 0434 (slow; player mostly traveling).
- #157 11:52 (`w_00157_00-11-52.000.jpg`, 0:39): **jumping out of ink as a squid** — a tall glossy orange column/tentacle shape shoots up next to a wall with big shiny liquid splash droplets around it; tank gauge beside reticle (orange, about 3/4). INFERENCE: squid-jump / surfacing burst or the start of a wall climb on the painted wall at left (unpainted pale wall at left suggests a jump rather than climb).
- #158–#160: swimming along own paint; gauge visible (yellow when low).
- #161–#162 11:56–11:57: a large purple barrel-shaped object with a squid logo stands on legs in the corridor (level prop).
- #163 11:58 (0:33): big yellow liquid burst mid-air + "Killer Wail" banner appears.
- #164 11:59 (`w_00164_00-11-59.000.jpg`, 0:32): **ally Killer Wail**: a large loudspeaker on four legs (in own team orange/black) placed on a ledge, blasting a wide swirling **orange** beam cone to the right; banner "Killer Wail" + portrait at right under the ring; teammate "Sabby" nametag nearby. Own special ring shows only a tiny orange sliver at 12 o'clock (recharging from zero after Bubbler).
- #165 12:00 (`w_00165_00-12-00.000.jpg`, 0:31): camera close to the speaker; the beam is a big spiral tunnel of orange with mixed teal/green streaks inside, clearly passing through the space above the player. Orange splash rings on the floor near the player.
- #166 12:01: player runs past the speaker; beam still active (~3 s observed).
- #167 12:02: swimming, gauge low (yellow).
- Banner portrait for "Killer Wail" looks identical to the one shown for the player's own "Bubbler" (#141–#143) — INFERENCE: the portrait may be a generic/player-avatar icon rather than identifying the user; can't resolve at this resolution.

INFERENCE
- Specials of allies are rendered in the ally team colour (orange) — a readable cue of which side the special belongs to.
- Squid form can burst up out of ink (surfacing/jump) with an exaggerated liquid column — very juicy feedback.

GDD mapping: 05.1 (squid jump surfacing FX), 08.3 (ally ultimate in team colour, banner callout), 12.

### Sheet 014 (12:03–12:14, frames #168–#179) — ROLLER KILL, THIRD RESPAWN

OBSERVED
- #168–#170 12:03–12:05 (0:28–0:26): pushing into a mixed teal/orange courtyard, swimming then shooting; points 0434 → 0440.
- #171 12:06 (`w_00171_00-12-06.000.jpg`, 0:25): **big hit moment** — radial yellow/orange **speed-line burst** covering the whole screen from the centre outwards, plus teal vignette with halftone edge. An enemy roller-user is mid-air vaulting over a low wall toward the player (roller flicking a teal spray arc). Player being hit (teal splashes on body).
- #172 12:07 (`w_00172_00-12-07.000.jpg`, 0:24): **player splatted** — ripple rings + dropped weapon on the teal floor; the player's own death marker (orange sad-faced squid glyph with a spiky glowing halo) rises at left. Enemy roller-user + teammate "Sabby" fighting nearby.
- #173 12:08 (`w_00173_00-12-08.000.jpg`): kill-cam pans to the roller enemy (teal ink, big orange-handled roller) — no text yet.
- #174 12:09 (`w_00174_00-12-09.000.jpg`): **"Squished by Krak-On Splat Roller!"** (verb changes per weapon type: "Splatted" for guns, "Squished" for roller) + killer gear panel — this time the sub-ability slots are filled with icons, not "?" + "Respawn in 3".
- #175 "Respawn in 2", #176 "Respawn in 1" (12:10, 12:11).
- #177 12:12 (`w_00177_00-12-12.000.jpg`, 0:19): camera behind/above own pad; pad surface shows an animated halftone swirl; a small pink/white glowing object in the air near the ramp (INFERENCE: player/ally projectile in flight). 
- #178 12:13: landing on pad; #179 12:14 (0:17): player running off pad with gauge visible (full).
- Roster at 12:07–12:12: 2 orange X'd, 1–2 teal X'd.

INFERENCE
- Third death: 12:07 death → 12:14 moving ≈ 7 s (kill-cam text appeared 2 s after death this time vs 1 s before; 1 fps granularity). Across three deaths: ~5–7 s total downtime.
- The radial speed-line burst at 12:06 is a heavy-hit/"about to die" or roller-impact emphasis effect; needs 10–60 fps to see whether it is on damage or on death.
- Ink tank is refilled to full on respawn (gauge full at #179).

GDD mapping: 06.3 (kill-cam text varies by weapon class; ~5–7 s), 05.4 (radial burst on heavy hit), 06.4 (pad drop), 05.3 (full tank on spawn), 07 (roller vs shooter kill verbs).

### Sheet 015 (12:15–12:26, frames #180–#191) — FINAL 10-SECOND COUNTDOWN

OBSERVED
- 0:16 → 0:05; points 0445 → 0494 (fastest painting of the round: ~5 pts/s while spraying fresh/contested ground near spawn-side mid).
- #184 12:19 (`w_00184_00-12-19.000.jpg`, 0:12): clearest camera reference — character seen from directly behind, **centred horizontally** (no visible shoulder offset; reticle sits straight above the head), character ≈ 25% of screen height (feet y≈600, head y≈420), camera above head height looking down ~30°. Back tank on the character is white/near-empty.
- #185 12:20 (`w_00185_00-12-20.000.jpg`, 0:11): a **golden ring marker on the floor** at the player's feet, with a curved label band reading "Sabby" and a "3" glyph; #186–#187 the ring/label persists and follows the player position, the "Sabby" label growing into a tilted banner (#187 `w_00187_00-12-22.000.jpg`). INFERENCE: this is the landing marker of an ally ("Sabby") **super-jumping to the player** — the marker is anchored on the jump target. (Uncertain; landing itself not captured at 1 fps.)
- **Final countdown**: from 0:10 a **huge outlined white numeral** is drawn over the centre of the screen, around the player/reticle: "10" at #186 12:21 (`w_00186_00-12-21.000.jpg`), "9" at #187 12:22, "8" at #188 12:23 (`w_00188_00-12-23.000.jpg`), "7" at #189, "6" #190, "5" #191 — thin double-line outline, semi-transparent (world visible through), ≈ 1/3 screen height, one per second in sync with the timer. Timer stays yellow.
- #187: swimming in teal/orange border area, gauge low (yellow).
- Roster mostly all alive near the end (1 orange X'd at 0:12–0:09).

INFERENCE
- Final countdown is non-intrusive (outline only) so play remains readable while tension rises.
- "1 minute left!" (text banner) + yellow timer + 10..1 outline numerals = three-stage end-of-round escalation.

GDD mapping: 03 (final countdown presentation), 04.2 (camera centred, no shoulder offset, ~25% char height), 08.4 Team Launch (landing marker on target teammate — inferred), 12.

### Sheet 016 (12:27–12:38, frames #192–#203) — GAME! AND JUDGING

OBSERVED
- #192–#194 12:27–12:29 (0:04–0:02): countdown numerals "4", "3", "2" outlines continue. #194 `w_00194`: "Low ink!" toast at 0:02. Points 0494 → 0499.
- #195 12:30 (`w_00195_00-12-30.000.jpg`, **0:01**): outline "1" over the centre; a "Danger!" burst now on the LEFT (orange) end of the roster (so the tag appears for either team). The roster bar is visibly **asymmetric**: orange icons smaller and "vs" divider shifted left to x≈590, teal icons larger. (At 0:53 `w_00143` it was the reverse: orange larger, divider at x≈690; at GO `w_00017` equal, divider at 640.) INFERENCE: the roster bar is a live relative indicator of something (possibly players alive / special readiness); NOT confirmed to be turf %. Do not copy blindly.
- #196 12:31 (`w_00196_00-12-31.000.jpg`): **"GAME!"** — several thick lavender/purple **tape strips** printed "GAME!" in black slap diagonally across the screen (crossing X pattern); HUD is removed; the gameplay freezes (player shown mid-action as a squid, small green marker dot).
- #197 12:32: more tapes cover the screen; #198 12:33: background cut to black with the tapes still on screen (transition).
- #199 12:34 (`w_00199_00-12-34.000.jpg`): **top-down overhead view of the whole stage** with all painted turf visible: orange concentrated on the own-base (left) half, teal on the right half, a mixed contested strip in the middle; stage walls outlined in purple; surrounding city blocks in grey. No UI yet.
- #200 12:35 (`w_00200`): a **judge mascot** (large grumpy cat character) pops up in front of the map; bottom bar appears: "Good Guys" (own team, orange text, left) vs "Bad Guys" (enemy, teal text, right); both at **0.0%**.
- #201 12:36: both sides count up together: "5.2%" / "5.2%" with points below.
- #202 12:37 (`w_00202_00-12-37.000.jpg`): "23.7% / 496p" on BOTH sides — orange bar fills from the left, teal bar fills from the right, towards the middle; both show identical values while counting (suspense).
- #203 12:38: "25.5% / 534p" both sides, judge still with arms crossed; a small teal flag begins to appear near the judge's hand.

INFERENCE
- Results reveal is deliberately suspenseful: the two sides count up in lock-step until the loser's value stops.
- Values shown: % of inkable turf + a points number (turf points, "p") per team.

GDD mapping: 03 (GAME! end card, overhead map, judge + dual counting bar, % and points), 10.7 (overhead map is effectively the only map view in this footage — no minimap on TV HUD), 12.

### Sheet 017 (12:39–12:50, frames #204–#215) — VERDICT + SCOREBOARD

OBSERVED
- #204 12:39 (`w_00204_00-12-39.000.jpg`): judge cat raises a **teal flag with a squid emblem** (winner's colour); final bar **Good Guys 34.6% / 725p** vs **Bad Guys 50.7% / 1063p** — the orange bar stopped and the teal bar continued past it. A large orange ink-splat banner "DEFEAT" slams into the top-left corner (in the player's own team colour).
- #205–#206 12:40–12:41: black brush-stroke "#" hash marks splat across the screen (wipe transition).
- #207 12:42: own team's four inklings standing in a row with nametags (みかど, ZackScott, Ackey, Sabby) in front of a blurred map; result bar still at bottom.
- #208–#210 12:43–12:45: own team plays **defeat animations** (slumping, kneeling, dropping weapons). "DEFEAT" splat stays top-left.
- #211 12:46: individual view — top-left orange splat now shows the player's personal **"499p"**; the player's character in a dejected pose at lower-left.
- #212 12:47 (`w_00212_00-12-47.000.jpg`): **scoreboard** slides in on the right: "VICTORY!" header (teal splat) with 4 teal rows, then "DEFEAT" header (orange splat) with 4 orange rows. Each row: "Level N", player avatar face, weapon icon, name, points (e.g. 968p), and two small counters: splats dealt ("x5") and times splatted ("x3"). The recording player's row (**ZackScott, Level 1, 499p, 0 splats / 3 deaths**) is highlighted by extending further left with a lighter border. Winners' points ~776–968p, losers 499–546p. Player's weapon icon = a compact shooter.
- #213–#215: static scoreboard.

INFERENCE
- The player's 3 deaths on the scoreboard match the 3 deaths observed at 10:13, 11:44, 12:07 → our death timestamps are complete for this player.
- Winners' points appear to include a win bonus (points noticeably higher than any loser; enemy "Afro" with 0 splats has 870p) — not verifiable from footage alone.
- Personal points shown in results equal the in-match odometer (0499 at 0:01 → 499p).

GDD mapping: 03 (verdict flag, % + points per team, DEFEAT/VICTORY splat, team pose, personal points, scoreboard with K/D), 12.

### Sheet 018 (12:51–12:54, frames #216–#219) — REWARDS TALLY

OBSERVED
- #216 12:51: scoreboard still shown.
- #217 12:52: scoreboard slides up/out; a "Cash 0000000" and "Level" panel slides in from below.
- #218 12:53 (`w_00218_00-12-53.000.jpg`): **points transfer animation**: the top-left splat counts DOWN ("67p") while "Cash" counts up (0000352) and the "Level" XP bar fills (green paint bar, "352/700", level 1 badge in a green splat). A "Gear" panel below shows the player's 3 gear pieces (headband, tee, shoes) with small gear-XP bars.
- #219 12:54 (`w_00219`): splat reads "0p"; Cash 0000499; Level bar 499/700. End of extracted window.

INFERENCE
- Turf points convert 1:1 into currency and XP for this defeat (no bonus shown).

GDD mapping: 03 (post-round reward tally), 12.

---

# SYNTHESIS (answers to GDD 16.2)

All times are source time (HH:MM:SS); frame file = `C:\Color-Clash\reference\video_review\windows\round_urchin_0915\w_<idx>_<time>.jpg`, idx = seconds since 09:15. 1 fps sampling — events shorter than ~1 s may be missed and all durations are ±1 s.

## a) Round structure  (GDD 03, 06.4, 12)

| Phase | Source time | Evidence | Notes |
|---|---|---|---|
| Lobby "BATTLE TIME!" (8 players, mode + 2-stage rotation) | 09:15 | `w_00000_00-09-15.000.jpg` | OBSERVED |
| Squid-shaped iris wipe → black loading with ink-blob | 09:16–09:19 | `w_00001`…`w_00004` | ~4 s |
| Stage fly-over with "Turf War / Ink the most turf to win! / Urchin Underpass" | 09:20–09:23 | `w_00005_00-09-20.000.jpg` | ~4 s |
| White flash → own team pops out of spawn pad (squid→kid) with nametags | 09:24–09:27 | `w_00011_00-09-26.000.jpg` | |
| Enemy team intro on their pad (teal) | 09:28–09:29 | `w_00013`, `w_00014` | ~2 s |
| "Ready?" over-shoulder on pad, "You" label over own player | 09:30–09:31 | `w_00015_00-09-30.000.jpg` | ~2 s |
| **"GO!"** + HUD appears, timer 3:00 | 09:32 | `w_00017_00-09-32.000.jpg` | control granted ≈ here |
| First enemy ink seen on floor | 09:58 (2:34) | `w_00043_00-09-58.000.jpg` | |
| First contact / contested mid reached | ~10:03–10:06 (2:29–2:26) | `w_00048`…`w_00051` | **≈ 30–35 s from GO** for this (roundabout, painting) route. INFERENCE: a direct swim would be much faster; the player painted home turf first. |
| "1 minute left!" banner, timer turns yellow | 11:32 (0:59) | `w_00137_00-11-32.000.jpg` | |
| Final 10..1 outline numerals centre-screen | 12:21–12:30 | `w_00186`, `w_00188`, `w_00195` | 1 per s |
| **"GAME!"** tape strips, freeze | 12:31–12:33 | `w_00196_00-12-31.000.jpg` | round length GO→GAME ≈ 179–180 s ✔ |
| Overhead full-map reveal | 12:34 | `w_00199_00-12-34.000.jpg` | |
| Judge + dual count-up bar (both sides rise in lockstep 0.0→25.5%) | 12:35–12:38 | `w_00202_00-12-37.000.jpg` | |
| Verdict: flag in winner colour, final 34.6%/725p vs 50.7%/1063p, "DEFEAT" splat | 12:39 | `w_00204_00-12-39.000.jpg` | |
| Ink-stroke wipe → team pose (defeat anims) | 12:40–12:45 | `w_00207`…`w_00210` | |
| Personal points (499p) → scoreboard (level, weapon, pts, splats, deaths) | 12:46–12:51 | `w_00212_00-12-47.000.jpg` | |
| Reward tally (points → cash + XP) | 12:52–12:54 | `w_00218_00-12-53.000.jpg` | |

Total: GAME! → scoreboard ≈ 16 s; intro (name card) → GO ≈ 12 s after loading.

## b) Friendly vs enemy paint  (GDD 07, 12)
- OBSERVED: two highly saturated complementary hues — own = orange, enemy = teal/cyan — on a desaturated grey/white/black level palette (`w_00021`, `w_00056_00-10-11.000.jpg`, `w_00199`).
- Paint is glossy: specular highlights turn lit orange areas yellow (`w_00025_00-09-40.000.jpg`), shadowed areas deep orange; teal similarly lighter in sun.
- Edges: irregular blobby outlines with satellite droplets; no soft blending — the newer colour overwrites the older with a hard edge (`w_00096`, `w_00100_00-10-55.000.jpg`).
- Walls take paint identically to floors; players paint walls only where aimed so walls are patchy (`w_00082`, `w_00087_00-10-42.000.jpg`). Wall paint didn't raise the points counter (0294→0295 during a big wall paint, 10:39–10:42) — INFERENCE: walls aren't scored.
- Paint conforms to geometry (grates stay unpainted between bars, `w_00023`).
- Size: a single shot impact splat ≈ 1 character-width; continuous walk+fire lane ≈ 1.5–2 character widths (`w_00111`–`w_00119`). A roller-user was seen (enemy) but its paint strip wasn't captured clearly.
- Splash particles take the colour of the ink surface they come from (`w_00126_00-11-21.000.jpg`).

## c) Paint tank  (GDD 05.3, 12)
- No permanent tank bar on the HUD. Three signals:
  1. **Diegetic back tank** on the character — reads white/empty vs coloured fill (`w_00100_00-10-55.000.jpg` empty; `w_00122_00-11-17.000.jpg` ~1/3).
  2. **"Low ink!" toast** just below the character (dark box, hazard-stripe top edge, red tank icon): 09:51 (`w_00036`), 10:58 (`w_00103`), 11:18 (`w_00123`), 12:29 (`w_00194`).
  3. **Contextual capsule gauge beside the reticle** (right of it, joined by a thin leader line) shown only while in squid form; fill rises while swimming in own ink: yellow/pale when low, orange when full (`w_00038_00-09-53.000.jpg` low → `w_00041_00-09-56.000.jpg` near-full ≈ 3 s).
- Refill: ~3–5 s from low to full while swimming (09:53→09:56; 11:19→~11:24). Tank full after respawn (`w_00179`).
- Points counter freezes while swimming (no painting).

## d) Camera  (GDD 04.2)
- Third-person, behind and above; character **centred horizontally, no visible shoulder offset** — reticle sits directly above the head (`w_00184_00-12-19.000.jpg`). Character height ≈ 20–25% of screen when standing; pitch ~25–35° down in neutral.
- Swimming: camera drops lower/closer to the floor, horizon rises (`w_00041`, `w_00081_00-10-36.000.jpg`).
- Wall climb: camera faces the wall and tilts up near the top, showing sky (`w_00090`, `w_00091_00-10-46.000.jpg`).
- Aiming up at a wall: camera pitches up, character large in lower frame (`w_00087`). On slopes looking down the camera becomes near top-down (`w_00147`).
- Occlusion: player rendered semi-transparent when foliage is between camera and character (`w_00025`); camera can sit inside a shield sphere (`w_00144`).
- FOV feels moderately wide (INFERENCE ~70–80° horizontal equivalent; not measurable).
- Death: camera swings to the killer (kill-cam). Respawn: fixed high shot behind own pad looking toward mid (`w_00062`, `w_00153`, `w_00177`).

## e) Movement  (GDD 05.1–05.3)
- Swim form in own ink: character barely visible — splash plume + wake ripples only (`w_00041`, `w_00081`, `w_00082`); small squid visible when on low ink/transitions (`w_00038`).
- Squid in ENEMY ink is fully exposed on top of the surface (`w_00148_00-11-43.000.jpg`) — lethal situation; slowing can't be measured at 1 fps.
- Wall climb: squid visibly travels up a painted wall in ~1–2 s (10:44→10:46), gauge shown (`w_00090`, `w_00091`).
- Surfacing jump: tall glossy ink column + droplets (`w_00157_00-11-52.000.jpg`).
- Speed feel: swimming covers large distances between 1-s frames; walking while firing is noticeably slower (lanes painted steadily). No numbers claimed.

## f) Weapon  (GDD 07)
- Player: a compact starter shooter (weapon icon on scoreboard `w_00212`; held at hip `w_00100`). Full-auto stream of blobs; reticle = small white/pink circle + 4 tick marks at wider radius (spread indicator) (`w_00021`, `w_00081`).
- Range feel: short-medium — impacts land a few character heights ahead of the player on flat ground; reticle projects onto the floor ahead.
- Spray visuals: bright orange droplets and ring-shaped splashes on impact (`w_00087`), star-shaped splash decals on floor (`w_00025`).
- Enemies seen: .52 Gal (kill-cam `w_00059_00-10-14.000.jpg`, thick teal stream `w_00150`), Krak-On Splat Roller (`w_00171`, `w_00174`), a charger-like long gun (enemy intro `w_00014`; possible aiming laser `w_00081`).

## g) Combat readability  (GDD 05.4, 06.3, 06.4, 08.4)
- Damage indicator: **enemy-colour ink splatter around the screen edges** — few droplets for a light hit (`w_00122`), almost the whole border for near-death with a halftone inner edge (`w_00056`, `w_00148`). Fades within ~1–2 s when safe.
- Heavy-hit emphasis: radial yellow speed-line burst (`w_00171_00-12-06.000.jpg`, roller kill).
- On death: body vanishes, dropped weapon + ripple ring left on the floor (`w_00058`, `w_00149`, `w_00172`); a sad-faced squid ghost glyph rises (`w_00172`, teammate version `w_00057`); roster icon becomes grey with X.
- Kill-cam: camera on killer, spiky black bubble "Splatted by <weapon>!" / "Squished by <roller>!", killer's gear+abilities panel, "Respawn in 3/2/1" arrow banner bottom-right (`w_00059`, `w_00174_00-12-09.000.jpg`).
- **Respawn timing** (death frame → controllable):
  - Death 1: 10:13 → counter 3 at 10:14 → drop-in 10:17 → land 10:18 → moving 10:19 ≈ **5–6 s**
  - Death 2: 11:44 → 3 at 11:45 → pad 11:48 → land 11:49 → moving 11:50 ≈ **5–6 s**
  - Death 3: 12:07 → 3 at 12:09 → pad 12:12 → land 12:13 → moving 12:14 ≈ **6–7 s**
  - Visible countdown is always 3 s; the rest is kill-cam lead-in + fly-in to pad. Compare our 4 s respawn (06.3).
- Respawn presentation: player flies in from the sky as a glowing squid projectile with contrail onto the team pad (`w_00062_00-10-17.000.jpg`), squid→kid pop on pad (`w_00063`). No explicit spawn-protection visual observed (06.4: nothing to copy/compare).
- Super jump: INFERENCE only — golden ring + ally name ("Sabby") + "3" glyph anchored at the player's feet at 12:20–12:22 (`w_00185`, `w_00187`) looks like a teammate's landing marker. Launch/landing itself not captured.
- Special gauge penalty on death: full → ~50% (10:13 → 10:17, `w_00062`).

## h) Sub weapon / special  (GDD 08.1, 08.3)
- Sub weapon: **no throw, arc preview or bomb explosion by the player was observed** in this round. One possible highlighted enemy device (green diamond outline with red dots) at `w_00100` — uncertain.
- Special gauge: ring around a special icon, top-right; fills clockwise from 12 o'clock with painting (`w_00021` quarter at 2:56). Full at 10:01 (≈29 s after GO) → "Charged!" text + "Press R" prompt + golden ring/aura burst around the player (`w_00046_00-10-01.000.jpg`, `w_00098_00-10-53.000.jpg`).
- Activation 11:35→11:36: golden honeycomb shield sphere around the player, spreading to a nearby ally; banner "Bubbler" + portrait slides in under the ring; ring becomes a draining duration timer (`w_00141_00-11-36.000.jpg`, `w_00143_00-11-38.000.jpg`); lasted ≈ 5 s (gone by 11:41).
- Other specials: ally "Killer Wail" giant speaker blasting a spiral beam in orange (`w_00164`, `w_00165_00-12-00.000.jpg`), with the same banner format.
- "Danger!" spiky tag on the roster (enemy side 11:38–11:48, own side at 12:30) — INFERENCE: flags a player with special active/ready.

## i) HUD layout (1280x720 reference, `w_00021_00-09-36.000.jpg`, `w_00017`)  (GDD 12, 10.7)
- **Top-left** (~x50–215, y30–70): timer pill (black rounded, stopwatch icon, white "M:SS"; turns yellow in final minute).
- **Top-centre** (~x385–895, y25–70): team roster — 4 own squid icons "vs" 4 enemy icons on a black bar; icons grey+X when splatted; divider/icon sizes shift during the match (meaning unconfirmed); "Danger!" tags attach here.
- **Top-right** (~x935–1120, y30–80): 4-digit odometer points counter with "p".
- **Far top-right** (~x1100–1230, y25–145): special ring gauge around special icon; "Press R" prompt at its lower right; "Charged!" text to its left; special activation banners slide in below it (~y230–295).
- **Right, under ring** (~x1100–1235, y165–200): three small circular gear-ability icons.
- **Centre** (~x640–660, y350–450): reticle; ink capsule gauge appears ~90 px to its right while swimming.
- **Below character** (~x565–720, y520–575): "Low ink!" toast.
- **Bottom-left** (~x55–135, y600–690): "C'mon! / d-pad / Booyah!" callout hint.
- **Bottom-right** (on death only): "Respawn in N" banner (~x930–1260, y645–695); left-centre killer gear panel.
- **No minimap on the TV HUD** (INFERENCE: the original shows the map on a second screen; our 10.7 minimap has no direct reference here). The only full map view is the post-game overhead (`w_00199`).
- Centre-screen text events: "Ready?"/"GO!", "1 minute left!", 10..1 outline numerals, "GAME!".

## Moments for high-frame-rate inspection
(start–end in source seconds; 555 s = 09:15)

| # | Window (source s) | Time | What happens | Evidence (1 fps) | Suggested rate | GDD |
|---|---|---|---|---|---|---|
| 1 | 585–590 | 09:30–09:35 | "Ready?" → "GO!" → HUD pop-in, first steps off pad (when is control granted?) | `w_00015`–`w_00020` | 60 fps | 03, 12 |
| 2 | 591–597 | 09:51–09:57 | "Low ink!" toast → squid transform → reticle-side tank gauge pop-in and refill | `w_00036`–`w_00042` | 10 fps | 05.1, 05.3 |
| 3 | 606–614 | 10:06–10:14 | Damage vignette build-up → splat (body vanishes, weapon drops) → kill-cam + "Respawn in 3" | `w_00051`–`w_00059` | 10 fps; 60 fps for 612–614 | 05.4, 06.3 |
| 4 | 616–620 | 10:16–10:20 | Respawn fly-in from sky → pad landing → squid-to-kid pop → first step; special meter after death | `w_00061`–`w_00065` | 60 fps | 06.3, 06.4, 08.4 |
| 5 | 643–647 | 10:43–10:47 | Squid wall climb up a painted wall and top-out, camera tilt | `w_00088`–`w_00092` | 60 fps | 05.2, 04.2 |
| 6 | 694–699 | 11:34–11:39 | Special activation (Press R) → shield sphere, spread to ally, banner slide-in, ring becomes drain timer | `w_00139`–`w_00144` | 60 fps | 08.3, 12 |
| 7 | 701–706 | 11:41–11:46 | Point-blank duel, squid exposed in enemy ink, splat, kill-cam text reveal | `w_00146`–`w_00151` | 10 fps | 05.1, 05.4, 06.3 |
| 8 | 711–714 | 11:51–11:54 | Squid surfacing jump (ink column) out of own ink | `w_00156`–`w_00159` | 60 fps | 05.1 |
| 9 | 725–730 | 12:05–12:10 | Roller vault + radial speed-line burst → death → "Squished by" kill-cam | `w_00170`–`w_00175` | 60 fps for 725–728 | 05.4, 06.3, 07 |
| 10 | 739–744 | 12:19–12:24 | Golden ring + "Sabby" marker at player's feet (suspected ally super-jump landing) + 10/9/8 countdown numerals | `w_00184`–`w_00189` | 10 fps | 08.4, 03 |
| 11 | 750–756 | 12:30–12:36 | 0:01 → "GAME!" tape slam → black → overhead map → judge + bar at 0.0% | `w_00195`–`w_00201` | 10 fps | 03 |
| 12 | 757–762 | 12:37–12:42 | Dual count-up → loser bar stops → flag + "DEFEAT" splat → ink-stroke wipe | `w_00202`–`w_00207` | 10 fps | 03 |
