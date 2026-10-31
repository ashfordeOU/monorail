#!/bin/bash
# Measures Monorail's own CPU, energy, wake-ups and memory, and nothing else on the Mac.
#
#   bash measure-performance.sh            # about 3 minutes: idle, then while you use it
#   bash measure-performance.sh --quick    # about 1 minute
#   sudo bash measure-performance.sh       # adds macOS's own per-app energy figures (powermetrics)
#
# Everything is read for the Monorail process only (by its PID). Nothing is sent anywhere:
# the report is printed and saved to ~/Desktop/monorail-performance.txt for you to share.
# No window titles, app names or personal data are collected.
set -u

QUICK=0
[ "${1:-}" = "--quick" ] && QUICK=1
IDLE=$([ $QUICK = 1 ] && echo 30 || echo 90)
ACTIVE=$([ $QUICK = 1 ] && echo 30 || echo 60)
OUT="$HOME/Desktop/monorail-performance.txt"

PID=$(pgrep -x Monorail | head -n1)
if [ -z "$PID" ]; then
    echo "Monorail isn't running. Open it, then run this again." >&2
    exit 1
fi

say() { printf '%s\n' "$*" | tee -a "$OUT"; }
: > "$OUT"

# CPU seconds the process has used so far (user + system), from ps (format [[dd-]hh:]mm:ss.ss).
cpu_seconds() {
    ps -o time= -p "$PID" | awk '{
        n = split($1, d, "-"); days = 0; t = $1
        if (n == 2) { days = d[1]; t = d[2] }
        m = split(t, p, ":"); s = 0
        for (i = 1; i <= m; i++) s = s * 60 + p[i]
        printf "%.3f", days * 86400 + s }'
}

# Samples top for this PID only: CPU %, idle wake-ups, Apple's energy impact and memory.
sample() { # seconds label
    local seconds=$1 label=$2
    local before after
    before=$(cpu_seconds)
    top -l $((seconds / 2 + 1)) -s 2 -pid "$PID" -stats pid,cpu,idlew,power,mem,threads 2>/dev/null \
        | awk -v pid="$PID" '$1 == pid { n++; if (n > 1) { cpu += $2; w += $3; p += $4; mem = $5; th = $6; k++ } }
              END { if (k) printf "%.2f %.1f %.2f %s %s\n", cpu / k, w / k, p / k, mem, th; else print "0 0 0 ? ?" }' \
        > /tmp/monorail-sample.$$
    after=$(cpu_seconds)
    read -r cpu wakeups power mem threads < /tmp/monorail-sample.$$
    rm -f /tmp/monorail-sample.$$
    local used
    used=$(awk -v a="$after" -v b="$before" -v s="$seconds" 'BEGIN { printf "%.3f s (%.2f%% of one core)", a - b, (a - b) / s * 100 }')
    say ""
    say "== $label ($seconds s) =="
    say "CPU time used:        $used"
    say "Average CPU (top):    $cpu %"
    say "Idle wake-ups:        $wakeups per second"
    say "Energy impact (top):  $power"
    say "Memory:               $mem"
    say "Threads:              $threads"
}

APP=$(ps -o comm= -p "$PID")
VERSION=$(defaults read "$(dirname "$(dirname "$APP")")/Info" CFBundleShortVersionString 2>/dev/null || echo "?")
say "Monorail performance report · $(date '+%Y-%m-%d %H:%M')"
say "Monorail $VERSION (pid $PID) · macOS $(sw_vers -productVersion) · $(sysctl -n hw.model) · $(sysctl -n hw.ncpu) cores"
say "Power: $(pmset -g batt | head -n1 | sed "s/Now drawing from //; s/'//g")$(pmset -g | grep -q 'lowpowermode *1' && echo ' · Low Power Mode on')"
say "Running for $(ps -o etime= -p "$PID" | tr -d ' ') · CPU used since launch: $(cpu_seconds) s · $(ps -o rss= -p "$PID" | awk '{printf "%.0f MB", $1/1024}') in memory"

echo ""
echo "Step 1 of 2: leave the Mac alone for $IDLE seconds (don't touch the mouse or keyboard)…"
sample "$IDLE" "Idle"

echo ""
echo "Step 2 of 2: now use Monorail for $ACTIVE seconds: switch slides, open the overview, move between workspaces…"
sample "$ACTIVE" "In use"

if [ "$(id -u)" = 0 ] && command -v powermetrics > /dev/null; then
    echo ""
    echo "Reading macOS's per-app energy for 20 more seconds…"
    say ""
    say "== powermetrics (macOS's own figures, Monorail only) =="
    powermetrics --samplers tasks --show-process-energy -i 5000 -n 4 2>/dev/null \
        | awk -v pid="$PID" '$0 ~ "^Name" && !h { print; h = 1 } $2 == pid { print }' | tee -a "$OUT"
fi

say ""
say "Saved to $OUT. Paste it to the Monorail developer. It contains no window titles or personal data."
