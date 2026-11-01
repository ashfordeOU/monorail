# Installomator label for Monorail by Ashforde®.
# To add it upstream: open a pull request to github.com/Installomator/Installomator adding this
# block to fragments/labels/monorail.sh. Set expectedTeamID to Ashforde OÜ's Apple Team ID once
# releases are signed with a Developer ID (until then Installomator will refuse unsigned packages).
monorail)
    name="Monorail"
    type="pkg"
    packageID="org.ashforde.macslider"
    downloadURL="$(downloadURLFromGit ashfordeOU monorail)"
    appNewVersion="$(versionFromGit ashfordeOU monorail)"
    expectedTeamID="REPLACE_WITH_TEAM_ID"
    ;;
