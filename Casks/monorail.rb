cask "monorail" do
  version "1.7.27"
  sha256 "26477bd351c60856287c83c70b123d904f9a2334428a028e85a87fbeb2ad84f4"

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
