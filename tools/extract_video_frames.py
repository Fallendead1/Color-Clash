"""Reference-video frame extraction for Color Clash (GDD Section 16, START_HERE B/C).

Never modifies the source video. Uses ffmpeg input seeking with -copyts and the
showinfo filter so every saved image is labelled with its real source PTS, not a
sequence number.

Usage (from the repo root, with tools/.venv active or via its python.exe):

  python tools/extract_video_frames.py probe
  python tools/extract_video_frames.py overview --every 10
  python tools/extract_video_frames.py window --name round1 --start 120 --end 360 --fps 1
  python tools/extract_video_frames.py sheets --set overview --per-sheet 9

Outputs go to reference/video_review/<set>/ with manifest.json alongside the
images and contact sheets in reference/video_review/<set>/sheets/.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import re
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT_ROOT = ROOT / "reference" / "video_review"
VIDEO_BASENAME = "Colorclashvideoreference"
MAX_WIDTH = 1280
JPEG_QUALITY = 4  # ffmpeg -q:v scale, 2 (best) .. 31 (worst)
PTS_RE = re.compile(r"pts_time:\s*([0-9.]+)")


def find_video() -> Path:
    candidates = [p for p in ROOT.glob(VIDEO_BASENAME + ".*")]
    candidates += [p for p in (ROOT / "reference").glob(VIDEO_BASENAME + ".*")] if (ROOT / "reference").exists() else []
    candidates = [p for p in candidates if p.is_file()]
    if len(candidates) != 1:
        sys.exit(f"Expected exactly one {VIDEO_BASENAME}.* file, found: {candidates}")
    return candidates[0]


def probe(video: Path) -> dict:
    out = subprocess.run(
        [
            "ffprobe", "-v", "error", "-show_entries",
            "format=duration,size,bit_rate:stream=index,codec_type,codec_name,width,height,r_frame_rate,avg_frame_rate,nb_frames,start_time",
            "-of", "json", str(video),
        ],
        capture_output=True, text=True, check=True,
    )
    return json.loads(out.stdout)


def fmt_ts(seconds: float) -> str:
    ms = int(round(seconds * 1000))
    h, rem = divmod(ms, 3_600_000)
    m, rem = divmod(rem, 60_000)
    s, ms = divmod(rem, 1000)
    return f"{h:02d}:{m:02d}:{s:02d}.{ms:03d}"


def scale_filter() -> str:
    # Downscale to at most MAX_WIDTH, never upscale, keep aspect, even height.
    return f"scale='min({MAX_WIDTH},iw)':-2"


def extract_single(video: Path, t: float, dest: Path) -> float | None:
    cmd = [
        "ffmpeg", "-hide_banner", "-nostdin", "-loglevel", "info", "-y",
        "-ss", f"{t:.3f}", "-copyts", "-i", str(video),
        "-frames:v", "1", "-an",
        "-vf", f"showinfo,{scale_filter()}",
        "-q:v", str(JPEG_QUALITY), str(dest),
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    m = PTS_RE.search(res.stderr)
    if res.returncode != 0 or not dest.exists():
        return None
    return float(m.group(1)) if m else None


def cmd_overview(args) -> None:
    video = find_video()
    info = probe(video)
    duration = float(info["format"]["duration"])
    out_dir = OUT_ROOT / "overview"
    out_dir.mkdir(parents=True, exist_ok=True)

    times = [round(i * args.every, 3) for i in range(int(duration // args.every) + 1)]
    tail = max(0.0, duration - 1.0)
    if times[-1] < tail - 0.5:
        times.append(round(tail, 3))

    manifest_path = out_dir / "manifest.json"
    existing = {}
    if manifest_path.exists():
        for e in json.loads(manifest_path.read_text())["frames"]:
            existing[e["requested_s"]] = e

    def job(idx_t):
        idx, t = idx_t
        if t in existing and (out_dir / existing[t]["file"]).exists():
            return existing[t]
        name = f"ov_{idx:04d}_{fmt_ts(t).replace(':', '-')}.jpg"
        pts = extract_single(video, t, out_dir / name)
        return {"index": idx, "requested_s": t, "pts_s": pts, "pts": fmt_ts(pts) if pts is not None else None, "file": name}

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as ex:
        frames = list(ex.map(job, enumerate(times)))

    manifest = {
        "video": video.name,
        "probe": info,
        "mode": "overview",
        "every_s": args.every,
        "max_width": MAX_WIDTH,
        "timestamp_source": "ffmpeg showinfo pts_time with -copyts (real source PTS)",
        "frames": frames,
    }
    manifest_path.write_text(json.dumps(manifest, indent=2))
    missing = [f for f in frames if f["pts_s"] is None]
    print(f"overview: {len(frames)} frames, {len(missing)} missing PTS/failed -> {out_dir}")


def cmd_window(args) -> None:
    video = find_video()
    out_dir = OUT_ROOT / "windows" / args.name
    out_dir.mkdir(parents=True, exist_ok=True)
    for old in out_dir.glob("w_*.jpg"):
        old.unlink()
    dur = args.end - args.start
    vf = f"fps={args.fps},showinfo,{scale_filter()}" if args.fps > 0 else f"showinfo,{scale_filter()}"
    # With -copyts an output -t/-to is measured on the absolute timeline, so bound by frame count instead.
    vstream = next(s for s in probe(video)["streams"] if s["codec_type"] == "video")
    num, den = (int(x) for x in vstream["avg_frame_rate"].split("/"))
    source_fps = num / den
    frame_limit = int(dur * (args.fps if args.fps > 0 else source_fps) + 0.5)
    cmd = [
        "ffmpeg", "-hide_banner", "-nostdin", "-loglevel", "info", "-y",
        "-ss", f"{args.start:.3f}", "-copyts", "-i", str(video),
        "-frames:v", str(frame_limit), "-an", "-vf", vf,
        "-q:v", str(JPEG_QUALITY), "-fps_mode", "passthrough",
        str(out_dir / "w_%05d.jpg"),
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        sys.exit(res.stderr[-2000:])
    pts_list = [float(x) for x in PTS_RE.findall(res.stderr)]
    files = sorted(out_dir.glob("w_*.jpg"))
    frames = []
    for i, f in enumerate(files):
        pts = pts_list[i] if i < len(pts_list) else None
        new = out_dir / f"w_{i:05d}_{fmt_ts(pts).replace(':', '-') if pts is not None else 'unknown'}.jpg"
        f.rename(new)
        frames.append({"index": i, "pts_s": pts, "pts": fmt_ts(pts) if pts is not None else None, "file": new.name})
    manifest = {
        "video": video.name, "mode": "window", "name": args.name,
        "start_s": args.start, "end_s": args.end, "fps": args.fps if args.fps > 0 else "source",
        "timestamp_source": "ffmpeg showinfo pts_time with -copyts (real source PTS)",
        "frames": frames,
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2))
    print(f"window {args.name}: {len(frames)} frames ({fmt_ts(args.start)}-{fmt_ts(args.end)}) -> {out_dir}")


def load_font(size: int):
    for candidate in ("C:/Windows/Fonts/consola.ttf", "C:/Windows/Fonts/arial.ttf"):
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            continue
    return ImageFont.load_default()


def cmd_sheets(args) -> None:
    set_dir = OUT_ROOT / args.set if args.set == "overview" else OUT_ROOT / "windows" / args.set
    manifest = json.loads((set_dir / "manifest.json").read_text())
    frames = [f for f in manifest["frames"] if f["pts_s"] is not None]
    sheets_dir = set_dir / "sheets"
    sheets_dir.mkdir(exist_ok=True)
    for old in sheets_dir.glob("*.jpg"):
        old.unlink()

    cols = args.cols
    thumb_w = args.thumb_width
    font = load_font(26)
    label_h = 36
    index = []
    for s in range(0, len(frames), args.per_sheet):
        batch = frames[s : s + args.per_sheet]
        first = Image.open(set_dir / batch[0]["file"])
        thumb_h = round(first.height * thumb_w / first.width)
        rows = (len(batch) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * thumb_w, rows * (thumb_h + label_h)), (20, 20, 20))
        draw = ImageDraw.Draw(sheet)
        for i, fr in enumerate(batch):
            img = Image.open(set_dir / fr["file"]).convert("RGB")
            img.thumbnail((thumb_w, thumb_h))
            x = (i % cols) * thumb_w
            y = (i // cols) * (thumb_h + label_h)
            sheet.paste(img, (x, y + label_h))
            draw.text((x + 8, y + 4), f"{fr['pts']}  #{fr['index']}", fill=(255, 230, 0), font=font)
        name = f"sheet_{s // args.per_sheet:03d}_{batch[0]['pts'].replace(':', '-')}_to_{batch[-1]['pts'].replace(':', '-')}.jpg"
        sheet.save(sheets_dir / name, quality=85)
        index.append({"sheet": name, "first": batch[0]["pts"], "last": batch[-1]["pts"], "count": len(batch)})
    (sheets_dir / "index.json").write_text(json.dumps(index, indent=2))
    print(f"sheets: {len(index)} sheets -> {sheets_dir}")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("probe")
    o = sub.add_parser("overview")
    o.add_argument("--every", type=float, default=10.0)
    o.add_argument("--workers", type=int, default=4)
    w = sub.add_parser("window")
    w.add_argument("--name", required=True)
    w.add_argument("--start", type=float, required=True)
    w.add_argument("--end", type=float, required=True)
    w.add_argument("--fps", type=float, default=1.0, help="0 = source frame rate")
    s = sub.add_parser("sheets")
    s.add_argument("--set", default="overview")
    s.add_argument("--per-sheet", type=int, default=9)
    s.add_argument("--cols", type=int, default=3)
    s.add_argument("--thumb-width", type=int, default=640)
    args = p.parse_args()

    if args.cmd == "probe":
        print(json.dumps(probe(find_video()), indent=2))
    elif args.cmd == "overview":
        cmd_overview(args)
    elif args.cmd == "window":
        cmd_window(args)
    elif args.cmd == "sheets":
        cmd_sheets(args)


if __name__ == "__main__":
    main()
