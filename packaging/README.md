# Packaging

Ways to install Monorail besides the DMG, the zip and Homebrew. The release workflow keeps the
version and checksums in these files up to date after every release.

| Folder | For | How people use it |
|---|---|---|
| `installomator/` | IT teams using Installomator with Jamf, Kandji, Mosyle… | Add the label upstream (see the file), then `Installomator.sh monorail` |
| `autopkg/` | Munki and AutoPkg users | `autopkg run Monorail.pkg.recipe.yaml` |
| `macports/` | MacPorts users | Submit the Portfile to github.com/macports/macports-ports, then `sudo port install monorail` |
| `nix/` and `/flake.nix` | Nix and nix-darwin users | `nix profile install github:ashfordeOU/monorail` |
| `../scripts/build-appstore.sh` | The Mac App Store edition | See `docs/APP-STORE.md` |

Every release also has a `.pkg` installer (signed once a Developer ID Installer certificate is
added) for MDM tools.
