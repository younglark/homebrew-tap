# frozen_string_literal: true

# Seams under test (agreed by the implementation brief):
# 1. AliyunpanDownloadStrategy#fetch public interface: writes a complete
#    artifact to cached_location with a basename/extension Homebrew can unpack.
# 2. Failure modes: missing CLI, not logged in, non-zero exit, exit 0 without
#    a file, SHA-256 mismatch in a Homebrew-like verifier, leftover cleanup.
# 3. Cache reuse, paths containing spaces, and no mutation of aliyunpan
#    savedir / current drive / account (only `download` is invoked).
# 4. Cask prelude loading via Tap.fetch, which must work when the cask is
#    copied into Homebrew's .metadata directory (require_relative would break).

require_relative "test_helper"

class AliyunpanDownloadStrategyTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("aliyunpan-strategy-test-")
    @cache = File.join(@tmpdir, "cache")
    @log = File.join(@tmpdir, "cli.log")
    @artifact = File.join(@tmpdir, "artifact.tar.gz")
    File.write(@artifact, FIXTURE_BODY)
    ENV["FAKE_ALIYUNPAN_LOG"] = @log
    ENV["FAKE_ALIYUNPAN_MODE"] = "success"
    ENV["FAKE_ALIYUNPAN_ARTIFACT"] = @artifact
    @previous_tmpdir = ENV["TMPDIR"]
    tmpdir = File.join(@tmpdir, "tmp")
    FileUtils.mkdir_p(tmpdir)
    ENV["TMPDIR"] = tmpdir
  end

  def teardown
    if defined?(@previous_tmpdir) && @previous_tmpdir
      ENV["TMPDIR"] = @previous_tmpdir
    else
      ENV.delete("TMPDIR")
    end
    %w[FAKE_ALIYUNPAN_LOG FAKE_ALIYUNPAN_MODE FAKE_ALIYUNPAN_ARTIFACT].each do |key|
      ENV.delete(key)
    end
    FileUtils.remove_entry(@tmpdir) if @tmpdir && File.directory?(@tmpdir)
  end

  def test_fetch_writes_cached_tarball_and_passes_checksum
    url = "aliyunpan:///Software/mumuplayer/1.9.9/MuMuPlayer_Pro_1.9.9_app.tar.gz"
    strategy = new_strategy(url)

    strategy.fetch

    assert_path_exists strategy.cached_location
    assert_predicate strategy.cached_location, :file?
    assert strategy.cached_location.to_s.end_with?(".tar.gz"),
           "cached_location must keep the .tar.gz extension for unpack detection: #{strategy.cached_location}"
    assert_equal "MuMuPlayer_Pro_1.9.9_app.tar.gz", strategy.basename.to_s
    verify_sha256!(strategy.cached_location, FIXTURE_SHA256)
    refute_path_exists strategy.temporary_path
    assert_equal ["download"], recorded_subcommands
    assert_includes recorded_args_for_first_download, "--saveto"
    assert_includes recorded_args_for_first_download, "--np"
    assert_includes recorded_args_for_first_download,
                    "/Software/mumuplayer/1.9.9/MuMuPlayer_Pro_1.9.9_app.tar.gz"
    refute_includes recorded_args_for_first_download, "--driveId"
  end

  def test_fetch_reuses_cache_and_does_not_invoke_cli_again
    url = "aliyunpan:///Software/mumuplayer/1.9.9/MuMuPlayer_Pro_1.9.9_app.tar.gz"
    strategy = new_strategy(url)
    strategy.fetch
    first_calls = recorded_download_count

    ENV["FAKE_ALIYUNPAN_MODE"] = "fail"
    strategy.fetch

    assert_equal first_calls, recorded_download_count
    verify_sha256!(strategy.cached_location, FIXTURE_SHA256)
  end

  def test_fetch_supports_spaces_in_cache_and_cloud_paths
    cache = File.join(@tmpdir, "cache dir with spaces")
    tmpdir = File.join(@tmpdir, "tmp dir with spaces")
    FileUtils.mkdir_p(tmpdir)
    url = "aliyunpan:///Software/my%20files/foo%20bar.tar.gz"
    strategy = new_strategy(url, cache: cache)
    previous_tmpdir = ENV["TMPDIR"]
    ENV["TMPDIR"] = tmpdir

    begin
      strategy.fetch
    ensure
      if previous_tmpdir
        ENV["TMPDIR"] = previous_tmpdir
      else
        ENV.delete("TMPDIR")
      end
    end

    assert_path_exists strategy.cached_location
    assert_includes strategy.cached_location.to_s, "cache dir with spaces"
    assert strategy.cached_location.to_s.end_with?("foo bar.tar.gz"),
           strategy.cached_location.to_s
    assert_equal "foo bar.tar.gz", strategy.basename.to_s
    verify_sha256!(strategy.cached_location, FIXTURE_SHA256)
    assert_includes recorded_args_for_first_download, "/Software/my files/foo bar.tar.gz"
    saveto = recorded_saveto
    refute_nil saveto
    assert_includes saveto, " ", "expected --saveto to work with a path that may contain spaces"
    assert_includes saveto, tmpdir
  end

  def test_missing_cli_raises_friendly_error_without_interactive_login
    url = "aliyunpan:///Software/mumuplayer/1.9.9/MuMuPlayer_Pro_1.9.9_app.tar.gz"
    missing = File.join(@tmpdir, "no-such-aliyunpan")
    strategy = new_strategy(url, aliyunpan_executable: missing)

    error = assert_raises(AliyunpanDownloadError) { strategy.fetch }
    assert_match(/aliyunpan/i, error.message)
    assert_match(/PATH|install/i, error.message)
    refute_match(/please wait|scan|二维码|qr code/i, error.message)
    refute_path_exists strategy.cached_location
    refute_path_exists strategy.temporary_path
    refute_path_exists @log
  end

  def test_not_logged_in_raises_friendly_error_and_does_not_start_login
    ENV["FAKE_ALIYUNPAN_MODE"] = "not_logged_in"
    strategy = new_strategy("aliyunpan:///Software/mumuplayer/1.9.9/MuMuPlayer_Pro_1.9.9_app.tar.gz")

    error = assert_raises(AliyunpanDownloadError) { strategy.fetch }
    assert_match(/login/i, error.message)
    refute_match(/will now run|starting login|aliyunpan login now/i, error.message)
    refute_includes recorded_subcommands, "login"
    refute_path_exists strategy.cached_location
    refute_path_exists strategy.temporary_path
  end

  def test_nonzero_exit_does_not_leave_partial_cache
    ENV["FAKE_ALIYUNPAN_MODE"] = "fail"
    strategy = new_strategy("aliyunpan:///Software/mumuplayer/1.9.9/MuMuPlayer_Pro_1.9.9_app.tar.gz")

    error = assert_raises(AliyunpanDownloadError) { strategy.fetch }
    assert_match(/文件不存在|download failed|failed/i, error.message)
    refute_path_exists strategy.cached_location
    refute_path_exists strategy.temporary_path
    refute leftover_work_dirs?
  end

  def test_exit_zero_without_file_is_a_failure
    ENV["FAKE_ALIYUNPAN_MODE"] = "exit0_missing"
    strategy = new_strategy("aliyunpan:///Software/mumuplayer/1.9.9/MuMuPlayer_Pro_1.9.9_app.tar.gz")

    error = assert_raises(AliyunpanDownloadError) { strategy.fetch }
    assert_match(/exit(?:ed)? 0|did not write|not (?:found|saved|written)/i, error.message)
    refute_path_exists strategy.cached_location
    refute_path_exists strategy.temporary_path
    refute leftover_work_dirs?
  end

  def test_checksum_mismatch_is_detected_by_homebrew_like_verifier
    url = "aliyunpan:///Software/mumuplayer/1.9.9/MuMuPlayer_Pro_1.9.9_app.tar.gz"
    File.write(@artifact, "not-the-official-archive\n")
    strategy = new_strategy(url)
    strategy.fetch

    error = assert_raises(RuntimeError) do
      verify_sha256!(strategy.cached_location, FIXTURE_SHA256)
    end
    assert_match(/SHA256 mismatch/, error.message)
  end

  def test_fetch_does_not_change_savedir_drive_or_account
    strategy = new_strategy("aliyunpan:///Software/mumuplayer/1.9.9/MuMuPlayer_Pro_1.9.9_app.tar.gz")
    strategy.fetch

    assert_equal ["download"], recorded_subcommands
    recorded_arg_lines.each do |line|
      refute_match(/\b(login|logout|su|drive|config|cd|share)\b/, line)
    end
  end

  def test_strategy_is_a_homebrew_download_strategy_subclass
    assert AliyunpanDownloadStrategy < AbstractDownloadStrategy
    assert AliyunpanDownloadStrategy < AbstractFileDownloadStrategy
  end

  def test_cask_prelude_loads_via_tap_fetch_from_metadata_directory
    metadata_dir = File.join(@tmpdir, "Caskroom", "mumuplayer@1.9.9", ".metadata", "1.9.9", "abc123")
    FileUtils.mkdir_p(metadata_dir)
    cask_src = File.join(TAP_ROOT, "Casks", "mumuplayer@1.9.9.rb")
    copied = File.join(metadata_dir, "mumuplayer@1.9.9.rb")
    FileUtils.cp(cask_src, copied)

    # require_relative from the cached copy would miss the tap's lib/.
    refute_path_exists File.expand_path("../lib/aliyunpan_download_strategy.rb", metadata_dir)

    prelude = File.read(copied)[/\A.*?(?=\ncask )/m]
    refute_nil prelude
    assert_match(/Tap\.fetch\("younglark\/tap"\)/, prelude)

    # Homebrew has already loaded AbstractFileDownloadStrategy when it
    # evaluates a cask. The prelude must still find the tap lib from a
    # .metadata copy, where require_relative would fail.
    wrapper = File.join(metadata_dir, "load_prelude.rb")
    File.write(wrapper, <<~RUBY)
      require "digest"
      require "fileutils"
      require "pathname"
      require "uri"

      class AbstractDownloadStrategy
        def initialize(*); end
      end

      class AbstractFileDownloadStrategy < AbstractDownloadStrategy
      end

      module Tap
        def self.fetch(name)
          raise "unexpected tap \#{name}" unless name == "younglark/tap"

          Struct.new(:path).new(Pathname.new(#{TAP_ROOT.inspect}))
        end
      end

      #{prelude}
    RUBY

    # Isolate from already-loaded constants by spawning a subprocess without the test helper parent.
    script = File.join(@tmpdir, "run_metadata_load.rb")
    File.write(script, <<~RUBY)
      require "pathname"
      load #{wrapper.inspect}
      abort "strategy not defined" unless defined?(AliyunpanDownloadStrategy)
      puts "loaded"
    RUBY

    output = IO.popen(["ruby", script], err: [:child, :out], &:read)
    status = $CHILD_STATUS || $?
    assert status.success?, output
    assert_match(/loaded/, output)
  end

  def test_casks_keep_install_semantics_and_use_cloud_paths
    %w[mumuplayer@1.9.9 mumuplayer@1.9.9.forge].each do |token|
      source = File.read(File.join(TAP_ROOT, "Casks", "#{token}.rb"))
      assert_match(/cask "#{Regexp.escape(token)}" do/, source)
      assert_match(/app "MuMuPlayer\.app"/, source)
      assert_match(/depends_on arch: :arm64/, source)
      assert_match(/depends_on macos: :big_sur/, source)
      assert_match(/using: AliyunpanDownloadStrategy/, source)
      assert_match(%r{url "aliyunpan:///Software/mumuplayer/#\{version\}/MuMuPlayer_Pro_#\{version\}_app\.tar\.gz"}, source)
      refute_match(/driveId/, source)
      refute_match(/depends_on formula:/, source)
      refute_match(/^\s*auto_updates\b/, source)
      assert_includes source, 'Tap.fetch("younglark/tap")'
      if token == "mumuplayer@1.9.9"
        assert_includes source, "1d1a27907dbcc7270e0f925c816c291dbd3f21c0bc96aab05d1296fa93b5f440"
      else
        assert_includes source, "d8dc31ac08f69f459f651a032dcc24fc92407071dc7aa259ed5c35a254c4e21d"
      end
      %w[
        ~/Library/Application Scripts/*.group.com.netease.mumu.nemux
        ~/Library/Application Support/com.netease.mumu.nemux
        ~/Library/Caches/com.netease.mumu.nemux*
        ~/Library/Group Containers/*.group.com.netease.mumu.nemux
        ~/Library/HTTPStorages/com.netease.mumu.nemux*
        ~/Library/Preferences/*.netease.mumu*.plist
        ~/Library/Saved Application State/com.netease.mumu.nemux*.savedState
        ~/Library/WebKit/com.netease.mumu.nemux*
      ].each do |entry|
        assert_includes source, entry
      end
    end
  end

  # Reproduces the failure seen on macOS: brew sanitizes ENV["PATH"] to its
  # shims plus the default Unix path, so /opt/homebrew/bin is missing even
  # though aliyunpan is installed there (often as a Cellar symlink).
  def test_finds_cli_in_homebrew_prefix_when_brew_sanitizes_path
    prefix = File.join(@tmpdir, "opt", "homebrew")
    cellar = File.join(prefix, "Cellar", "aliyunpan", "0.4.0", "bin")
    FileUtils.mkdir_p(cellar)
    FileUtils.mkdir_p(File.join(prefix, "bin"))
    FileUtils.mkdir_p(File.join(prefix, "Library", "Homebrew", "shims", "shared"))
    target = File.join(cellar, "aliyunpan")
    FileUtils.cp(FAKE_CLI, target)
    FileUtils.chmod(0o755, target)
    File.symlink("../Cellar/aliyunpan/0.4.0/bin/aliyunpan", File.join(prefix, "bin", "aliyunpan"))

    with_env(
      "PATH" => "#{File.join(prefix, "Library", "Homebrew", "shims", "shared")}:/usr/bin:/bin:/usr/sbin:/sbin",
      "HOMEBREW_PREFIX" => prefix,
      "HOMEBREW_PATH" => "#{File.join(@tmpdir, "user-bin")}:/usr/bin:/bin:#{File.join(prefix, "bin")}",
      "ALIYUNPAN" => nil,
    ) do
      strategy = AliyunpanDownloadStrategy.new(
        "aliyunpan:///Software/mumuplayer/1.9.9/MuMuPlayer_Pro_1.9.9_app.tar.gz",
        "mumuplayer",
        "1.9.9",
        cache: @cache,
      )
      strategy.fetch
    end

    downloaded = Dir.glob(File.join(@cache, "downloads", "*"))
                    .reject { |path| path.end_with?(".incomplete") }
    refute_empty downloaded
    verify_sha256!(downloaded.fetch(0), FIXTURE_SHA256)
    assert_equal ["download"], recorded_subcommands
  end

  def test_aliyunpan_env_overrides_sanitized_path
    prefix = File.join(@tmpdir, "opt", "homebrew")
    FileUtils.mkdir_p(File.join(prefix, "bin"))
    override = File.join(@tmpdir, "explicit-aliyunpan")
    FileUtils.cp(FAKE_CLI, override)
    FileUtils.chmod(0o755, override)

    with_env(
      "PATH" => "/usr/bin:/bin:/usr/sbin:/sbin",
      "HOMEBREW_PREFIX" => prefix,
      "HOMEBREW_PATH" => "/usr/bin:/bin",
      "ALIYUNPAN" => override,
    ) do
      strategy = AliyunpanDownloadStrategy.new(
        "aliyunpan:///Software/mumuplayer/1.9.9/MuMuPlayer_Pro_1.9.9_app.tar.gz",
        "mumuplayer",
        "1.9.9",
        cache: @cache,
      )
      strategy.fetch
    end

    assert_equal ["download"], recorded_subcommands
    verify_sha256!(
      Dir.glob(File.join(@cache, "downloads", "*")).reject { |path| path.end_with?(".incomplete") }.fetch(0),
      FIXTURE_SHA256,
    )
  end

  def test_finds_cli_on_homebrew_path_outside_prefix
    user_bin = File.join(@tmpdir, "user local", "bin")
    FileUtils.mkdir_p(user_bin)
    FileUtils.cp(FAKE_CLI, File.join(user_bin, "aliyunpan"))
    FileUtils.chmod(0o755, File.join(user_bin, "aliyunpan"))
    prefix = File.join(@tmpdir, "opt", "homebrew")
    FileUtils.mkdir_p(File.join(prefix, "bin"))

    with_env(
      "PATH" => "/usr/bin:/bin:/usr/sbin:/sbin",
      "HOMEBREW_PREFIX" => prefix,
      "HOMEBREW_PATH" => "#{user_bin}:/usr/bin:/bin",
      "ALIYUNPAN" => nil,
    ) do
      strategy = AliyunpanDownloadStrategy.new(
        "aliyunpan:///Software/mumuplayer/1.9.9/MuMuPlayer_Pro_1.9.9_app.tar.gz",
        "mumuplayer",
        "1.9.9",
        cache: @cache,
      )
      strategy.fetch
    end

    assert_equal ["download"], recorded_subcommands
  end


  # Real aliyunpan v0.4.0 saves to --saveto plus the cloud path, e.g.
  # $saveto/Software/mumuplayer/1.9.9.forge/MuMuPlayer_Pro_1.9.9.forge_app.tar.gz
  def test_fetch_uses_cloud_hierarchy_under_saveto
    ENV["FAKE_ALIYUNPAN_MODE"] = "nested"
    url = "aliyunpan:///Software/mumuplayer/1.9.9.forge/MuMuPlayer_Pro_1.9.9.forge_app.tar.gz"
    strategy = new_strategy(url)

    strategy.fetch

    assert_path_exists strategy.cached_location
    assert_equal "MuMuPlayer_Pro_1.9.9.forge_app.tar.gz", strategy.basename.to_s
    verify_sha256!(strategy.cached_location, FIXTURE_SHA256)
    refute_path_exists strategy.temporary_path
  end

  def test_does_not_pick_same_name_file_outside_expected_nested_path
    ENV["FAKE_ALIYUNPAN_MODE"] = "flat_decoy"
    File.write(@artifact, "decoy-not-the-archive\n")
    url = "aliyunpan:///Software/mumuplayer/1.9.9.forge/MuMuPlayer_Pro_1.9.9.forge_app.tar.gz"
    strategy = new_strategy(url)

    error = assert_raises(AliyunpanDownloadError) { strategy.fetch }
    assert_match(/exit(?:ed)? 0|did not write/i, error.message)
    refute_path_exists strategy.cached_location
  end

  def test_rejects_cloud_path_that_escapes_the_save_directory
    ENV["FAKE_ALIYUNPAN_MODE"] = "nested"
    url = "aliyunpan:///Software/../../outside/MuMuPlayer_Pro_1.9.9.forge_app.tar.gz"
    strategy = new_strategy(url)

    error = assert_raises(AliyunpanDownloadError) { strategy.fetch }
    assert_match(/escapes|invalid cloud path|unsafe/i, error.message)
    refute_path_exists strategy.cached_location
  end



  IDA_PRO_CASK = "ida-pro@9.5"
  IDA_PRO_CLOUD_PATH = "/Software/IDA Pro/9.5/macOS-AppleSilicon/IDA_Professional_9.5_arm64_app.tar.gz"
  IDA_PRO_URL = "aliyunpan:///Software/IDA%20Pro/9.5/macOS-AppleSilicon/IDA_Professional_9.5_arm64_app.tar.gz"
  IDA_PRO_SHA256 = "54e87281c6640fd5cb146f0b1a0895766a4f895de48c05497843bf7991490b3d"

  def test_ida_pro_cask_structure_and_cloud_url
    source = File.read(File.join(TAP_ROOT, "Casks", "#{IDA_PRO_CASK}.rb"))
    assert_match(/cask "#{Regexp.escape(IDA_PRO_CASK)}" do/, source)
    assert_includes source, 'Tap.fetch("younglark/tap")'
    assert_match(/using: AliyunpanDownloadStrategy/, source)
    assert_includes source, 'version "9.5"'
    assert_includes source, IDA_PRO_SHA256
    assert_includes source, 'aliyunpan:///Software/IDA%20Pro/#{version}/macOS-AppleSilicon/IDA_Professional_#{version}_arm64_app.tar.gz'
    assert_match(/app "IDA Professional #\{version\}\.app"/, source)
    assert_match(/depends_on arch: :arm64/, source)
    assert_match(/depends_on macos: ">= :monterey"/, source)
    refute_match(/^\s*zap\b/, source)
    refute_match(/^\s*auto_updates\b/, source)
    refute_match(/driveId/, source)
    refute_match(/keygen|\\bcrack\\b|bypass/i, source)
    assert_match(/ida\.hexlic/, source)
    refute_match(%r{/Users/|/home/box|/workspace/ida95}, source)
    refute_match(/aliyunpan:\/\/\/Software\/IDA Pro\//, source)
    assert_match(/IDA%20Pro/, source)
  end

  def test_ida_pro_cask_prelude_loads_via_tap_fetch_from_metadata_directory
    metadata_dir = File.join(@tmpdir, "Caskroom", IDA_PRO_CASK, ".metadata", "9.5", "abc123")
    FileUtils.mkdir_p(metadata_dir)
    cask_src = File.join(TAP_ROOT, "Casks", "#{IDA_PRO_CASK}.rb")
    FileUtils.cp(cask_src, File.join(metadata_dir, "#{IDA_PRO_CASK}.rb"))
    refute_path_exists File.expand_path("../lib/aliyunpan_download_strategy.rb", metadata_dir)

    prelude = File.read(cask_src)[/\A.*?(?=\ncask )/m]
    refute_nil prelude
    wrapper = File.join(metadata_dir, "load_prelude.rb")
    File.write(wrapper, <<~RUBY)
      require "digest"
      require "fileutils"
      require "pathname"
      require "uri"

      class AbstractDownloadStrategy
        def initialize(*); end
      end

      class AbstractFileDownloadStrategy < AbstractDownloadStrategy
      end

      module Tap
        def self.fetch(name)
          raise "unexpected tap \#{name}" unless name == "younglark/tap"

          Struct.new(:path).new(Pathname.new(#{TAP_ROOT.inspect}))
        end
      end

      #{prelude}
    RUBY

    script = File.join(@tmpdir, "run_ida_metadata_load.rb")
    File.write(script, <<~RUBY)
      require "pathname"
      load #{wrapper.inspect}
      abort "strategy not defined" unless defined?(AliyunpanDownloadStrategy)
      puts "loaded"
    RUBY

    output = IO.popen(["ruby", script], err: [:child, :out], &:read)
    status = $CHILD_STATUS || $?
    assert status.success?, output
    assert_match(/loaded/, output)
  end

  def test_ida_pro_cask_url_decodes_spaces_in_cloud_path
    strategy = new_strategy(IDA_PRO_URL)
    assert_equal IDA_PRO_CLOUD_PATH, strategy.send(:cloud_path)

    error = assert_raises(URI::InvalidURIError) do
      new_strategy("aliyunpan:///Software/IDA Pro/9.5/macOS-AppleSilicon/IDA_Professional_9.5_arm64_app.tar.gz").send(:cloud_path)
    end
    assert_match(/bad URI|is not URI/i, error.message)
  end

  def test_ida_pro_fetch_uses_decoded_cloud_hierarchy_under_saveto
    ENV["FAKE_ALIYUNPAN_MODE"] = "nested"
    strategy = new_strategy(IDA_PRO_URL)
    strategy.fetch

    assert_path_exists strategy.cached_location
    verify_sha256!(strategy.cached_location, FIXTURE_SHA256)
    assert_equal "IDA_Professional_9.5_arm64_app.tar.gz", strategy.basename.to_s
    assert_includes recorded_args_for_first_download, IDA_PRO_CLOUD_PATH
    saveto = recorded_saveto
    refute_nil saveto
    assert_includes saveto, "aliyunpan-fetch-"
  end

  def test_ida_pro_app_tarball_preserves_modes_and_symlinks
    app_name = "IDA Professional 9.5.app"
    src = File.join(@tmpdir, "app-src")
    macos = File.join(src, app_name, "Contents", "MacOS")
    fw = File.join(src, app_name, "Contents", "Frameworks", "QtCore.framework")
    FileUtils.mkdir_p(macos)
    FileUtils.mkdir_p(File.join(fw, "Versions", "A"))
    File.write(File.join(macos, "ida"), "fake-ida\n")
    File.chmod(0o755, File.join(macos, "ida"))
    File.write(File.join(macos, "license.txt"), "EULA\n")
    File.chmod(0o644, File.join(macos, "license.txt"))
    File.write(File.join(fw, "Versions", "A", "QtCore"), "fake-qt\n")
    File.chmod(0o644, File.join(fw, "Versions", "A", "QtCore"))
    File.symlink("A", File.join(fw, "Versions", "Current"))
    File.symlink("Versions/Current/QtCore", File.join(fw, "QtCore"))

    archive = File.join(@tmpdir, "IDA_Professional_9.5_arm64_app.tar.gz")
    assert system("tar", "-C", src, "-czf", archive, app_name), "failed to create fixture tarball"

    dest = File.join(@tmpdir, "app-out")
    FileUtils.mkdir_p(dest)
    assert system("tar", "-C", dest, "-xzf", archive), "failed to extract fixture tarball"

    ida = File.join(dest, app_name, "Contents", "MacOS", "ida")
    lic = File.join(dest, app_name, "Contents", "MacOS", "license.txt")
    current = File.join(dest, app_name, "Contents", "Frameworks", "QtCore.framework", "Versions", "Current")
    qt = File.join(dest, app_name, "Contents", "Frameworks", "QtCore.framework", "QtCore")
    assert File.executable?(ida), "expected Contents/MacOS/ida to remain executable"
    assert_equal 0o755, File.stat(ida).mode & 0o777
    assert_equal 0o644, File.stat(lic).mode & 0o777
    refute File.executable?(lic)
    assert File.symlink?(current)
    assert_equal "A", File.readlink(current)
    assert File.symlink?(qt)
    assert File.exist?(qt)
    assert_equal "fake-qt\n", File.read(qt)
  end


  private

  def new_strategy(url, cache: @cache, aliyunpan_executable: FAKE_CLI)
    AliyunpanDownloadStrategy.new(
      url,
      "mumuplayer",
      "1.9.9",
      cache: cache,
      aliyunpan_executable: aliyunpan_executable,
    )
  end

  def recorded_arg_lines
    return [] unless File.file?(@log)

    File.read(@log).split("\n")
  end

  def recorded_subcommands
    recorded_arg_lines.filter_map { |line| line[/^arg0=(.*)$/, 1] }
  end

  def recorded_download_count
    recorded_subcommands.count("download")
  end

  def recorded_args_for_first_download
    lines = recorded_arg_lines
    start = lines.index { |line| line == "arg0=download" }
    return [] unless start

    args = []
    lines[start..].each do |line|
      break if line == "---"

      match = line.match(/^arg(\d+)=(.*)$/)
      args[Integer(match[1])] = match[2] if match
    end
    args
  end

  def recorded_saveto
    args = recorded_args_for_first_download
    index = args.index("--saveto")
    return nil unless index

    args[index + 1]
  end


  def with_env(vars)
    previous = {}
    vars.each do |key, value|
      previous[key] = ENV.key?(key) ? ENV[key] : :__unset__
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
    yield
  ensure
    previous.each do |key, value|
      if value == :__unset__
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end

  def leftover_work_dirs?
    Dir.glob(File.join(Dir.tmpdir, "aliyunpan-fetch-*")).any?
  end
end
