#!/usr/bin/env python3
"""Render the approved rotary-control silhouette as an 18 pt template asset."""

import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "HandySwitch/Assets.xcassets/StatusBarIcon.imageset"


def render(scale):
    # Source anchors: circular body, upper-right indicator, detached 60-degree arc.
    # The background is removed; the indicator becomes a transparent hole.
    sampling = 12
    unit = scale * sampling
    mask = Image.new("L", (18 * unit, 18 * unit))
    draw = ImageDraw.Draw(mask)

    def bounds(cx, cy, radius):
        return tuple(round(v * unit) for v in
                     (cx - radius, cy - radius, cx + radius, cy + radius))

    draw.ellipse(bounds(9, 9.3, 6), fill=255)
    draw.ellipse(bounds(11.9, 6.4, 1.3), fill=0)
    draw.arc(bounds(9, 9.3, 8.65), 270, 330,
             fill=255, width=round(1.3 * unit))
    mask = mask.resize((18 * scale, 18 * scale), Image.Resampling.LANCZOS)
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
