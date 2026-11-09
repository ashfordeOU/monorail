# Submissions: Homebrew, Installomator, the Mac App Store, and a real-Mac test

Everything here is ready except the steps only the owner can take: pull requests to other projects
come from the owner's GitHub account, and the App Store needs the owner's Apple account. Releases
from 1.7.16 on are signed with Ashforde OU's Developer ID (Team `D69G45342Y`) and notarised, which
all three require.

## 1. A 10-minute test on a real Mac (do this first)

GitHub's Mac already checks every release (`.github/workflows/release-smoke.yml`): the download is
notarised and accepted by Gatekeeper, the DMG and pkg install, the app opens and quits cleanly, Evening
Mode warms the display and restores it, Monorail answers Keeper on the shared channel, and Installomator
installs it. What only a person can check, because it needs Accessibility (which no program can
grant itself) or the lid:

Install the newest release, then:

1. **Install:** open the DMG and drag Monorail to Applications. It should open with **no** warning.
   Allow Accessibility when asked (after an upgrade from 1.7.15 or earlier: remove Monorail from
   Privacy & Security → Accessibility with **–**, then open it again).
2. **First run:** in the welcome tour, try **Simple**, then **Power user**: Settings shows 6 or all
   sections (switch at the bottom of the Settings sidebar).
3. **Windows:** open three windows of different apps: they slide in side by side. Use the slider bar,
   ⌃⌥← ⌃⌥→, and the overview (⌃⌥O).
4. **Evening Mode:** menu bar → Evening Mode → Turn On Now, then drag the slider in Settings →
   Evening Mode: every display gets warmer as you drag. Take a screenshot: it has normal colours.
   Quit Monorail: colours go back to normal.
5. **Stay Awake, lid closed** (plugged in, no external display): turn on **Stay Awake with the Lid
   Closed**, start Stay Awake (one password prompt), close the lid for a minute, open it: the Mac kept
   running. End Stay Awake: no password, and `pmset -g` shows `SleepDisabled 0` within seconds.
6. **With Keeper running too:** start Stay Awake from Monorail: Keeper takes it (Monorail says so).
7. **Shared engine** (2 minutes): quit Monorail, run
   `/Applications/Monorail.app/Contents/MacOS/Monorail --shared-engine` in Terminal, click another
   app, open a window, close one, minimise one, then Ctrl-C. Send the output.

Anything odd: menu bar → **Report a Problem…** (or tell the session what you saw).

## 2. Homebrew (the main cask list)

Once in, people install with `brew install --cask monorail`, no tap needed, and Homebrew keeps it
updated. Our own tap keeps working either way.

**Not yet (checked 3 November 2026: 0 stars, 0 forks, 0 watchers).** Submit when the repository passes
about 225 stars (or 90 forks or watchers), e.g. after the Product Hunt launch; an early submission is
closed. Until then `brew tap ashfordeOU/monorail https://github.com/ashfordeOU/monorail && brew install --cask monorail` works from our own tap.

**Check first:** Homebrew only takes apps with some following. For a project hosted on GitHub that
means roughly 30 forks, 30 watchers or 75 stars, and about three times that when the developer
submits it themselves. Check the repository's numbers on its GitHub page; if they're lower, wait,
because a submission that's too early is closed. Also run `brew search monorail` to make sure the
name is free.

**Submit** (on the Mac, with the GitHub CLI signed in as ashfordeOU):
```bash
brew tap homebrew/cask --force
cd "$(brew --repository homebrew/cask)"
git checkout -b monorail
mkdir -p Casks/m
curl -fsSL https://raw.githubusercontent.com/ashfordeOU/monorail/main/Casks/monorail.rb -o Casks/m/monorail.rb
brew style --fix Casks/m/monorail.rb
brew audit --cask --new --online monorail
brew install --cask monorail && brew uninstall --cask monorail
gh repo fork --remote
git add Casks/m/monorail.rb
git commit -m "monorail 1.7.16 (new cask)"
git push -u origin monorail
gh pr create --fill
```
Fix whatever `brew audit` reports before opening the pull request; the reviewers ask for the same.

## 3. Installomator (for IT teams)

The label is in `packaging/installomator/monorail.sh` with Team ID `D69G45342Y`. Installomator
checks that team on every download, which notarised releases now pass.

```bash
gh repo fork Installomator/Installomator --clone
cd Installomator
git checkout -b monorail
cp ../monorail/packaging/installomator/monorail.sh fragments/labels/monorail.sh   # or download it from GitHub
./utils/assemble.sh monorail DEBUG=0     # installs Monorail with the new label: it must succeed
git add fragments/labels/monorail.sh
git commit -m "Add label: monorail"
git push -u origin monorail
gh pr create --fill
```

## 4. The Mac App Store

**Parked.** On a real Mac, the sandbox blocked Accessibility even with it granted, and Apple allows
window managers only as Developer ID downloads. See [APP-STORE.md](APP-STORE.md#status-parked-november-2026).
The steps below are kept in case that changes.

The sandboxed edition builds in CI on every change. What only the owner can do, all in the
Ashforde OU developer account:

1. **Certificates:** in Xcode → Settings → Accounts → Ashforde OU → Manage Certificates → **+**:
   **Apple Distribution** and **Mac Installer Distribution**.
2. **App ID and profile:** developer.apple.com → Identifiers → **+** → App ID
   `org.ashforde.monorail.appstore`, with the **App Groups** capability on and the group
   `D69G45342Y.group.ashforde.suite` (the folder Monorail and Keeper share); then Profiles → **+** → **Mac App Store Connect** for that App ID
   with the Apple Distribution certificate. Download the profile.
3. **App Store Connect:** appstoreconnect.apple.com → Apps → **+** → New App: macOS, name
   "Monorail by Ashforde", bundle ID `org.ashforde.monorail.appstore`, SKU `monorail`.
4. **Export and add the secrets** (GitHub → ashfordeOU/monorail → Settings → Secrets → Actions), the
   same way as the Developer ID ones:
   - `MONORAIL_APPSTORE_CERT` + `MONORAIL_APPSTORE_PASSWORD`: the Apple Distribution `.p12`, base64
   - `MONORAIL_APPSTORE_INSTALLER_CERT` (+ `MONORAIL_APPSTORE_INSTALLER_PASSWORD` if different): the
     Mac Installer Distribution `.p12`, base64
   - `MONORAIL_APPSTORE_PROFILE`: the profile, base64: `base64 -i Monorail_App_Store.provisionprofile | pbcopy`
   - `APPLE_ID` and `APPLE_APP_PASSWORD` are already there.
5. **Then the session runs the App Store workflow** (Actions → App Store): it builds the sandboxed
   edition, signs it, checks the signature and the identifier, validates it with Apple and uploads it.
   It shows up in App Store Connect → TestFlight within the hour: try it there first.
6. **The listing**: everything to copy into App Store Connect (name, subtitle, description, keywords,
   URLs, screenshots in `assets/appstore/`, App Review notes and the App Privacy answers) is in
   [appstore/LISTING.md](appstore/LISTING.md). Then **Add for Review** and **Submit**.
