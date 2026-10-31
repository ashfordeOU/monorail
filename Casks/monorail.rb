cask "monorail" do
  version "1.5.0"
  sha256 "41592f14cac14a191c1a6f4fc3844b40349c2185ae42644e1465840f2fbc9dd3"

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
