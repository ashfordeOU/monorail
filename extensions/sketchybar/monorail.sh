#!/bin/sh
# SketchyBar plug-in for Monorail by Ashforde®.
# In sketchybarrc:
#   sketchybar --add event monorail_changed org.ashforde.monorail.changed \
#              --add item monorail left --set monorail script="$PLUGIN_DIR/monorail.sh" \
#              --subscribe monorail monorail_changed
# Needs Settings → Automation → Publish state turned on.
STATE="$HOME/Library/Application Support/Monorail/state.json"
[ -f "$STATE" ] || exit 0
WS=$(/usr/bin/plutil -extract workspace raw -o - "$STATE" 2>/dev/null)
NAME=$(/usr/bin/plutil -extract workspaceName raw -o - "$STATE" 2>/dev/null)
SLIDE=$(/usr/bin/plutil -extract slide raw -o - "$STATE" 2>/dev/null)
SLIDES=$(/usr/bin/plutil -extract slides raw -o - "$STATE" 2>/dev/null)
sketchybar --set monorail label="$WS · $NAME  $SLIDE/$SLIDES"
