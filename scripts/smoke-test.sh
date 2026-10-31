#!/bin/sh
# End-to-end smoke test on a real Mac: opens three TextEdit windows and checks that Monorail
# tiles them, moves focus, pairs them, undoes, and moves one to another workspace.
# Needs Monorail running with Accessibility allowed and the local API on
# (Settings → Automation → Local API). Takes about 20 seconds; closes what it opens.
set -u
dir="$HOME/Library/Application Support/Monorail"
[ -f "$dir/api-port" ] || { echo "Turn on the local API in Monorail ▸ Settings ▸ Automation first" >&2; exit 69; }
port=$(cat "$dir/api-port"); token=$(cat "$dir/api-token")
get() { curl -fsS -H "Authorization: Bearer $token" "http://127.0.0.1:$port/$1"; }
post() { curl -fsS -X POST -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d "$2" "http://127.0.0.1:$port/$1"; }
textedit() { get windows | python3 -c 'import json,sys; w=[x for x in json.load(sys.stdin) if x.get("app")=="TextEdit"]; print(json.dumps(w))'; }
count() { textedit | python3 -c 'import json,sys; w=json.load(sys.stdin); print(sum(1 for x in w if '"$1"'))'; }

passed=0; failed=0
check() { if [ "$2" = "$3" ]; then echo "  ✓ $1"; passed=$((passed + 1)); else echo "  ✗ $1 (expected $3, got $2)"; failed=$((failed + 1)); fi; }

echo "==> Opening three TextEdit windows"
osascript -e 'tell application "TextEdit" to repeat 3 times' -e 'make new document' -e 'end repeat' >/dev/null
sleep 3
check "Monorail sees the windows" "$(count 'True')" 3
check "they are tiled, not floating" "$(count 'not x["floating"]')" 3

slides() { textedit | python3 -c 'import json,sys; print(len({x.get("slide") for x in json.load(sys.stdin)}))'; }
before=$(slides)

echo "==> Moving focus and pairing"
post action '{"action":"focus-left"}' >/dev/null; sleep 0.6
ids=$(textedit | python3 -c 'import json,sys; print(",".join(str(x["id"]) for x in json.load(sys.stdin)[:2]))')
post pair "{\"ids\":[$ids]}" >/dev/null; sleep 1
check "the first two share a slide" "$(textedit | python3 -c 'import json,sys; w=json.load(sys.stdin); print(int(w[0].get("slide")==w[1].get("slide")))')" 1

echo "==> Undo"
post undo '{}' >/dev/null; sleep 1
check "undo puts the slides back" "$(slides)" "$before"

echo "==> Moving a window to workspace 2"
first=$(echo "$ids" | cut -d, -f1)
post move "{\"id\":$first,\"workspace\":2}" >/dev/null; sleep 1
check "it is on workspace 2" "$(textedit | python3 -c 'import json,sys; print([x.get("workspace") for x in json.load(sys.stdin) if x["id"]=='"$first"'][0])')" 2

echo "==> Cleaning up"
osascript -e 'tell application "TextEdit" to close every document saving no' -e 'tell application "TextEdit" to quit' >/dev/null 2>&1
echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
