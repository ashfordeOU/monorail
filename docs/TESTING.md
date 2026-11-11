# Testing Monorail on a real Mac

Monorail's layout model is unit-tested on every push, but anything involving real windows, displays,
power and permissions needs a real Mac. This is the checklist to run before a big release (and before
the Product Hunt launch). It takes about 30 minutes. Note anything that's off and open an issue with
**Settings → Devices & Sharing → Report a Problem…**, which fills in your Mac and version for you.

## 1. The first-hour check (energy)

1. Restart Monorail, then use your Mac normally for about an hour.
2. Run the measuring script:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/ashfordeOU/monorail/main/scripts/measure-performance.sh -o /tmp/measure.sh && bash /tmp/measure.sh
   ```
3. Expected while idle: **under 0.2% CPU**, **under 2 wake-ups a second**, **under 120 MB of memory**.
4. For a fair "in use" comparison, do the same during the second step every time: open the overview 3 times and switch slides 10 times.

## 2. Stay Awake

- [ ] Menu bar → **Stay Awake → For 1 hour**: ☕ and a countdown appear in the menu bar.
- [ ] Leave the Mac alone past your display-sleep time: the display stays on (with **Keep the Display On**).
- [ ] Turn **Keep the Display On** off: the display sleeps, but music or a download keeps going.
- [ ] **While an App Is Open** → pick an app, then quit it: Stay Awake ends with a notice.
- [ ] **While Downloading**: start a big download, then let it finish; Stay Awake ends within about 30 seconds.
- [ ] **Move the Pointer Now and Then**: Slack or Teams still shows you as active after 10 idle minutes.
- [ ] **Still lock the screen after** 5 idle minutes: the screen locks even though the Mac stays awake.
- [ ] Unplug on low battery (set the cut-off to 50% to test): Stay Awake ends with a notice.
- [ ] A trigger, **While an external display is connected**: plug in a display and Stay Awake starts by itself; unplug it and it stops.
- [ ] Check `pmset -g assertions | grep Monorail` in Terminal shows Monorail's assertion while on, and nothing when off.

## 3. Closed-lid mode (MacBook)

- [ ] **Evening Mode** (menu bar): Turn On Now warms every display, including external ones; drag the slider in Settings → Evening Mode and the screen follows; a screenshot keeps normal colours; quit Monorail and the colours come back; sleep and wake the Mac and it stays warm.
- [ ] Turn on **Stay Awake with the Lid Closed** and start Stay Awake: macOS asks for your password once.
- [ ] Plugged in, no external display: close the lid for a minute, open it: the Mac kept running (`pmset -g` shows SleepDisabled 1).
- [ ] End Stay Awake: no password asked, and within a few seconds `pmset -g` shows SleepDisabled 0.
- [ ] Start it again, then quit Monorail (or `kill -9` it): within a few seconds SleepDisabled is 0.
- [ ] Start it again, unplug the power with the lid closed: the Mac goes to sleep (with "Only while plugged in", the default).
- [ ] Close the lid with no external display: music keeps playing and a download keeps going.
- [ ] End Stay Awake: macOS asks for your password again, and closing the lid sleeps the Mac as usual.
- [ ] Quit Monorail during a closed-lid session, then reopen it: the lid behaves normally again.

## 4. Displays

- [ ] Plug in a display: it gets its own strip; nothing jumps on the built-in screen.
- [ ] Unplug it: its windows move to the built-in screen, all visible.
- [ ] Plug it back in: those windows go back to the external display, arranged as before.
- [ ] Mirror the displays, then stop mirroring: one strip while mirrored, two afterwards.
- [ ] Turn on **Remember the layout for each set of displays**: set up a layout at your desk, unplug, rearrange, plug back in; the desk layout returns.
- [ ] Change the resolution (System Settings → Displays): slides keep their proportions.

## 5. Floating windows

- [ ] In Finder, select 5 files and press ⌘I: every Get Info window is fully on screen and they're staggered.
- [ ] Open an app's Settings window: it opens where the app puts it, or centred if that would be off screen.
- [ ] Drag a floating window mostly off screen and let go: it comes back into view.

## 6. The rest of 1.2 and 1.3

- [ ] ⌃⌥/ then type `safari two thirds` and press return.
- [ ] Start a screen share in Zoom, Teams or Meet: private apps hide; they come back when sharing stops.
- [ ] Run an AI coding assistant in a terminal and let it ask for approval: a chime and a notice.
- [ ] **Animate Windows** off in the menu bar menu: windows move instantly, everything still works.
- [ ] Settings → About → **Usage** shows launches, running time, CPU and your most used actions.
- [ ] Switch the language (Settings → General) to each of the 9 languages: the menu bar menu and Settings tabs change.

## 6b. New in 1.7.29

- [ ] Unplug, open Chrome with a few busy tabs, wait two minutes: ⚡ in the slider popover turns orange and lists Chrome; its windows show ⚡ in the overview (⌃⌥O). Right-click a window there → Hide This App works.
- [ ] Battery panel (⚡ in the popover, or Settings → Apps → show the battery in the menu bar): charge, time left and watts match System Settings → Battery roughly; the history line fills in over an hour; Low Power Mode switches (asks for your password).
- [ ] Pause an app from the panel: it stops using the processor (Activity Monitor), shows under “Resting”; click its Dock icon or plug in and it wakes. Quit Monorail while an app is paused: the app wakes.
- [ ] Run `claude` or `codex` in Terminal: it appears under AI agents. `monorail battery` prints the same figures as JSON.
- [ ] Settings → Apps → turn on hiding power-hungry apps; leave a busy app untouched for an hour on battery: it's hidden with a notice; plug in and it comes back.
- [ ] The popover's row under the slides: Layouts applies a saved layout, Focus toggles focus mode, and the battery chip opens ⚡.
- [ ] Turn on Stage Manager: Monorail pauses with a notice and the popover shows “Paused for Stage Manager”; turn it off and tiling carries on.
- [ ] Settings → Shortcuts → Clashes: set a Monorail shortcut to ⌃← (Move left a space) and it's listed; **Use …** swaps it for a free one.
- [ ] A portrait display: new slides stack top to bottom. Settings → Layout → Keep screen edges clear: a 40 pt top edge keeps windows below it.

## 7. Crash check (a week)

Turn on **Settings → Devices & Sharing → Keep crash and hang reports on this Mac** for a week of normal use.
Then press **Report a Problem…**: if there are reports, the folder opens so you can attach them to the issue.

## End-to-end smoke test

On a Mac with Monorail running and the local API on (Settings → Automation → Local API):

```bash
sh scripts/smoke-test.sh
```

It opens three TextEdit windows, checks that Monorail tiles them, pairs two, undoes, moves one to
workspace 2, then closes them. It takes about 20 seconds and prints each check. Run it before a
release, alongside `Monorail --self-test`.

## UI test in GitHub Actions (self-hosted Mac)

`Monorail --ui-test` runs the same checks as the smoke test from inside the app, without the
local API, and exits with 0 when they pass. GitHub's Mac runners can't grant Accessibility, so the
**UI test** workflow runs on a Mac of yours:

1. On that Mac: GitHub → repository → Settings → Actions → Runners → **New self-hosted runner**
   (macOS). Follow the steps, and add the label `monorail-ui` when asked.
2. Run the workflow once (Actions → UI test → Run workflow). It builds and installs
   `~/Applications/Monorail UI Test.app`, then stops at the UI test step because the app has no
   Accessibility access yet.
3. In System Settings → Privacy & Security → Accessibility, allow **Monorail UI Test**. Every later
   build is signed with the same certificate, so this is needed only once.
4. Run the workflow again. It quits your everyday Monorail during the test and opens it again after.

To run it without Actions: `dist/Monorail.app/Contents/MacOS/Monorail --ui-test` from a terminal
that has Accessibility access, or after allowing the built app.
