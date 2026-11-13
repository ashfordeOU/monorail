#!/bin/bash
# Real screenshots of Monorail on a real Mac, for the website and the press kit.
#
# Runs on a GitHub macOS runner (see .github/workflows/mac-shots.yml): installs dist/Monorail.app, allows it
# Accessibility and Screen Recording in the runner's privacy database (CI machines only; never do this on
# your own Mac), opens real apps with real content, then drives Monorail through its local API and links
# while taking screenshots, per-window pictures and a short screen recording.
#
#   scripts/mac-shots.sh OUT_DIR
set -uo pipefail
out="${1:-dist/mac-shots}"
mkdir -p "$out"
work="$(cd "$(dirname "$0")/.." && pwd)"
log() { echo "==> $*"; }

log "The machine"
sw_vers || true
csrutil status || true
system_profiler SPDisplaysDataType 2>/dev/null | grep -E "Resolution|Retina|UI Looks like" || true

log "Install Monorail in Applications"
rm -rf /Applications/Monorail.app
cp -R "$work/dist/Monorail.app" /Applications/
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Monorail.app || true

log "Allow Accessibility and Screen Recording (runner only)"
now=$(date +%s)
grant() { # service client client_type(0 bundle id, 1 path)
  for db in "/Library/Application Support/com.apple.TCC/TCC.db" "$HOME/Library/Application Support/com.apple.TCC/TCC.db"; do
    [ -f "$db" ] || continue
    sudo sqlite3 "$db" "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, indirect_object_identifier, flags, last_modified) VALUES ('$1', '$2', $3, 2, 4, 1, 'UNUSED', 0, $now);" 2>&1 | head -2 || true
  done
}
for service in kTCCServiceAccessibility kTCCServiceScreenCapture kTCCServicePostEvent; do
  grant "$service" org.ashforde.monorail 0
done
for tool in /bin/bash /bin/zsh /usr/sbin/screencapture /usr/bin/swift "$(xcrun --find swift 2>/dev/null)"; do
  [ -n "$tool" ] && grant kTCCServiceScreenCapture "$tool" 1
done
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "SELECT service, client, auth_value FROM access WHERE client LIKE '%monorail%';" || true

log "A real wallpaper, Dock on, no desktop clutter"
cat > /tmp/wall.swift <<'SWIFT'
import AppKit
let dir = URL(fileURLWithPath: "/System/Library/Desktop Pictures")
let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
print("Wallpapers:", files.map(\.lastPathComponent).sorted().joined(separator: ", "))
let wanted = ["Sequoia Sunrise", "Sequoia", "Sonoma", "Ventura", "Monterey"]
let pick = wanted.lazy.compactMap { w in files.first { $0.lastPathComponent.hasPrefix(w) && ["heic", "jpg", "png"].contains($0.pathExtension) } }.first
if let pick, let screen = NSScreen.main {
    try? NSWorkspace.shared.setDesktopImageURL(pick, for: screen, options: [:])
    print("Wallpaper:", pick.lastPathComponent)
}
SWIFT
swift /tmp/wall.swift || true
defaults write com.apple.finder CreateDesktop -bool false && killall Finder || true
defaults write com.apple.dock autohide -bool false && killall Dock || true
sleep 3

log "Real content for real apps"
docs="$HOME/Documents/Monorail demo"
mkdir -p "$docs/Launch" "$docs/Design" "$docs/Notes"
cat > "$docs/Launch plan.txt" <<'TXT'
Launch plan — Monorail 1.9.1

Goals for the week
• Ship the new website with real screens of every feature
• Record the docking film on a real Mac
• Answer every review within a day

Monday: final checks on Apple silicon and Intel
Tuesday: press kit to journalists, Product Hunt at 08:01
Wednesday: newsletter, then the long thread on how the strip works
Thursday: office hours for IT teams rolling out the .pkg
Friday: retro, then a quiet weekend

Notes
Nothing you're using ever shrinks: a new window slides in beside you.
TXT
for f in "Roadmap.md" "Press list.csv" "Release notes.md" "Icon 1024.png" "Hero.png" "Docking.mov"; do touch "$docs/Launch/$f"; done
for f in "Panel.sketch" "Dashboard.fig" "Colours.json" "Themes.pdf"; do touch "$docs/Design/$f"; done
cp "$work/assets/icon.png" "$docs/Design/Monorail icon.png"
cat > /tmp/term.command <<CMD
#!/bin/zsh
clear
cd "$work"
printf '\e]0;monorail — git\a'
git log --oneline --graph --decorate -14 --color=always
echo
swift --version 2>/dev/null | head -1
exec zsh -i
CMD
chmod +x /tmp/term.command

log "Settings: no usage counts, no update checks, welcome done, local API on"
mkdir -p "$HOME/Library/Application Support/Monorail"
cat > "$HOME/Library/Application Support/Monorail/settings.json" <<'JSON'
{"shareUsageStats":false,"checkForUpdates":false,"usageNoticeShown":true,"hasCompletedOnboarding":true,"localAPI":true}
JSON

log "Open the apps"
open -a Safari "https://monorail.ashforde.org/changelog/"; sleep 4
open -a Finder "$docs"; sleep 2
open -a Terminal /tmp/term.command; sleep 3
open -a TextEdit "$docs/Launch plan.txt"; sleep 2
open -a Preview "$work/assets/launch/v17/07-themes.png"; sleep 2
open -a Calendar; sleep 4
screencapture -x "$out/00-before-monorail.png"

log "Start Monorail"
open /Applications/Monorail.app
for i in $(seq 1 30); do [ -f "$HOME/Library/Application Support/Monorail/api-port" ] && break; sleep 1; done
sleep 6
dir="$HOME/Library/Application Support/Monorail"
if [ ! -f "$dir/api-port" ]; then echo "The local API didn't start"; ls -la "$dir"; fi
port=$(cat "$dir/api-port" 2>/dev/null); token=$(cat "$dir/api-token" 2>/dev/null)
api() { curl -fsS -m 5 -X POST -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d "{\"action\":\"$1\"}" "http://127.0.0.1:$port/action" >/dev/null 2>&1 || echo "  (action $1 failed)"; }
log "What Monorail sees"
curl -fsS -m 5 -H "Authorization: Bearer $token" "http://127.0.0.1:$port/windows" | python3 -m json.tool | head -60 || echo "no window list"

shot() { sleep "${2:-1.6}"; screencapture -x "$out/$1.png"; echo "  $1"; }
log "The strip"
shot 01-strip 2
api focus-left; shot 02-strip-left
api focus-left; shot 03-strip-left2
api focus-right; api focus-right; api focus-right; shot 04-strip-right
api full-width; shot 05-full-width; api full-width; sleep 1

log "The overview"
api overview; shot 06-overview 2.2; api overview; sleep 1.5

log "The menu bar panel"
open -g monorail://panel; shot 07-panel 2.2
open -g monorail://panel/battery; shot 08-panel-battery 2.0
open -g monorail://panel; sleep 1

log "The Dashboard"
for page in time ai-usage switches apps battery; do open -g "monorail://dashboard/$page"; shot "09-dashboard-$page" 2.5; done
osascript -e 'tell application "System Events" to keystroke "w" using command down' >/dev/null 2>&1 || true
sleep 1

log "The command palette"
open -g monorail://palette; shot 10-palette 1.6
osascript -e 'tell application "System Events" to key code 53' >/dev/null 2>&1 || true

log "Each window on its own (with its shadow)"
cat > /tmp/windows.swift <<'SWIFT'
import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for w in list where (w[kCGWindowLayer as String] as? Int) == 0 {
    let owner = w[kCGWindowOwnerName as String] as? String ?? "?"
    let id = w[kCGWindowNumber as String] as? Int ?? 0
    let b = w[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
    if (b["Width"] ?? 0) > 200 { print("\(id)\t\(owner)") }
}
SWIFT
swift /tmp/windows.swift 2>/dev/null > /tmp/windows.txt || true
cat /tmp/windows.txt
mkdir -p "$out/windows"
while IFS=$'\t' read -r id owner; do
  [ -n "$id" ] && screencapture -x -l "$id" "$out/windows/${owner// /-}-$id.png"
done < /tmp/windows.txt

log "A short recording of the strip sliding"
( sleep 1.5; for a in focus-left focus-left focus-left focus-right focus-right focus-right focus-right; do api "$a"; sleep 1.4; done ) &
screencapture -x -v -V 13 "$out/strip.mov" 2>&1 | tail -2 || echo "recording isn't available here"
wait

log "Done"
ls -la "$out" "$out/windows"
