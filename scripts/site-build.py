#!/usr/bin/env python3
"""Stamps the site's shared head, header and footer into every page of a built site.

Pages carry three markers: <!--#head--> inside <head>, <!--#header--> at the top of <body> and <!--#footer--> at the end.
Usage: site-build.py public/   (the Pages workflow runs it after the changelog and docs pages are generated)."""
import pathlib, re, sys

HEAD = """<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<link rel="icon" href="/favicon.ico" sizes="48x48">
<link rel="icon" type="image/png" sizes="32x32" href="/icons/icon-32.png">
<link rel="icon" type="image/png" sizes="16x16" href="/icons/icon-16.png">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="manifest" href="/site.webmanifest">
<meta name="theme-color" content="#050507">
<link rel="stylesheet" href="/ui/site.css">
<script src="/ui/themes.js"></script>
<script>
/* Before the first paint: the appearance and colour chosen on this browser, so nothing flashes. */
(() => { const d = document.documentElement; let m = null, c = null;
  try { m = localStorage.getItem('monorail-mode'); c = localStorage.getItem('monorail-colour'); } catch (e) {}
  d.dataset.scheme = m === 'light' || m === 'dark' ? m : (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
  const t = c && window.MONORAIL_THEMES && window.MONORAIL_THEMES[c];
  if (t) { t.l.forEach((x, i) => d.style.setProperty('--l' + (i + 1), x)); t.g.forEach((x, i) => d.style.setProperty('--g' + (i + 1), x)); t.p.forEach((x, i) => d.style.setProperty('--w' + (i + 1), x)); } })();
</script>
<script src="/ui/site.js" defer></script>"""

NAV = [("/#windows", "Windows"), ("/#dashboard", "Dashboard"), ("/#everyday", "Everyday"), ("/#ai", "AI"), ("/#themes", "Themes"),
       ("/changelog/", "What’s new"), ("/support/", "Support")]

ICON = {
    "theme": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 3a9 9 0 0 0 0 18c1.4 0 2-1 2-2 0-1.6-1.5-2-1.5-3.3 0-1 .8-1.7 1.8-1.7H17a4 4 0 0 0 4-4c0-4-4-7-9-7z"/><circle cx="7.5" cy="11" r="1.1" fill="currentColor"/><circle cx="10" cy="7" r="1.1" fill="currentColor"/><circle cx="15" cy="7.2" r="1.1" fill="currentColor"/></svg>',
    "menu": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M4 8h16M4 16h16"/></svg>',
    "down": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 4v11m0 0-4.5-4.5M12 15l4.5-4.5M5 19.5h14"/></svg>',
}

def header(path):
    links = []
    for href, label in NAV:
        current = ' aria-current="page"' if (href.endswith("/") and path.startswith(href.strip("/") + "/")) else ""
        links.append('<a href="%s"%s>%s</a>' % (href, current, label))
    return """<a class="skip" href="#main">Skip to content</a>
<div class="ambient" aria-hidden="true"><i></i><b></b></div>
<div class="warmth" id="warmth" aria-hidden="true"></div>
<header class="top">
  <div class="bar glass flat">
    <a class="brand" href="/"><img src="/assets/icon.png" alt="" width="26" height="26">Monorail</a>
    <nav aria-label="Main">%s</nav>
    <span class="spacer"></span>
    <button type="button" class="iconbtn" id="theme-btn" aria-haspopup="dialog" aria-expanded="false" aria-controls="theme-pop" title="Appearance and colour">%s<span class="sr">Appearance and colour</span></button>
    <a class="btn primary small dl" href="/download/" data-smartdl data-short="1"><span data-dl-label>Download</span></a>
    <button type="button" class="iconbtn menu-btn" id="menu-btn" aria-expanded="false" aria-label="Menu">%s</button>
  </div>
  <div class="theme-pop" id="theme-pop" role="dialog" aria-label="Appearance and colour" hidden>
    <h2>Appearance</h2>
    <div class="seg" data-mode-pick role="group" aria-label="Appearance">
      <button type="button" data-mode="auto">Automatic</button><button type="button" data-mode="light">Light</button><button type="button" data-mode="dark">Dark</button>
    </div>
    <div data-theme-picker></div>
    <p class="now"><span>Now: <b data-theme-name>Monorail</b></span><span class="faint">Saved on this browser</span></p>
  </div>
</header>""" % ("".join(links), ICON["theme"], ICON["menu"])

FOOTER = """<footer class="foot">
  <div class="wrap">
    <div class="cols">
      <div><a class="brand" href="/"><img src="/assets/icon.png" alt="" width="26" height="26">Monorail by Ashforde®</a>
        <p style="margin-top:14px;max-width:34ch">Your whole Mac, on one rail. Free for every Mac, by Ashforde OÜ, a company in the European Union.</p>
        <p style="margin-top:18px"><a class="btn glassy small dl" href="/download/" data-smartdl><span data-dl-label>Download for Mac</span></a></p></div>
      <div><h2>Monorail</h2><ul><li><a href="/#windows">Windows</a></li><li><a href="/#dashboard">Dashboard</a></li><li><a href="/#everyday">Everyday</a></li><li><a href="/#ai">AI</a></li><li><a href="/changelog/">What’s new</a></li><li><a href="/performance/">Performance</a></li><li><a href="/press/">Press</a></li></ul></div>
      <div><h2>Help</h2><ul><li><a href="/support/">Support</a></li><li><a href="/docs/actions/">Every action</a></li><li><a href="/docs/settings/">Every setting</a></li><li><a href="/docs/it/">For IT</a></li><li><a href="/docs/agents/">AI agents</a></li><li><a href="/docs/compatibility/">Compatibility</a></li><li><a href="mailto:contact@ashforde.org?subject=Monorail%20problem">Report a problem</a></li></ul></div>
      <div><h2>Ashforde</h2><ul><li><a href="/privacy/">Privacy</a></li><li><a href="/docs/security/">Security</a></li><li><a href="/docs/licence/">Licence</a></li><li><a href="/docs/trademarks/">Trademarks</a></li><li><a href="mailto:contact@ashforde.org">contact@ashforde.org</a></li></ul></div>
    </div>
    <p class="legal">© Ashforde OÜ. Ashforde® is a registered trademark of Ashforde OÜ. Licensed under the Functional Source License (FSL-1.1-ALv2). The Monorail name and icon are trademarks of Ashforde OÜ. This site sets no cookies: it only counts visits and downloads, anonymously. Your appearance and colour choice is kept on this browser only.</p>
  </div>
  <div class="giant" aria-hidden="true">Monorail</div>
</footer>
<div class="afterdl" id="afterdl" role="dialog" aria-label="Next steps" hidden>
  <button type="button" class="iconbtn x" id="afterdlclose" aria-label="Close">✕</button>
  <b>Thanks for downloading Monorail</b>
  <ol><li>Open <span id="afterdlname">the Monorail DMG</span> from your Downloads.</li><li>Drag <b>Monorail</b> onto <b>Applications</b>.</li><li>Open Monorail and allow <b>Accessibility</b> when asked. The welcome tour does the rest.</li></ol>
  <p class="hint">Didn’t start? <a id="afterdlretry" href="/releases/latest/Monorail.dmg">Download again</a></p>
</div>"""

def build(site):
    site = pathlib.Path(site)
    count = 0
    for page in site.rglob("*.html"):
        text = page.read_text(encoding="utf-8")
        if "<!--#" not in text:
            continue
        rel = "/" + page.relative_to(site).as_posix()
        rel = rel[: -len("index.html")] if rel.endswith("index.html") else rel
        text = text.replace("<!--#head-->", HEAD).replace("<!--#header-->", header(rel.lstrip("/"))).replace("<!--#footer-->", FOOTER)
        page.write_text(text, encoding="utf-8")
        count += 1
    print("site-build: %d pages" % count)

if __name__ == "__main__":
    build(sys.argv[1] if len(sys.argv) > 1 else "public")
