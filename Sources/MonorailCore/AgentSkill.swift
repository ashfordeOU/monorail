/// The Agent Skill that teaches AI agents (OpenClaw, Hermes Agent, Claude, computer-use agents and
/// others that read SKILL.md files) to drive Monorail. Kept identical to
/// extensions/agent-skill/monorail/SKILL.md (a test checks).
public enum AgentSkill {
    public static let markdown = #"""
---
name: monorail
description: Arrange, focus, move and pair windows on a Mac running Monorail, the scrolling window manager. Use when asked to put apps side by side, switch or tidy workspaces, apply a saved layout, find a window, keep the Mac awake, or read what's on screen.
---

# Monorail

Monorail keeps every window on a horizontal strip of slides. A slide holds one or more windows,
and each display has numbered workspaces. Prefer Monorail's commands over clicking and dragging
windows: they're exact, they don't need screenshots, and the person can undo them.

## Before you start

Monorail must be running, with **Settings → Automation → Local API** turned on (it listens only on
this Mac). If a command says the local API is off, ask the person to turn it on.

The command-line tool is inside the app:

```sh
M=/Applications/Monorail.app/Contents/Resources/monorail
```

(If `monorail` is already on the PATH, use that.)

## The easiest way: say it

Describe the result in one sentence. Monorail understands it on the Mac:

```sh
$M say "Slack and Mail side by side on 2"
$M say "Safari two thirds"
$M say "move Xcode to 3"
$M say "focus mode on"
```

## Read the state first

All of these print JSON:

```sh
$M state        # workspace, slide and focused window
$M windows      # every window: id, app, title, workspace, slide
$M workspaces   # workspaces with their names and slides
$M layouts      # saved layouts; also: pairs, templates, snapshots
$M actions      # every action name
```

## Run an action

```sh
$M focus-right          # focus-left, focus-up, focus-down, focus-first, focus-last
$M move-left            # move the focused window
$M workspace-2          # go to workspace 2; move-to-workspace-2 moves the window there
$M cycle-width          # full-width, center, regroup, overview, undo, redo
$M layout "Coding"      # apply a saved layout; also: pair, template, snapshot, focus-app
$M awake 60             # keep the Mac awake for 60 minutes; awake off ends it
```

## Battery

```sh
$M battery     # charge, watts, time left, health, and the apps and AI agents using the most power
```

To save battery, POST `/battery` with `{"app": "Google Chrome", "do": "hide"}` (also `pause`, `resume`,
or `quit`, which the person confirms). Pausing freezes an app until it's opened or the Mac is plugged in.

## Over HTTP or MCP

The same things are at `http://127.0.0.1:<port>`; the port is in
`~/Library/Application Support/Monorail/api-port` and every request needs
`Authorization: Bearer <token>` from `~/Library/Application Support/Monorail/api-token`.

```sh
curl -H "Authorization: Bearer $(cat ~/Library/Application\ Support/Monorail/api-token)" \
     "http://127.0.0.1:$(cat ~/Library/Application\ Support/Monorail/api-port)/windows"
```

POST JSON to `/say` (`{"text": "..."}`), `/action` (`{"action": "focus-left"}`), `/focus` (`{"id": 12}`),
`/move` (`{"id": 12, "workspace": 2}`) or `/pair` (`{"ids": [12, 15], "layout": "columns"}`).

MCP clients can run `/Applications/Monorail.app/Contents/MacOS/Monorail --mcp` instead; its tools
include `get_state`, `list_windows`, `say`, `perform_action`, `pair_windows`, `move_window`,
`apply_layout`, `battery_status` and `save_battery`.

## Be careful

- Read `windows` before acting on ids; ids change when windows close.
- Don't close windows unless the person asked: Monorail asks them to confirm when an agent closes one.
- After a change you're unsure about, `$M undo` puts it back.
"""#
}
