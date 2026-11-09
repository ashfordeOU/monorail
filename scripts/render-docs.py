#!/usr/bin/env python3
"""Publishes the guides people need as pages on the website, so they don't depend on GitHub.

  python3 scripts/render-docs.py public

Writes public/docs/<slug>/index.html for each guide below, in the site's look. Links between the
guides point at their pages; links to other repository files are dropped (the text stays).
Needs the Python "markdown" package.
"""
import html, os, re, sys
import markdown

OUT = sys.argv[1] if len(sys.argv) > 1 else "public"
GUIDES = {  # source → (slug, title)
    "docs/IT.md": ("it", "Monorail for IT"),
    "docs/ACTIONS.md": ("actions", "Every action"),
    "docs/SETTINGS.md": ("settings", "Every setting"),
    "docs/COMPATIBILITY.md": ("compatibility", "Compatibility"),
    "SECURITY.md": ("security", "Security"),
    "LICENSE": ("licence", "Licence"),
    "TRADEMARKS.md": ("trademarks", "Trademarks"),
}
SLUGS = {os.path.basename(src): slug for src, (slug, _) in GUIDES.items()}

PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} · Monorail</title>
<link rel="icon" href="../../favicon.ico" sizes="48x48">
<script>try {{ const t = localStorage.getItem('monorail-theme'); if (t === 'light' || t === 'dark') document.documentElement.dataset.theme = t; }} catch (e) {{}}</script>
<style>
:root {{ --ink:#24112B; --muted:#7A5A70; --line:rgba(36,17,43,.10); --bg:#FFF8F3; --card:#FFFFFF; --soft:#FBEFEA; --plum:#D63A80; color-scheme:light; }}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{ --ink:#F6ECF3; --muted:#BFA6B6; --line:rgba(255,255,255,.10); --bg:#120914; --card:#1D1022; --soft:#241429; --plum:#F07AB0; color-scheme:dark; }} }}
:root[data-theme="dark"] {{ --ink:#F6ECF3; --muted:#BFA6B6; --line:rgba(255,255,255,.10); --bg:#120914; --card:#1D1022; --soft:#241429; --plum:#F07AB0; color-scheme:dark; }}
* {{ box-sizing:border-box; }}
body {{ margin:0; font:17px/1.6 -apple-system, BlinkMacSystemFont, "SF Pro Text", "Inter", "Helvetica Neue", Arial, sans-serif; color:var(--ink); background:var(--bg); -webkit-font-smoothing:antialiased; }}
main {{ max-width:900px; margin:0 auto; padding:32px 16px 72px; overflow-wrap:anywhere; }}
a {{ color:var(--plum); }}
.top {{ display:flex; align-items:center; justify-content:space-between; gap:12px; flex-wrap:wrap; margin-bottom:24px; }}
.brand {{ display:flex; align-items:center; gap:10px; font-weight:700; color:var(--ink); text-decoration:none; }}
.brand img {{ width:30px; height:30px; border-radius:8px; }}
.top nav {{ display:flex; gap:16px; font-size:15px; flex-wrap:wrap; }}
.top nav a {{ color:var(--muted); text-decoration:none; }}
h1 {{ font-size:clamp(30px, 5vw, 44px); line-height:1.1; letter-spacing:-.02em; }}
h2 {{ margin-top:40px; }}
code {{ background:var(--soft); padding:1px 6px; border-radius:6px; font-size:.92em; }}
pre {{ background:var(--soft); padding:14px 16px; border-radius:12px; overflow-x:auto; }}
pre code {{ padding:0; background:none; }}
.table {{ overflow-x:auto; }}
table {{ border-collapse:collapse; width:100%; font-size:15px; }}
th, td {{ text-align:left; vertical-align:top; padding:8px 10px; border-bottom:1px solid var(--line); }}
footer {{ margin-top:56px; color:var(--muted); font-size:14px; }}
</style>
</head>
<body>
<main>
<header class="top">
  <a class="brand" href="../../"><img src="../../assets/icon.png" alt="" width="30" height="30">Monorail</a>
  <nav aria-label="Site"><a href="../../changelog/">Changelog</a><a href="../../support/">Support</a><a href="../../privacy/">Privacy</a><a href="../../download/">Download</a></nav>
</header>
{body}
<footer>© Ashforde OÜ · <a href="mailto:contact@ashforde.org">contact@ashforde.org</a></footer>
</main>
</body>
</html>
"""


def relink(match):
    text, target = match.group(1), match.group(2)
    if re.match(r"(https?:|mailto:|#)", target):
        return match.group(0)
    name = os.path.basename(target.split("#")[0])
    anchor = "#" + target.split("#")[1] if "#" in target else ""
    if name in SLUGS:
        return f"[{text}](../{SLUGS[name]}/{anchor})"
    return text  # another file in the repository: keep the words, drop the link


for src, (slug, title) in GUIDES.items():
    text = open(src, encoding="utf-8").read()
    if src == "LICENSE":
        body = f"<h1>{html.escape(title)}</h1>\n<pre>{html.escape(text)}</pre>"
    else:
        text = re.sub(r"(?<!!)\[([^\]]+)\]\(([^)\s]+)\)", relink, text)
        body = markdown.markdown(text, extensions=["tables", "fenced_code", "toc", "sane_lists"])
        body = body.replace("<table>", '<div class="table"><table>').replace("</table>", "</table></div>")
    folder = os.path.join(OUT, "docs", slug)
    os.makedirs(folder, exist_ok=True)
    open(os.path.join(folder, "index.html"), "w", encoding="utf-8").write(PAGE.format(title=html.escape(title), body=body))
    print(f"docs/{slug}/ from {src}")
