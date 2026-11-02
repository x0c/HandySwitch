#!/usr/bin/env python3
"""Render the adopted knob as an 18 pt line-silhouette template asset.

Source anchors (design/app-icon/AppIcon-1024.png, adopted 2026-11-02):
- the knob is a full circle seen straight on; its bevelled rim becomes the
  circle outline and the face stays transparent;
- the indicator is a short line pointing to the upper right at about 45
  degrees, from about 0.3 R to 0.75 R of the knob radius; it stays a solid
  round-capped stroke;
- the dot arc, shadow and turquoise ground are dropped (owner decision).
"""

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "HandySwitch/Assets.xcassets/StatusBarIcon.imageset"

CANVAS = 18.0          # points
CENTER = (9.0, 9.0)
RADIUS = 7.4           # outer edge of the outline
STROKE = 1.6           # outline and indicator weight, matched to SF Symbols medium
ANGLE = math.radians(45)
INDICATOR = (0.28, 0.76)  # start/end along the radius, measured from the centre


def render(scale):
    sampling = 16
    unit = scale * sampling
    size = round(CANVAS * unit)
    mask = Image.new("L", (size, size))
    draw = ImageDraw.Draw(mask)
    cx, cy = (v * unit for v in CENTER)
    r = RADIUS * unit
    w = STROKE * unit

    draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=255, width=round(w))

    inner = r - w
    (a, b) = INDICATOR
    p0 = (cx + math.cos(ANGLE) * inner * a, cy - math.sin(ANGLE) * inner * a)
    p1 = (cx + math.cos(ANGLE) * inner * b, cy - math.sin(ANGLE) * inner * b)
    draw.line((p0, p1), fill=255, width=round(w))
    for x, y in (p0, p1):  # round caps
        draw.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=255)

    mask = mask.resize((round(CANVAS * scale),) * 2, Image.Resampling.LANCZOS)
    image = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    image.putalpha(mask)
    return image


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    entries = []
    for scale in (1, 2):
        name = f"StatusBarIcon@{scale}x.png"
        render(scale).save(OUTPUT / name)
        entries.append({"filename": name, "idiom": "mac", "scale": f"{scale}x"})
    (OUTPUT / "Contents.json").write_text(json.dumps({
        "images": entries,
        "info": {"author": "xcode", "version": 1},
        "properties": {"template-rendering-intent": "template"},
    }, indent=2) + "\n")
