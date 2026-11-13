cask "monorail" do
  version "1.9.0"
  sha256 "55c2f0452be0a3b46c8eb176f9dc8f2dfd713a9545c27fa8b7ff496e1493d2c1"

  url "https://monorail.ashforde.org/releases/v#{version}/Monorail-#{version}.dmg"
  name "Monorail by Ashforde®"
  desc "Scrolling window manager: every window rides one rail"
  homepage "https://monorail.ashforde.org/"

  livecheck do
    url "https://monorail.ashforde.org/releases/latest.json"
    strategy :json do |json|
      json["tag_name"]&.delete_prefix("v")
    end
  end

  auto_updates true
  depends_on macos: :ventura

  app "Monorail.app"

  uninstall quit: ["org.ashforde.monorail", "org.ashforde.macslider"]

  zap trash: [
    "~/Library/Application Support/Monorail",
    "~/Library/Preferences/org.ashforde.macslider.plist",
    "~/Library/Preferences/org.ashforde.monorail.plist",
  ]
end
