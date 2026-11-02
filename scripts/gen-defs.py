#!/usr/bin/env python3
"""Generates the shared definitions for the other implementations from spec/ (docs/PLATFORMS.md):

  core-ts/src/generated/actions.ts, settings.ts       for GNOME and KDE (TypeScript)
  windows/Monorail.Shared/Generated/Actions.cs, Settings.cs   for Windows (C#)

spec/ itself is generated from the Swift sources by scripts/gen-docs.py, so every platform uses
the same action names, titles, setting keys and defaults. `--check` fails if any file is stale.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HEADER = "Generated from spec/{src} by scripts/gen-defs.py. Don't edit by hand."


def load(name):
    with open(os.path.join(ROOT, "spec", name), encoding="utf-8") as f:
        return json.load(f)


def pascal(name):
    parts = re.split(r"[-_ ]", name)
    out = "".join(p[:1].upper() + p[1:] for p in parts if p)
    return ("_" + out) if out[:1].isdigit() else out


def literal(swift_type, default):
    """The default as a plain value, when it's a literal of a simple type (else None)."""
    if default is None:
        return ...
    d = default.strip()
    if swift_type == "Bool" and d in ("true", "false"):
        return d == "true"
    if swift_type in ("Int", "Int?") and re.fullmatch(r"-?\d+", d):
        return int(d)
    if swift_type == "Int?" and d == "nil":
        return None
    if swift_type == "Double" and re.fullmatch(r"-?\d+(\.\d+)?(e-?\d+)?", d):
        return float(d)
    if swift_type == "String" and re.fullmatch(r'"([^"\\]|\\.)*"', d):
        return json.loads(d)
    return ...  # not a simple literal


TS_TYPES = {"Bool": "boolean", "Int": "number", "Int?": "number | null", "Double": "number", "String": "string",
            "[String]": "string[]", "[Int]": "number[]", "[String: String]": "Record<string, string>",
            "[String: Double]": "Record<string, number>"}
CS_TYPES = {"Bool": "bool", "Int": "int", "Int?": "int?", "Double": "double", "String": "string"}


def ts_actions(spec):
    lines = [f"// {HEADER.format(src='actions.json')}", "",
             "export interface ActionInfo {", "  readonly name: string;", "  readonly title: string;",
             "  /** Has a shortcut out of the box. */", "  readonly defaultKey: boolean;",
             "  /** One of a numbered family (workspace-1…9 and so on). */", "  readonly numbered: boolean;", "}", "",
             "export const ACTIONS = ["]
    for a in spec["actions"]:
        lines.append(f"  {{ name: {json.dumps(a['name'])}, title: {json.dumps(a['title'], ensure_ascii=False)}, "
                     f"defaultKey: {str(a['defaultKey']).lower()}, numbered: {str(a['numbered']).lower()} }},")
    lines += ["] as const satisfies readonly ActionInfo[];", "",
              "export type ActionName = (typeof ACTIONS)[number]['name'];", ""]
    return "\n".join(lines)


def ts_settings(spec):
    lines = [f"// {HEADER.format(src='settings.json')}", "",
             "/** Every setting, with its type where it's a plain value (structured ones are JSON objects). */",
             "export interface Settings {"]
    defaults = []
    for s in spec["settings"]:
        if s["about"]:
            lines.append(f"  /** {s['about'].replace('*/', '* /')} */")
        lines.append(f"  {s['key']}: {TS_TYPES.get(s['type'], 'unknown')};")
        value = literal(s["type"], s["default"])
        if value is not ...:
            defaults.append(f"  {s['key']}: {json.dumps(value, ensure_ascii=False)},")
    lines += ["}", "", "/** Defaults of the plain settings (the rest start empty or come from the platform). */",
              "export const DEFAULTS: Partial<Settings> = {", *defaults, "};", "",
              f"export const SETTING_KEYS = {json.dumps([s['key'] for s in spec['settings']])} as const;", ""]
    return "\n".join(lines)


def cs_string(s):
    return json.dumps(s, ensure_ascii=False)


def cs_actions(spec):
    lines = [f"// {HEADER.format(src='actions.json')}", "#nullable enable", "namespace Monorail.Shared;", "",
             "public sealed record ActionInfo(string Name, string Title, bool DefaultKey, bool Numbered);", "",
             "/// <summary>Every Monorail action, by its shared name.</summary>", "public static class Actions", "{"]
    for a in spec["actions"]:
        lines.append(f"    public const string {pascal(a['name'])} = {cs_string(a['name'])};")
    lines += ["", "    public static readonly ActionInfo[] All =", "    {"]
    for a in spec["actions"]:
        lines.append(f"        new({cs_string(a['name'])}, {cs_string(a['title'])}, "
                     f"{str(a['defaultKey']).lower()}, {str(a['numbered']).lower()}),")
    lines += ["    };", "}", ""]
    return "\n".join(lines)


def cs_value(swift_type, value):
    if value is None:
        return "null"
    if swift_type == "Bool":
        return "true" if value else "false"
    if swift_type == "Double":
        text = repr(float(value))
        return text if "." in text or "e" in text else text + ".0"
    if swift_type == "String":
        return cs_string(value)
    return str(value)


def cs_settings(spec):
    lines = [f"// {HEADER.format(src='settings.json')}", "#nullable enable", "namespace Monorail.Shared;", "",
             "/// <summary>Every setting's key, as saved in settings.json.</summary>", "public static class SettingKeys",
             "{"]
    for s in spec["settings"]:
        lines.append(f"    public const string {pascal(s['key'])} = {cs_string(s['key'])};")
    lines += ["}", "", "/// <summary>Defaults of the plain settings.</summary>", "public static class SettingDefaults", "{"]
    for s in spec["settings"]:
        value = literal(s["type"], s["default"])
        if value is ... or s["type"] not in CS_TYPES:
            continue
        if s["about"]:
            lines.append(f"    /// <summary>{s['about'].replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')}</summary>")
        kind = CS_TYPES[s["type"]]
        keyword = "const" if value is not None else "static readonly"
        lines.append(f"    public {keyword} {kind} {pascal(s['key'])} = {cs_value(s['type'], value)};")
    lines += ["}", ""]
    return "\n".join(lines)


def outputs():
    actions, settings = load("actions.json"), load("settings.json")
    return {
        "core-ts/src/generated/actions.ts": ts_actions(actions),
        "core-ts/src/generated/settings.ts": ts_settings(settings),
        "windows/Monorail.Shared/Generated/Actions.cs": cs_actions(actions),
        "windows/Monorail.Shared/Generated/Settings.cs": cs_settings(settings),
    }


def main():
    check = "--check" in sys.argv
    stale = []
    for rel, text in outputs().items():
        path = os.path.join(ROOT, rel)
        current = open(path, encoding="utf-8").read() if os.path.exists(path) else None
        if current == text:
            continue
        if check:
            stale.append(rel)
        else:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as f:
                f.write(text)
            print(f"Wrote {rel}")
    if stale:
        print("Out of date (run python3 scripts/gen-defs.py):", ", ".join(stale))
        sys.exit(1)


if __name__ == "__main__":
    main()
