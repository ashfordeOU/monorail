cask "monorail" do
  version "1.7.20"
  sha256 "4fc042429d5d99e570473b817712228659a146da961c9cb6fd1a50f34d5d3854"

  url "https://github.com/ashfordeOU/monorail/releases/download/v#{version}/Monorail-#{version}.dmg"
  name "Monorail by Ashforde®"
  desc "Scrolling window manager: every window rides one rail"
  homepage "https://github.com/ashfordeOU/monorail"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :ventura"

  app "Monorail.app"

  uninstall quit: ["org.ashforde.monorail", "org.ashforde.macslider"]

  zap trash: [
    "~/Library/Application Support/Monorail",
    "~/Library/Preferences/org.ashforde.macslider.plist",
    "~/Library/Preferences/org.ashforde.monorail.plist",
  ]
end
