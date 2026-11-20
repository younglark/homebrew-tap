cask "mumuplayer@1.9.9.forge" do
  version "1.9.9.forge"
  sha256 "d8dc31ac08f69f459f651a032dcc24fc92407071dc7aa259ed5c35a254c4e21d"

  url "https://younglark.synology.me:1443/api/packages/root/generic/mumuplayer/#{version}/MuMuPlayer_Pro_#{version}_app.tar.gz"
  name "MuMuPlayer"
  desc "Netease MuMu Player 1.9.9 with reconstructed libmumu and Frida"
  homepage "https://mumu.163.com/mac/"

  depends_on arch: :arm64
  depends_on macos: :big_sur

  app "MuMuPlayer.app"

  # auto_updates is intentionally omitted: this cask is pinned to 1.9.9.forge.
  # Any in-app updater is independent of Homebrew and will not refresh this cask's version or checksum.

  zap trash: [
    "~/Library/Application Scripts/*.group.com.netease.mumu.nemux",
    "~/Library/Application Support/com.netease.mumu.nemux",
    "~/Library/Caches/com.netease.mumu.nemux*",
    "~/Library/Group Containers/*.group.com.netease.mumu.nemux",
    "~/Library/HTTPStorages/com.netease.mumu.nemux*",
    "~/Library/Preferences/*.netease.mumu*.plist",
    "~/Library/Saved Application State/com.netease.mumu.nemux*.savedState",
    "~/Library/WebKit/com.netease.mumu.nemux*",
  ]
end
