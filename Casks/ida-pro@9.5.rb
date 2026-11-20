# frozen_string_literal: true

# Load from the tap path, not relative to this file. Homebrew copies casks
# into Caskroom .metadata, where require_relative "../lib/..." would fail.
strategy_path = if defined?(Tap)
  Tap.fetch("younglark/tap").path/"lib/aliyunpan_download_strategy.rb"
else
  File.expand_path("../lib/aliyunpan_download_strategy.rb", __dir__)
end
require strategy_path.to_s

cask "ida-pro@9.5" do
  version "9.5"
  sha256 "54e87281c6640fd5cb146f0b1a0895766a4f895de48c05497843bf7991490b3d"

  # Spaces in the cloud path must be percent-encoded. URI() rejects a raw
  # space, and AliyunpanDownloadStrategy unescapes the path before calling
  # the CLI (see test_ida_pro_cask_url_decodes_spaces_in_cloud_path).
  url "aliyunpan:///Software/IDA%20Pro/#{version}/macOS-AppleSilicon/IDA_Professional_#{version}_arm64_app.tar.gz",
      using: AliyunpanDownloadStrategy
  name "IDA Professional"
  desc "Hex-Rays IDA Professional 9.5 for Apple silicon"
  homepage "https://hex-rays.com/ida-pro"

  depends_on arch: :arm64
  depends_on macos: ">= :monterey"

  app "IDA Professional #{version}.app"

  # No zap: this cask only stages the app bundle. Do not delete ~/.idapro or
  # other user license/database locations on uninstall.

  caveats <<~EOS
    This cask installs an extracted IDA Professional 9.5.app for Apple silicon
    (CFBundleShortVersionString 9.5.261026.365f1f33, arm64, macOS 12+).
    It does not run the official InstallBuilder installer and does not
    include an activation license. Provide your own Hex-Rays license
    (for example ida.hexlic) as documented by Hex-Rays before first launch.

    The archive was statically unpacked and checked (version, architecture,
    file modes, bundled EULA and third-party LICENSE texts). It has not been
    launched on a Mac as part of packaging this cask.
  EOS
end
