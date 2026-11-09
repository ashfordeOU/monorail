# Making the repository private

People get Monorail from monorail.ashforde.org, not from GitHub, so the repository can be
private.

| What | Where it comes from now |
|---|---|
| Downloads (DMG, pkg, zip, checksums) | `monorail.ashforde.org/releases/latest/`. Each website deploy copies the newest release there (`scripts/mirror-releases.py`). |
| Windows and Linux betas | `monorail.ashforde.org/releases/beta/`, through `/download/windows/` and `/download/linux/` |
| The app's update check | `monorail.ashforde.org/releases/latest.json` (and `index.json` for the beta channel), from 1.7.25 on. Older versions ask GitHub. |
| Guides (IT, actions, settings, compatibility, security, licence, trademarks) | `monorail.ashforde.org/docs/…`, built from the Markdown by `scripts/render-docs.py` |
| Install script | `curl -fsSL https://monorail.ashforde.org/install.sh \| bash` |
| Feedback, crashes, security reports | An email to contact@ashforde.org |
| Homebrew | `brew install --cask ashfordeou/monorail/monorail`, from a small public tap repository, `ashfordeOU/homebrew-monorail`, that holds only `Casks/monorail.rb` |

## Order

1. **Release 1.7.25.** It asks the website for updates. Wait about four weeks so most people
   update. Until the repository is private, older versions still update through GitHub.
2. **Create the public tap** `ashfordeOU/homebrew-monorail`, with only `Casks/monorail.rb` from
   this repository in it. The release workflow then keeps its version and checksum current.
3. **Set the repository variable** `SAVE_CI_MINUTES` to `true` (Settings → Secrets and variables →
   Actions → Variables). From then on, Mac and Windows checks only run when asked for: Actions →
   CI or Platforms → Run workflow → tick *full*. Releases still run them. Linux checks run on every
   change.
4. **Make it private:** Settings → General → Danger Zone → Change visibility. GitHub Pages keeps
   serving the site, because the account has GitHub Pro.

## What goes with it

- **Nix and MacPorts:** both fetch from the public repository, so they stop working.
- **The download counts on `/stats/`:** they come from GitHub, so that page stops showing them.
- **Code that's already public** stays available under the Functional Source License it was
  published under. Only new changes stay private.
