"""Crop the same region from several extracted frames into one enlarged strip for close inspection.

Usage: python tools/crop_frames.py <window_dir> <x0> <y0> <x1> <y1> <scale> <out.jpg> <frame_index>...
Coordinates are in the extracted image's pixels (1280x720 for review frames). Frame labels keep their source PTS.
"""

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

set_dir = Path(sys.argv[1])
x0, y0, x1, y1 = (int(v) for v in sys.argv[2:6])
scale = float(sys.argv[6])
out = Path(sys.argv[7])
indices = [int(v) for v in sys.argv[8:]]
frames = {f["index"]: f for f in json.loads((set_dir / "manifest.json").read_text())["frames"]}
w, h = int((x1 - x0) * scale), int((y1 - y0) * scale)
strip = Image.new("RGB", (w * len(indices), h + 30), (20, 20, 20))
draw = ImageDraw.Draw(strip)
try:
    font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 20)
except OSError:
    font = ImageFont.load_default()
for k, idx in enumerate(indices):
    fr = frames[idx]
    img = Image.open(set_dir / fr["file"]).crop((x0, y0, x1, y1)).resize((w, h), Image.LANCZOS)
    strip.paste(img, (k * w, 30))
    draw.text((k * w + 4, 4), fr["pts"], fill=(255, 230, 0), font=font)
strip.save(out, quality=90)
print(out)
