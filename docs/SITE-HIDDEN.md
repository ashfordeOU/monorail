# Hidden from the website for now

Some things are left off monorail.ashforde.org on purpose. This file says what, why and exactly how
to bring each one back. Nothing here was deleted from the app or from the history: the app still
works with Keeper, and every removed page is in git.

## Keeper (hidden 9 November 2026, for the Product Hunt launch)

Monorail launches on its own, so the site doesn't mention Keeper. **The app is unchanged:** Monorail
still recognises Keeper, shares Stay Awake and lid-closed mode with it, and shows it under "Also from
Ashforde" in the menu.

What was taken off the site, all in commit `3406602` ("Monorail's site without Keeper for the launch"):

| What | Where it was |
|---|---|
| The **Monorail + Keeper** page | `site/keeper/index.html` (the whole page) |
| The **"Better with Keeper"** section on the home page | `site/index.html`, `<section id="keeper">`, between the Features and Shortcuts sections, with its styles (`/* Monorail + Keeper */`) |
| The **Keeper** link in the top menu | `site/index.html`, `<a href="#keeper">Keeper</a>` after Features |
| The footer links **Keeper** (keeper.ashforde.org) and **Monorail + Keeper** | `site/index.html`, the "Ashforde" footer column |
| `keeper/` in the sitemap | `.github/workflows/pages.yml`, the sitemap loop |
| Keeper entries on the changelog page | `.github/workflows/pages.yml`, "Build the changelog page": a filter drops bullets that mention Keeper. `CHANGELOG.md` itself still has them. |

### Bring it back

```bash
# Everything at once: undo the commit that hid it (resolve any conflicts with later changes to the home page).
git revert 3406602
```

Or piece by piece, from the version just before it:

```bash
git show 3406602^:site/keeper/index.html > site/keeper/index.html      # the Monorail + Keeper page
git show 3406602^:site/index.html > /tmp/index-with-keeper.html         # copy the section, menu link, footer links and styles back
```

Then remove the Keeper filter line from the changelog step in `pages.yml`, put `keeper/` back in the
sitemap list, and push as usual (through `incoming`).

## The Mac App Store edition (hidden 9 November 2026)

Parked because Apple's sandbox blocks moving other apps' windows (see [APP-STORE.md](APP-STORE.md)).
The changelog page leaves out "Not in the App Store edition" and the bullets about the edition; the
filter is in the same step of `pages.yml`, next to the Keeper one. Remove those two lines to show
them again.

## Also off the site since the repository went private-ready

- The **download stats page** (`/stats/`, removed in commit `cd65b62`): it read its counts from
  GitHub, which a private repository can't give. Bring it back with `git show cd65b62^:site/stats/index.html`,
  pointed at a source that still works (for example the stats server).
- Links to the source code on GitHub, Nix and MacPorts install lines.
