# AI agents and Monorail

Monorail can be driven by AI agents as well as by you: desktop assistants, coding agents, bots and
computer-use agents. They arrange windows with exact commands instead of screenshots and clicks, so
it's faster, cheaper and easy to undo.

## 1. Turn on the local API

Open **Settings → Automation** and turn on **Local API**. It listens only on this Mac, and every
request needs a token that only your user account can read.

## 2. Connect your agent

**MCP clients** (Claude Desktop, Cursor, Hermes Agent, OpenClaw and any other client that speaks the
Model Context Protocol): click **Copy MCP Server Config** and add it to the client's MCP servers. It
runs:

```json
"monorail": { "command": "/Applications/Monorail.app/Contents/MacOS/Monorail", "args": ["--mcp"] }
```

**Agents that load skills** (OpenClaw, Hermes Agent, Claude and others that read `SKILL.md` files):
click **Save Agent Skill…** and choose the agent's skills folder. The skill is also at
[monorail.ashforde.org/agents/SKILL.md](https://monorail.ashforde.org/agents/SKILL.md).

**Any other agent or bot that can run commands** (computer-use agents, bots built on Grok, ChatGPT
or Gemini, scripts): click **Copy Agent Instructions** and paste them into its instructions, or point
it at the skill's address above. It then uses the `monorail` command:

```sh
/Applications/Monorail.app/Contents/Resources/monorail say "Slack and Mail side by side on 2"
/Applications/Monorail.app/Contents/Resources/monorail windows
```

## 3. Ask

“Put my editor and browser side by side.” “Move every chat app to workspace 3.” “Keep the Mac awake
for an hour while the build runs.”

## What agents can do

| | Command line | HTTP (local API) | MCP tool |
| --- | --- | --- | --- |
| Do what a sentence says | `monorail say "…"` | `POST /say` | `say` |
| Read the state | `monorail state` | `GET /state` | `get_state` |
| List windows | `monorail windows` | `GET /windows` | `list_windows` |
| Run any action | `monorail focus-left` | `POST /action` | `perform_action` |
| Put windows together | | `POST /pair` | `pair_windows` |
| Move a window to a workspace | | `POST /move` | `move_window` |
| Apply a saved layout | `monorail layout Coding` | `POST /layout` | `apply_layout` |
| Keep the Mac awake | `monorail awake 60` | | `stay_awake` |
| Battery and the apps using it | `monorail battery` | `GET /battery` | `battery_status` |
| Hide, pause or quit a hungry app | | `POST /battery` | `save_battery` |

Every action is listed in [the actions reference](ACTIONS.md).

## Safety

- The API only listens on this Mac, and every request needs your token.
- Monorail asks you before an agent closes a window.
- Anything an agent does can be undone with ⌃⌥Z or `monorail undo`.
- Turning off **Local API** cuts every agent off at once.

## The other way round: Monorail's own assistant

When Monorail doesn't understand something you type in the command palette, it can ask a model of
your choice to turn it into commands, and shows them to you before doing anything. Pick the provider
in **Settings → Smart → Assistant**: Anthropic (Claude), OpenAI, Google Gemini, xAI (Grok),
OpenRouter, a model in Ollama on this Mac (nothing leaves the Mac), or any OpenAI-compatible server
such as LM Studio. Keys are kept in your Keychain.
