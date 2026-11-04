cask "monorail" do
  version "1.7.19"
  sha256 "c935373ba9161986246822dadbc9896a3bead99442a3ec62bdde6e9f9c1271cd"

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
