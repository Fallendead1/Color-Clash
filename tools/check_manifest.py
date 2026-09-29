"""Sanity-check a video_review manifest: PTS present, chronology, seek accuracy, image size."""

import json
import sys
from pathlib import Path

from PIL import Image

set_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "reference/video_review/overview")
m = json.loads((set_dir / "manifest.json").read_text())
frames = m["frames"]
print("frames", len(frames), "first", frames[0]["pts"], "last", frames[-1]["pts"])
missing = [x for x in frames if x["pts_s"] is None]
print("missing pts", len(missing))
if "requested_s" in frames[0]:
    drift = [abs(x["pts_s"] - x["requested_s"]) for x in frames if x["pts_s"] is not None]
    print("max |pts - requested| = %.4f s" % max(drift))
ok = all(frames[i]["pts_s"] < frames[i + 1]["pts_s"] for i in range(len(frames) - 1))
print("strictly increasing pts:", ok)
for probe_idx in (0, len(frames) // 2, len(frames) - 1):
    im = Image.open(set_dir / frames[probe_idx]["file"])
    print("frame", probe_idx, frames[probe_idx]["pts"], "size", im.size)
