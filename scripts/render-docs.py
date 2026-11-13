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
    "docs/AGENTS.md": ("agents", "AI agents and Monorail"),
    "SECURITY.md": ("security", "Security"),
    "LICENSE": ("licence", "Licence"),
    "TRADEMARKS.md": ("trademarks", "Trademarks"),
}
SLUGS = {os.path.basename(src): slug for src, (slug, _) in GUIDES.items()}

PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>{title} · Monorail</title>
<link rel="canonical" href="https://monorail.ashforde.org/docs/{slug}/">
<!--#head-->
</head>
<body>
<!--#header-->
<main id="main" class="wrap">
  <section class="page-hero"><span class="eyebrow"><i></i>Guide</span><h1>{title}</h1></section>
  <div class="{layout}">
    {toc}
    <article class="prose">{body}</article>
  </div>
</main>
<!--#footer-->
</body>
</html>
"""


def contents(body):
    """A sticky list of the guide's sections, from its second-level headings."""
    heads = re.findall(r'<h2 id="([^"]+)">(.*?)</h2>', body)
    if len(heads) < 3:
        return ""
    links = "".join('<a href="#%s">%s</a>' % (anchor, re.sub(r"<[^>]+>", "", text)) for anchor, text in heads)
    return '<nav class="toc glass flat" aria-label="On this page"><b>On this page</b>%s</nav>' % links


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
        body = f"<pre>{html.escape(text)}</pre>"
    else:
        text = re.sub(r"(?<!!)\[([^\]]+)\]\(([^)\s]+)\)", relink, text)
        body = markdown.markdown(text, extensions=["tables", "fenced_code", "toc", "sane_lists"])
        body = re.sub(r"^\s*<h1[^>]*>.*?</h1>", "", body, count=1, flags=re.S)  # the page has its own title
    toc = contents(body)
    folder = os.path.join(OUT, "docs", slug)
    os.makedirs(folder, exist_ok=True)
    page = PAGE.format(title=html.escape(title), slug=slug, body=body, toc=toc, layout="toc-layout" if toc else "narrow")
    open(os.path.join(folder, "index.html"), "w", encoding="utf-8").write(page)
    print(f"docs/{slug}/ from {src}")
