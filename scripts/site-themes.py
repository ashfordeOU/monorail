#!/usr/bin/env python3
"""Writes site/ui/themes.js from Monorail's real themes (WorkspaceColor in Sources/Monorail/WindowControls.swift).

Run it after changing a theme so the website's theme picker matches the app."""
import json, re, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
src = (root / "Sources/Monorail/WindowControls.swift").read_text()
core = (root / "Sources/MonorailCore/AppSettings.swift").read_text()
titles = dict(re.findall(r'case \.(\w+): return "([^"]+)"', core.split("public enum Theme")[1].split("extension Theme")[0]))

def hexes(text):
    out = []
    for m in re.finditer(r"rgb\(([\d.]+),\s*([\d.]+),\s*([\d.]+)\)|Color\(white:\s*([\d.]+)\)", text):
        rgb = [float(m.group(4))] * 3 if m.group(4) else [float(x) for x in m.group(1, 2, 3)]
        out.append("#%02X%02X%02X" % tuple(round(x * 255) for x in rgb))
    return out

def cases(text):
    return {m.group(1): m.group(2) for m in re.finditer(r"case \.(\w+):\s*\n(.*?)(?=\n\s*case \.|\Z)", text, re.S)}

palettes = cases(src.split("static func palette")[1].split("static func backdrop")[0])
backdrops = cases(src.split("static func backdrop")[1].split("static var all")[0])
mono = re.search(r"case \.mono:\s*\n\s*return \[([\d., ]+)\]", src).group(1)
classic = re.search(r"classic: \[Theme\] = \[(.*?)\]", core, re.S).group(1)
seasonal = re.search(r"seasonal: \[Theme\] = \[(.*?)\]", core, re.S).group(1)
unique = re.search(r"unique: \[Theme\] = \[(.*?)\]", core, re.S).group(1)
names = lambda s: re.findall(r"\.(\w+)", s)
groups = {"Classic": names(classic), "Seasonal": [n for n in names(seasonal) if n != "seasons"], "Unique": names(unique)}

themes = {}
for key in groups["Classic"] + groups["Seasonal"] + groups["Unique"]:
    p = ["#%02X%02X%02X" % ((round(float(v) * 255),) * 3) for v in mono.split(",")] if key == "mono" else hexes(palettes[key])
    b = hexes(backdrops[key])
    assert len(p) == 9 and len(b) == 6, key
    themes[key] = {"t": titles[key], "p": p, "g": b[:3], "l": b[3:]}

(root / "site/ui/themes.js").write_text(
    "/* Generated from Sources/Monorail/WindowControls.swift (WorkspaceColor) by scripts/site-themes.py: Monorail's real themes.\n"
    "   p: the nine workspace colours, g: the overview's backdrop gradient, l: its three glows. */\n"
    "window.MONORAIL_THEMES = " + json.dumps(themes, separators=(",", ":")) + ";\n"
    "window.MONORAIL_THEME_GROUPS = " + json.dumps(groups) + ";\n")
print("%d themes" % len(themes))
