# Monorail on a Stream Deck

Every Monorail action is a `monorail://` link, so any Stream Deck button can run one.

1. In the Stream Deck app, drag **System → Website** onto a key.
2. Set the URL to an action link and tick **Access in background**:

| Key | URL |
| --- | --- |
| Previous slide | `monorail://focus-left` |
| Next slide | `monorail://focus-right` |
| Overview | `monorail://overview` |
| Next workspace | `monorail://next-workspace` |
| Focus mode | `monorail://focus-mode` |
| Deep work | `monorail://deep-work` |
| Demo zoom | `monorail://demo-zoom` |
| Share this slide | `monorail://share-slide` |
| Show keystrokes | `monorail://show-keystrokes` |
| Workspace 1–9 | `monorail://workspace/1` … `monorail://workspace/9` |
| Open a layout | `monorail://layout/Coding` |
| Pomodoro | `monorail://pomodoro` |

`monorail actions` (with the local API on) lists every action name. The icons in this folder are free to use on your keys.

You can also use **System → Open** with `/usr/local/bin/monorail <action>`.
