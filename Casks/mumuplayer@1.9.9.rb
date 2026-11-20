# frozen_string_literal: true

# Load from the tap path, not relative to this file. Homebrew copies casks
# into Caskroom .metadata, where require_relative "../lib/..." would fail.
strategy_path = if defined?(Tap)
  Tap.fetch("younglark/tap").path/"lib/aliyunpan_download_strategy.rb"
else
  File.expand_path("../lib/aliyunpan_download_strategy.rb", __dir__)
end
require strategy_path.to_s

cask "mumuplayer@1.9.9" do
  version "1.9.9"
  sha256 "1d1a27907dbcc7270e0f925c816c291dbd3f21c0bc96aab05d1296fa93b5f440"

  url "aliyunpan:///Software/mumuplayer/#{version}/MuMuPlayer_Pro_#{version}_app.tar.gz",
      using: AliyunpanDownloadStrategy
  name "MuMuPlayer"
  desc "Netease MuMu Player 1.9.9 for Apple silicon"
  homepage "https://mumu.163.com/mac/"

  depends_on arch: :arm64
  depends_on macos: :big_sur

  app "MuMuPlayer.app"

  # auto_updates is intentionally omitted: this cask is pinned to 1.9.9.
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
