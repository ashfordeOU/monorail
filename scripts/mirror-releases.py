#!/usr/bin/env python3
"""Copies the newest releases onto the website, so downloads and update checks don't need GitHub.

Run by the Website workflow (pages.yml) with GH_TOKEN and GITHUB_REPOSITORY set. Writes into
OUT (default public/releases):

  <tag>/<file>          every file of each mirrored release
  latest/<file>         the newest Mac release's files, under the same names
  beta/<file>           the newest Windows and Linux beta's files
  latest.json           the newest Mac release, in the shape of GitHub's release API
  index.json            every mirrored release, newest first (the Mac beta channel reads this)

Mirrored: the newest Mac release (vX.Y.Z), the newest Mac pre-release if it's newer, and the
newest Windows and Linux beta (beta-*). Download links in the JSON point at the website.
Works while the repository is private: the workflow's token can read its releases.
"""
import json, os, shutil, sys, urllib.request

REPO = os.environ["GITHUB_REPOSITORY"]
TOKEN = os.environ["GH_TOKEN"]
OUT = sys.argv[1] if len(sys.argv) > 1 else "public/releases"
SITE = os.environ.get("SITE_URL", "https://monorail.ashforde.org") + "/releases"


def api(path, accept="application/vnd.github+json"):
    request = urllib.request.Request(
        f"https://api.github.com/repos/{REPO}/{path}",
        headers={"Authorization": f"Bearer {TOKEN}", "Accept": accept, "X-GitHub-Api-Version": "2022-11-28"})
    return urllib.request.urlopen(request, timeout=120)


releases = [r for r in json.load(api("releases?per_page=50")) if not r["draft"]]
mac = [r for r in releases if r["tag_name"].startswith("v")]
stable = next((r for r in mac if not r["prerelease"]), None)
if stable is None:
    sys.exit("No Mac release to mirror")
chosen = [stable]
if mac and mac[0] is not stable:                       # a Mac beta newer than the stable release
    chosen.insert(0, mac[0])
beta = next((r for r in releases if r["tag_name"].startswith("beta-")), None)
if beta:
    chosen.append(beta)

os.makedirs(OUT, exist_ok=True)
mirrored = []
for release in chosen:
    tag = release["tag_name"]
    folder = os.path.join(OUT, tag)
    os.makedirs(folder, exist_ok=True)
    assets = []
    for asset in release["assets"]:
        name = asset["name"]
        path = os.path.join(folder, name)
        with api(f"releases/assets/{asset['id']}", "application/octet-stream") as response, open(path, "wb") as file:
            shutil.copyfileobj(response, file)
        if os.path.getsize(path) != asset["size"]:
            sys.exit(f"{tag}/{name}: downloaded {os.path.getsize(path)} bytes, expected {asset['size']}")
        assets.append({"name": name, "size": asset["size"], "content_type": asset.get("content_type"),
                       "browser_download_url": f"{SITE}/{tag}/{name}"})
        print(f"mirrored {tag}/{name} ({asset['size']:,} bytes)")
    mirrored.append({key: release.get(key) for key in ("tag_name", "name", "body", "prerelease", "draft", "published_at")}
                    | {"html_url": "https://monorail.ashforde.org/changelog/", "assets": assets})

def alias(release, name):
    source = os.path.join(OUT, release["tag_name"])
    target = os.path.join(OUT, name)
    shutil.rmtree(target, ignore_errors=True)
    shutil.copytree(source, target)

alias(stable, "latest")
if beta:
    alias(beta, "beta")
latest = next(m for m in mirrored if m["tag_name"] == stable["tag_name"])
json.dump(latest, open(os.path.join(OUT, "latest.json"), "w"), indent=1)
json.dump(mirrored, open(os.path.join(OUT, "index.json"), "w"), indent=1)
print(f"latest: {stable['tag_name']}; beta: {beta['tag_name'] if beta else 'none'}; {len(mirrored)} releases in index.json")
