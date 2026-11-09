# Monorail on managed Macs

A guide for IT teams and for people who use Monorail on a Mac their organisation manages.

## In short

- **Monorail installs without administrator rights.** It runs from the person's own Applications
  folder (`~/Applications`) and keeps itself up to date there.
- **Much of it works straight away, with no permissions at all:** Stay Awake, Keep me Available
  (Teams and Slack keep showing the person as available), Evening Mode, display brightness and
  resolution, the command palette, and arranging the windows of scriptable apps such as Safari,
  Finder and Terminal.
- **Arranging every window needs Accessibility.** macOS requires it before any app can move other
  apps' windows, and on a standard account only an administrator can allow it. You can allow it for
  Monorail in one step with the configuration profile in
  [`packaging/mdm/Monorail-Accessibility.mobileconfig`](../packaging/mdm/Monorail-Accessibility.mobileconfig).

Monorail asks for nothing else. It doesn't record the screen, read what you type, or send your
windows anywhere. See [SECURITY.md](../SECURITY.md) for how releases are signed and checked.

## Installing

Choose whichever suits your tools. Every release is signed with Ashforde OÜ's Developer ID
(Team ID `D69G45342Y`) and notarised by Apple.

| Method | How |
|---|---|
| Signed installer package | [`Monorail.pkg`](https://monorail.ashforde.org/releases/latest/Monorail.pkg), always the newest version. It installs into `/Applications`; deploy it with Jamf, Kandji, Mosyle, Intune or any MDM. |
| Installomator | Use the `monorail` label: `Installomator.sh monorail`. Ask contact@ashforde.org for the label until it is in Installomator itself. |
| AutoPkg and Munki | Download and pkg recipes are available from contact@ashforde.org. |
| Homebrew | `brew tap ashfordeou/monorail && brew trust ashfordeou/monorail && brew install --cask monorail` |
| Without an administrator | `curl -fsSL https://monorail.ashforde.org/install.sh \| bash`. When `/Applications` isn't writable, it installs into `~/Applications` instead and says so. |

Monorail's bundle identifier is `org.ashforde.monorail`.

### Updates

The direct-download build checks monorail.ashforde.org for new releases and verifies each one (checksum, then a
code signature that must match the running copy) before replacing itself in the folder it runs
from. That works in `~/Applications` without an administrator. In `/Applications` on a standard
account it can't replace itself, so update it with your usual tools instead, or turn off **Check
for updates automatically** in Settings → General.

## Allowing Accessibility with a configuration profile

macOS keeps privacy permissions in a database only the system can change. An MDM can pre-approve a
permission with a **Privacy Preferences Policy Control (PPPC)** payload, so people never see the
request.

1. Download [`Monorail-Accessibility.mobileconfig`](../packaging/mdm/Monorail-Accessibility.mobileconfig).
2. Upload it to your MDM as a custom configuration profile (or recreate it in your MDM's own PPPC
   editor with the values below), and scope it to the Macs or people who use Monorail.
3. Sign it with your MDM if your MDM expects signed profiles. The file in this repository is
   unsigned so that you can read and check it.

**The profile must come from your MDM.** macOS ignores privacy settings in profiles that someone
installs by hand, even an administrator, and in profiles delivered to a Mac that isn't enrolled
with user-approved or automated enrolment.

The profile contains a single `com.apple.TCC.configuration-profile-policy` payload:

| Key | Value |
|---|---|
| Service | `Accessibility` |
| Identifier | `org.ashforde.monorail` |
| IdentifierType | `bundleID` |
| Allowed | `true` |
| CodeRequirement | `identifier "org.ashforde.monorail" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = D69G45342Y` |

The code requirement means the permission applies only to copies of Monorail signed by Ashforde
OÜ. You can check it against an installed copy:

```sh
codesign --display --requirements - /Applications/Monorail.app
```

Nothing else is needed. Monorail doesn't need Screen Recording, Input Monitoring or Full Disk
Access for window arranging. (Live window previews in the overview are optional and ask for
Screen Recording separately; leave them off if your policy doesn't allow it.)

## Without Accessibility

If Accessibility isn't allowed, Monorail says so once, in its menu ("Window arranging needs
Accessibility — ask IT or an admin"), and doesn't keep asking. These work straight away:

- **Stay Awake**, for as long as you choose, while an app is open, or while something downloads.
- **Keep me Available**, which keeps the Mac awake and keeps Teams, Slack and other chat apps
  showing the person as available. It tells macOS the person is active (the same signal a key press
  gives), which needs no permission.
- **Evening Mode**, display brightness below the usual minimum, and resolution changes.
- **Arranging scriptable apps.** Safari, Google Chrome, Finder, Terminal, Notes, Mail, TextEdit,
  Pages, Numbers, Keynote, Preview and iTerm2 can be put in the left or right half, fill the screen,
  be centred, or be placed side by side, from the menu or the command palette. macOS asks once for
  each app ("Monorail wants to control Safari"), and a person can answer that without an
  administrator. You can pre-approve these too, with `AppleEvents` entries in a PPPC payload, or
  block them; Monorail works either way.
- Settings, the command palette, What's New and updates.

## Opening at login (optional)

Monorail adds itself as a login item when the person turns on **Open Monorail when I log in**. On
macOS 13 and later you can manage that with a **Managed Login Items** payload
(`com.apple.servicemanagement`), so it's on and can't be switched off by accident:

```xml
<dict>
	<key>PayloadType</key>
	<string>com.apple.servicemanagement</string>
	<key>PayloadIdentifier</key>
	<string>org.ashforde.monorail.loginitem</string>
	<key>PayloadUUID</key>
	<string>REPLACE-WITH-A-NEW-UUID</string>
	<key>PayloadVersion</key>
	<integer>1</integer>
	<key>Rules</key>
	<array>
		<dict>
			<key>RuleType</key>
			<string>TeamIdentifier</string>
			<key>RuleValue</key>
			<string>D69G45342Y</string>
			<key>Comment</key>
			<string>Monorail by Ashforde</string>
		</dict>
	</array>
</dict>
```

This only stops the login item being turned off; the person still turns it on in Monorail (or you
add a launch agent with your usual tools).

## Questions

Write to [contact@ashforde.org](mailto:contact@ashforde.org), or see [SECURITY.md](../SECURITY.md) to
report a security problem privately.
