Monorail for Windows (beta), portable build {VERSION}
=====================================================

Monorail arranges your windows side by side on a strip you scroll through, one strip per display.
This is an early beta of the Windows version: expect rough edges, and please tell us what you
find at https://github.com/ashfordeOU/monorail/issues.

No installer, no admin: unzip and run Monorail.exe
--------------------------------------------------
1. Unzip the whole folder anywhere you can open files from, such as Downloads or Documents.
   Keep the DLL files next to Monorail.exe: they are the runtime it needs.
2. Double-click Monorail.exe. It puts an icon in the notification area (the tray) and starts
   arranging your windows. Nothing is installed and you don't need to be an administrator.

Windows SmartScreen may warn you the first time, because the beta isn't code-signed yet: choose
"More info", then "Run anyway". If Windows still blocks it, right-click the zip before
unzipping, choose Properties, tick "Unblock" and unzip again.

Keyboard shortcuts
------------------
Win+Alt with these keys (Ctrl+Win+Alt, or Ctrl+Alt, when Windows or another app already uses
Win+Alt; run from a terminal, Monorail prints the ones it got):

  Left / Right / Up / Down   focus the window on that side
  Home / End                 focus the first / last window
  Shift + arrows             move the focused window
  W  (Shift+W)               cycle the window's width (Shift: backwards)
  F                          full width
  , (comma)                  stack into the slide on the left
  . (full stop)              unstack
  Page Down / Page Up        next / previous virtual desktop
  Shift + Page Down / Up     take the focused window to the next / previous desktop

Quitting
--------
Click the tray icon and choose Quit. The same menu pauses and resumes Monorail and opens or
reloads the settings file. (Run from a terminal, Ctrl+C stops it too.)

Stay Awake (like Caffeine)
--------------------------
In the tray icon's menu, Stay Awake keeps the PC and its display from sleeping: Off, For 1 Hour
or Until Turned Off. While it's on, "Keep Chat Apps Showing Me as Available" (ticked unless you
untick it) presses F15, a key no app uses, whenever the PC has been idle for 50 seconds, so Teams
and Slack don't mark you as away. None of this needs administrator rights. Your choice is
remembered in the settings file.

Settings
--------
%APPDATA%\Monorail\settings.json, written the first time Monorail runs, in the same format as
the Mac app's. Changes apply as soon as you save. Monorail never writes next to Monorail.exe or
to the registry, so to remove it, quit it and delete this folder (and %APPDATA%\Monorail if you
like).

Things to know
--------------
- Apps running as administrator can't be moved by Monorail (Windows doesn't let a normal app
  move them), so they stay where they are.
- To start Monorail when you sign in, put a shortcut to Monorail.exe in your Startup folder
  (press Win+R, type shell:startup and press Enter).
- Monorail is free. Licence: FSL-1.1-ALv2 (LICENSE.txt). The DLLs are the Swift runtime and the
  Microsoft Visual C++ runtime, included so nothing needs installing.
