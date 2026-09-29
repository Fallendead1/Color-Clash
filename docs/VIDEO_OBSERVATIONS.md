# Video Observations — Colorclashvideoreference

Status: IN PROGRESS (overview pass)

This file follows GDD Section 16 and START_HERE B/C. Every entry separates **OBSERVED** (visible in an extracted image),
**INFERENCE** (reasoned from what is visible, not directly shown) and **PROPOSED** (a change or experiment for our game).
The reference is a feel/behaviour reference only. Nothing here overrides the GDD's values, names or scope unless recorded
as a decision in `docs/DECISIONS.md`.

## Source

| Field | Value (from ffprobe, 2026-09-29) |
|---|---|
| Absolute path | `C:\Color-Clash\Colorclashvideoreference.mp4` (user referred to `C:\ColorClash`; that path does not exist — the files are in `C:\Color-Clash`) |
| Container | MP4 (`mov,mp4,m4a,3gp,3g2,mj2`), 1,827,420,759 bytes, 4.39 Mb/s |
| Duration | 3332.27 s container / 3332.18 s video (00:55:32) |
| Video | H.264 High, 1920×1080, 60/1 fps (r_frame_rate = avg_frame_rate → constant 60 fps), 199,931 frames, time_base 1/15360, start 0 |
| Audio | AAC LC, 44.1 kHz stereo. **Audio was not processed or listened to.** No transcript was available. |
| Original | Not modified, not re-encoded, not uploaded. Only individual frames were decoded locally with ffmpeg. |

## Method

- Script: `tools/extract_video_frames.py` (Python 3.12.10 venv at `tools/.venv`, Pillow 12.3.0, ffmpeg/ffprobe from WinGet).
- Overview: one frame every 10 s from 0 s to 3330 s plus a tail sample at 3331.28 s → **335 JPEGs**, 1280×720 (downscaled from
  1080p, aspect preserved, no upscaling). Timestamps are real source PTS read from ffmpeg `showinfo` with `-copyts`;
  max |PTS − requested| = 0.011 s; PTS strictly increasing (`tools/check_manifest.py`).
- Evidence root (git-ignored): `reference/video_review/overview/` (images + `manifest.json`),
  `reference/video_review/overview/sheets/` (38 contact sheets, 3×3, labelled `HH:MM:SS.mmm #index`).
- Images were opened and inspected visually by the model (Claude) in batches. Image analysis is performed by the model
  service, not offline.

## Identification

- **OBSERVED** 00:00:00–00:00:10 (`ov_0000`, `ov_0001`): *Splatoon* title screen with a "Wii U" badge. This is the original
  2015 Wii U Splatoon, not Splatoon 2/3. Confidence: high.

## Overview review log

### Sheets 000–001 (00:00:00 → 00:02:50) — reviewed by Claude

| Time | OBSERVED | Scope / GDD link |
|---|---|---|
| 00:00:00–00:00:10 | Title screen. | Out of scope (branding). |
| 00:00:20–00:00:30 | Full-screen two-tone ink camouflage loading pattern. | Loading screen — GDD 12.1 Loading (ours must show real stages, not a decorative wait). |
| 00:00:40 | "Choose an Inkling!" Girl/Boy character select. | Out of scope (avatar customisation). |
| 00:00:50 | Story-style dialogue box introducing four characters with weapons. | Out of scope (story). |
| 00:01:00–00:02:50 | Single-player tutorial with orange ink. Banner prompts: "Shoot ink with ZR! Pop the balloons!", "Aim with [gamepad gyro]", "Move with L stick", "Look left and right with R", "Reset the camera with Y", "Turn into a squid with ZL! You can swim in ink as a squid!", "You can even swim up walls! Your ink refills quickly while you swim!", "While swimming, press X to dash jump! You'll jump much farther than normal!" A controller diagram widget sits at lower-left the whole time. | Tutorial course itself is out of scope (GDD 03.1 forbids a blocking tutorial course). The *teaching order* supports our three short instructions (paint → glide/refill → own floor). Swim-up-walls is the reference of Paint Climb (05.2). Dash jump from swim → our "jumping keeps momentum within configured caps" (05.2). |

Camera, 00:01:00–00:02:50 (**OBSERVED**): third-person, character low in frame, slightly left of centre; small circular
reticle above the character. **INFERENCE**: shoulder-offset follow camera, consistent with GDD 04.2.
