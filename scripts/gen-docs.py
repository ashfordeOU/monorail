#!/usr/bin/env python3
"""Writes docs/ACTIONS.md (every action) and docs/SETTINGS.md (every setting) from the source,
so the reference can never fall behind. `--check` fails if the files are out of date (CI runs this)."""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        return f.read()


def actions():
    src = read("Sources/MonorailCore/Action.swift")
    enum = src[src.index("public enum Action"):]
    cases = []
    for name, raw in re.findall(r"^    case (\w+)(?: = \"([^\"]+)\")?\s*$", enum, re.M):
        cases.append((name, raw or name))
    titles = dict(re.findall(r'case \.(\w+): return "([^"]+)"', enum))
    unbound = set(re.findall(r"\.(\w+)", enum[enum.index("unboundByDefault"):enum.index("]", enum.index("unboundByDefault"))]))
    lines = ["# Every Monorail action", "",
             "Generated from `Sources/MonorailCore/Action.swift` by `scripts/gen-docs.py`. Don't edit by hand.", "",
             "Run any action from the command palette (⌃⌥/), with `open -g monorail://<name>`, `monorail <name>`,",
             "the local API (`POST /action`), MCP (`perform_action`), AppleScript or a script (`monorail.perform`).",
             "Give any of them a key in **Settings → Shortcuts**.", "",
             f"{len(cases)} actions.", "",
             "| Action | Name | Default key |", "| --- | --- | --- |"]
    for name, raw in cases:
        title = titles.get(name, name)
        key = "none (add one in Settings)" if name in unbound else "yes (see Settings → Shortcuts)"
        lines.append(f"| {title} | `{raw}` | {key} |")
    return "\n".join(lines) + "\n"


def settings():
    src = read("Sources/MonorailCore/AppSettings.swift")
    body = src[src.index("public struct AppSettings"):]
    body = body[:body.index("enum CodingKeys")]
    rows, doc = [], []
    for line in body.splitlines():
        line = line.strip()
        if line.startswith("///"):
            doc.append(line[3:].strip())
            continue
        m = re.match(r"public var (\w+)(?:: ([^=]+))?(?: = (.+))?$", line)
        if m and "{" not in line:
            name, kind, default = m.group(1), (m.group(2) or "").strip(), (m.group(3) or "").strip()
            text = " ".join(doc).replace("|", "\\|")
            shown = default.replace("|", "\\|")
            rows.append(f"| `{name}` | {text} | `{shown}` |" if default else f"| `{name}` | {text} | |")
        doc = []
    lines = ["# Every Monorail setting", "",
             "Generated from `Sources/MonorailCore/AppSettings.swift` by `scripts/gen-docs.py`. Don't edit by hand.", "",
             "Settings live in `~/Library/Application Support/Monorail/settings.json`. Every one can be changed in the",
             "Settings window; organisations can enforce any of them with a configuration profile (MDM) using these keys.", "",
             f"{len(rows)} settings.", "",
             "| Key | What it does | Default |", "| --- | --- | --- |"] + rows
    return "\n".join(lines) + "\n"


def main():
    outputs = {"docs/ACTIONS.md": actions(), "docs/SETTINGS.md": settings()}
    stale = []
    for path, text in outputs.items():
        full = os.path.join(ROOT, path)
        current = open(full, encoding="utf-8").read() if os.path.exists(full) else None
        if "--check" in sys.argv:
            if current != text:
                stale.append(path)
        else:
            os.makedirs(os.path.dirname(full), exist_ok=True)
            with open(full, "w", encoding="utf-8") as f:
                f.write(text)
            print("Wrote", path)
    if stale:
        print("Out of date (run python3 scripts/gen-docs.py):", ", ".join(stale))
        sys.exit(1)


main()
