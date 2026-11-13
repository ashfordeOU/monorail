# monorail.ashforde.org: design brief

The site is rebuilt from this brief, not reskinned. Every page shares one design system, one header, one footer
and one theme control.

## 1. Audit of the old site (13 November 2026)

Checked live on all 15 pages, at 1440, 820 and 390 px wide, in light and dark.

**Homepage**
1. The hero showed the Time page. The idea Monorail is built on, the strip of windows, didn't appear until the third screen.
2. The strip demo was grey placeholder boxes, with nothing that looked like real apps or the real slider bar.
3. Dark navy app screenshots sat on a white page with mixed framing, and some were cut off at the right edge.
4. About 60% of the page was text-only cards: apps and battery, Stay Awake, Evening, Focus, Your day, the whole AI section and a 12-item list.
5. The live notch card was mostly an empty black box.
6. The themes section showed 8 made-up gradients. Monorail has 26 real themes, and you couldn't see or try any of them.
7. Theme management was one unlabelled icon, only on the homepage, with no choice of colour.
8. On a phone there was no navigation at all (links hidden, no menu), and 30 tap targets were under 24 px.
9. There were 20 sections with the same centred heading pattern, about 20,000 px tall on desktop and 28,000 px on a phone, with no story.
10. There was no visual identity: the brand gradient appeared on two words.
11. Trust and privacy were two near-identical grids, and the install command appeared twice.
12. The sharing image (OG) was the old purple launch art.
13. The 404 page was a copy of the homepage with relative paths, so every image on it was broken.
14. The docking GIF was small and low resolution.

**Other pages**

15. Every page had its own header and footer: Support, Press, Changelog and Download each had different links, widths and footers, and none had a theme control.
16. The changelog showed the App Store edition (37 mentions) and raw `<!-- -->` markers. Fixed in the builder. It was also 47,000 px with no way to jump between versions.
17. The press kit said the latest version was 1.9.0 (hard-coded), and its screenshots and highlights predated the Dashboard, AI Usage and everything since.
18. The download pages were a small white box in the middle of an empty page.
19. Support didn't cover any feature added since 1.8.
20. Docs pages were long, plain lists.

## 2. Direction: "Night Rail"

These references set the direction:
- dark, cinematic glass panels lit by atmospheric light;
- a chromatic rim on glass controls;
- an instrument dial with tick marks;
- giant outlined type behind the footer.

This is also what macOS 26 looks like (Liquid Glass), so the site and the app speak the same language.

- **Dark first, light as an equal.**
  - Night: near-black `#050507` with two slow, blurred glows.
  - Daylight: warm fog `#F4F3F1` with white glass.
- **The glows are the theme.** Their colours come from the 26 real themes in `WorkspaceColor.backdrop` (the overview's gradient and its three glows). Pick a theme anywhere on the site and the page relights.
- **Glass components:**
  - Glass is a 6% white fill, 24 px blur, a 1 px hairline and a light inner top edge.
  - Primary controls get a thin chromatic rim (coral, pink, violet, cyan), like the volume slider reference.
- **Instruments:**
  - Readings are drawn as tick-mark dials, as in the sensor reference, not flat numbers.
  - They're used for the Dashboard, performance and AI limits.
- **Type:**
  - The system font (SF Pro on a Mac).
  - Headlines at 64–128 px with tight tracking.
  - A giant outlined MONORAIL behind the final call to action.
- **Real things only:** every picture of the app is a real CI render. Mock-ups (strip, notch, gauges) are live HTML, never fake screenshots.
- **Motion:** slow and physical (the strip's spring). Everything still under Reduce Motion.

## 3. Theme management

- **Appearance:** Automatic (follows the system), Light, Dark.
- **Colour:** any of Monorail's 26 themes, grouped Classic, Seasonal and Unique as in Settings → Appearance. The default is Monorail's own coral and pink.
- **Where:** in the header on every page, as a glass popover. The "Make it yours" section on the homepage uses the same control at full size, with a live overview.
- **Storage:** one choice in this browser only (`localStorage`), applied before first paint so there's no flash.

## 4. The homepage, section by section (a story, not a list)

| # | Section | What it shows | Why |
|---|---|---|---|
| 1 | **Hero** | "Your whole Mac. On one rail." over a live desktop: menu bar, a strip of app windows, the liquid-glass slider bar. A new window slides in every few seconds; arrow keys take over. | The one idea, shown in the first second. |
| 2 | **Proof ribbon** | Notarised by Apple · Free, every feature · 0.15% of one core · 9 languages · macOS 13+ | Removes doubt before the scroll. |
| 3 | **Nothing shrinks** | Two live mini-desktops side by side: a grid tiler squeezing four windows, and Monorail sliding a fifth in at full size. | The difference, felt, not described. |
| 4 | **Move your way** | Keys, trackpad, thumb wheel, slider bar, overview: a glass chip each, the live strip reacting. | Lowers "is this hard to learn?". |
| 5 | **Docking** | The docking film in a glass frame and three steps. | The second big idea. |
| 6 | **Dashboard** | A glass window with the real icon rail: click Time, AI Usage or Switches to swap in the real screen. Above it, five tick-mark dials (CPU, memory, GPU, disk, battery). | Turns a feature list into something to explore. |
| 7 | **AI** | Limit bars with a pace line and reset countdowns, styled as in the app, plus the MCP and command line in a glass terminal. | For the audience that's growing fastest. |
| 8 | **Menu bar panel** | The real panel screenshot beside two live liquid-glass sliders. Warmth really warms this page (Evening Mode); the round toggles click. | Shows the panel and lets you feel it. |
| 9 | **Live notch** | An animated notch cycling through sharing, a meeting, a timer, charging and taking notes. | The notch is a moment, so show it as one. |
| 10 | **Everyday** | Bento: Clipboard (light and dark renders), Tools (tabs over four real tool screens), Meeting Notes (a transcript that types itself), Stay Awake, Evening, Focus. | Breadth without a wall of text. |
| 11 | **Make it yours** | All 26 themes as swatches; choosing one relights the page and a live overview. | The theme management request, made a feature. |
| 12 | **Light on your battery** | Three dials: 0.15% of one core, 0 wake-ups, 55 MB. | Numbers people screenshot. |
| 13 | **Safe and private** | One merged section: notarised, signed (Team D69G45342Y), SIP on, no account, on-device, crash reports stay put, plus the commands to check. | Two old sections become one. |
| 14 | **Compare** | Tabs: "Against other window managers" (table) and "What it replaces" (price list). | Two old sections become one. |
| 15 | **Get it** | Tabs: Download, Homebrew, Terminal, IT and MDM, with copy buttons. Then Mac, Windows beta and Linux beta. | Install in one place. |
| 16 | **FAQ** | The questions, in two columns on desktop. | |
| 17 | **Final call** | The app icon, "Give every window room. Free.", Download, with a giant outlined MONORAIL behind. | The reference's footer typography. |

## 5. Every other page

All pages share `/assets/site.css` and `/assets/site.js`: the header with the theme control and a phone menu, the
footer, glass and type. Paths are absolute, so the 404 page and nested pages always find their files.

| Page | Rebuilt as |
|---|---|
| Download (Mac, Windows, Linux, pkg) | Full-height glass card on the glow, with live version, size and date from `latest.json`, the next three steps, and other ways to install. |
| Support | Search-style hero; cards for getting started, common questions (now covering the Dashboard, AI Usage, clipboard, switches, notes and the notch) and contact. |
| Privacy | The same facts, in glass sections with a table of exactly what is and isn't sent. |
| Press | A live fact sheet (version from `latest.json`), the new real screens to download, descriptions with copy buttons, icon, film. |
| Performance | The dials, the method and the commands. |
| Changelog | The new look, a version list to jump to, and edition entries removed. |
| Docs (actions, settings, IT, agents, compatibility, security, licence, trademarks) | The same header and footer, a readable column and a sticky contents list. |
| 404 | Its own page: "This slide doesn't exist." with a way home. |
| Share | Kept as it is (a redirect page), with the shared look. |
