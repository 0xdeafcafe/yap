cask "yap" do
  version "0.3"
  sha256 "c3458f7a0482e797c506f385431bd3d4548553bfcda2d95f77ddce17ecfdc066"

  url "https://github.com/0xdeafcafe/yap/releases/download/v#{version}/Yap.zip"
  name "Yap"
  desc "Hold fn to dictate, using the built-in on-device speech model"
  homepage "https://github.com/0xdeafcafe/yap"

  auto_updates true
  depends_on macos: :tahoe

  app "Yap.app"

  uninstall quit: "red.forbes.yap"

  zap trash: [
    "~/.config/yap",
    "~/Library/Application Support/Yap",
    "~/Library/Logs/Yap",
    "~/Library/Preferences/red.forbes.yap.plist",
  ]
end
