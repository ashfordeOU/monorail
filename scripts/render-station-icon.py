#!/usr/bin/env python3
"""Draws Station's app icon (assets/station/icon.png, 1024 px): Apple's icon grid, a deep navy
gradient, and three rings in Station's colours (charge green, time blue, drain yellow). Run: python3 scripts/render-station-icon.py"""
from PIL import Image, ImageDraw, ImageFilter
import os

S = 4096  # draw large, then scale down for smooth edges
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

# The rounded square on Apple's macOS icon grid: 824 of 1024, with a soft shadow.
inset, radius = int(S * 100 / 1024), int(S * 185 / 1024)
box = (inset, inset, S - inset, S - inset)
shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(shadow).rounded_rectangle((box[0], box[1] + S // 80, box[2], box[3] + S // 80), radius, fill=(0, 0, 0, 90))
img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(S // 60)))

grad = Image.new("RGBA", (S, S))
top, bottom = (38, 62, 120), (10, 16, 42)
gd = ImageDraw.Draw(grad)
for y in range(S):
    t = y / S
    gd.line([(0, y), (S, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle(box, radius, fill=255)
img.paste(grad, (0, 0), mask)

# A gentle highlight across the top.
hl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(hl).ellipse((box[0] - S // 4, box[1] - S // 2, box[2] + S // 4, box[1] + S // 3), fill=(255, 255, 255, 34))
img = Image.alpha_composite(img, Image.composite(hl.filter(ImageFilter.GaussianBlur(S // 30)), Image.new("RGBA", (S, S)), mask))

# Three rings, outside in, each a track and an arc, like Station's battery rings.
d = ImageDraw.Draw(img)
cx = cy = S // 2
width = int(S * 62 / 1024)
gap = int(S * 24 / 1024)
r0 = int(S * 300 / 1024)
for i, (share, col) in enumerate([(0.78, (52, 199, 89)), (0.64, (90, 200, 250)), (0.86, (255, 214, 10))]):
    alpha = 255
    r = r0 - i * (width + gap)
    bbox = (cx - r, cy - r, cx + r, cy + r)
    d.arc(bbox, 0, 360, fill=col + (34,), width=width)
    end = -90 + 360 * share
    d.arc(bbox, -90, end, fill=col + (alpha,), width=width)
    # Round ends.
    import math
    for ang in (-90, end):
        a = math.radians(ang)
        rr = r - width / 2
        x, y = cx + rr * math.cos(a), cy + rr * math.sin(a)
        d.ellipse((x - width / 2, y - width / 2, x + width / 2, y + width / 2), fill=col + (alpha,))

out = os.path.join(os.path.dirname(__file__), "..", "assets", "station", "icon.png")
img.resize((1024, 1024), Image.LANCZOS).save(out)
print("wrote", os.path.normpath(out))
