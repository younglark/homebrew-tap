# frozen_string_literal: true

# Load from the tap path, not relative to this file. Homebrew copies casks
# into Caskroom .metadata, where require_relative "../lib/..." would fail.
strategy_path = if defined?(Tap)
  Tap.fetch("younglark/tap").path/"lib/aliyunpan_download_strategy.rb"
else
  File.expand_path("../lib/aliyunpan_download_strategy.rb", __dir__)
end
require strategy_path.to_s

cask "adobe-photoshop@27.5" do
  version "27.5"
  sha256 "bf27d96a8ba5249f96c53049622f1dbf15dab0c239319f636bb42c427d6a1907"

  url "aliyunpan:///Software/Photoshop/#{version}/macOS-AppleSilicon/Adobe_Photoshop_2026_#{version}_app.tar.gz",
      using: AliyunpanDownloadStrategy
  name "Adobe Photoshop 2026"
  desc "Adobe Photoshop 2026 27.5 app, packed as-is from a third-party archive"
  homepage "https://www.adobe.com/products/photoshop.html"

  depends_on macos: ">= :ventura"

  app "Adobe Photoshop 2026.app"

  # No zap: this cask only stages the app bundle. Do not delete user
  # documents, presets, or Creative Cloud data on uninstall.
  # No preflight/postflight/uninstall scripts: brew only copies the app.

  caveats <<~EOS
    This cask installs an as-is extract of Adobe Photoshop 2026.app
    (CFBundleShortVersionString 27.5.0, universal x86_64+arm64, macOS 13+).
    The source was a third-party remixed installer package, not an official
    Adobe Admin Console or Creative Cloud package. The .app was packed
    without modification: no files were added, removed, repaired, patched,
    or re-signed.

    This cask does not run installer scripts, does not change hosts,
    certificates, or security settings, and does not add a license.
    Provide your own Adobe account or license as Adobe documents before
    first launch.

    The bundle was statically checked for version, architecture, and that
    archived file bytes, modes, and symlinks match the installer payload.
    It has not been launched on a Mac, and brew install has not been
    tested, as part of packaging this cask.
  EOS
end
