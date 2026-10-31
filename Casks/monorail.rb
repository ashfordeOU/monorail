cask "monorail" do
  version "1.5.2"
  sha256 "2c04ad9e19358ae6ec81684af2917394c3c8e759ebf2225a824624b250f023dd"

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

  uninstall quit: "org.ashforde.macslider"

  zap trash: [
    "~/Library/Application Support/Monorail",
    "~/Library/Preferences/org.ashforde.macslider.plist",
  ]
end
