# Installomator label for Monorail by Ashforde®.
# To add it upstream: open a pull request to github.com/Installomator/Installomator adding this
# block to fragments/labels/monorail.sh. expectedTeamID is Ashforde OÜ's Apple Team ID; submit it once
# releases are signed with a Developer ID (until then Installomator will refuse unsigned packages).
monorail)
    name="Monorail"
    type="pkg"
    packageID="org.ashforde.monorail"
    downloadURL="https://monorail.ashforde.org/releases/latest/Monorail.pkg"
    appNewVersion="$(curl -fsL https://monorail.ashforde.org/releases/latest.json | grep -o '"tag_name": *"v[^"]*"' | sed -E 's/.*"v([^"]*)"/\1/')"
    expectedTeamID="D69G45342Y"
    ;;
