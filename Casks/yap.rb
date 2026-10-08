cask "yap" do
  version "0.1"
  sha256 "eb5eb973e743562e35953be576889a7d3c25d9906b4a9734aca1c99b19aa83e8"

  url "https://github.com/0xdeafcafe/yap/releases/download/v#{version}/Yap.zip"
  name "Yap"
  desc "Hold fn to dictate, using the built-in on-device speech model"
  homepage "https://github.com/0xdeafcafe/yap"

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
