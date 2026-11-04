#!/bin/bash
# Measures Monorail on this Mac for one minute: CPU, idle wake-ups, memory and energy impact.
# Leave the Mac alone while it runs (that's the "idle" the site quotes). No admin needed.
#   curl -fsSL https://raw.githubusercontent.com/ashfordeOU/monorail/main/scripts/perf-check.sh | bash
set -euo pipefail
pid="$(pgrep -x Monorail | head -n1 || true)"
[ -n "$pid" ] || { echo "Monorail isn't running. Open it, then run this again."; exit 1; }
seconds="${1:-60}"
version="$(defaults read /Applications/Monorail.app/Contents/Info CFBundleShortVersionString 2>/dev/null || echo "?")"
model="$(sysctl -n hw.model)"; cores="$(sysctl -n hw.ncpu)"
power="$(pmset -g batt | grep -q "Battery Power" && echo "on battery" || echo "on power")"
tosec() { awk -F'[:.]' '{ if (NF==3) print $1*60+$2+$3/100; else print $1*3600+$2*60+$3+$4/100 }'; }
before="$(ps -o time= -p "$pid" | tr -d ' ' | tosec)"
echo "Measuring Monorail $version for $seconds s on a $model ($cores cores), $power. Don't touch the Mac…"
# top in delta mode: the second sample covers exactly the interval.
sample="$(top -l 2 -s "$seconds" -d -pid "$pid" -stats pid,idlew,mem,power 2>/dev/null | awk -v p="$pid" '$1==p' | tail -n1)"
after="$(ps -o time= -p "$pid" | tr -d ' ' | tosec)"
cpu="$(awk -v a="$after" -v b="$before" -v s="$seconds" 'BEGIN { printf "%.2f", (a-b)/s*100 }')"
wakes="$(echo "$sample" | awk -v s="$seconds" '{ gsub(/\+/, "", $2); printf "%.1f", $2/s }')"
mem="$(echo "$sample" | awk '{ print $3 }')"
energy="$(echo "$sample" | awk '{ print $4 }')"
echo
echo "Monorail $version · $model · $power · idle ${seconds}s"
echo "  CPU:            ${cpu}% of one core"
echo "  Idle wake-ups:  ${wakes} a second"
echo "  Memory:         ${mem}"
echo "  Energy impact:  ${energy}"
