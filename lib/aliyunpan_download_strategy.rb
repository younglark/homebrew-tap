# frozen_string_literal: true

require "digest"
require "fileutils"
require "open3"
require "timeout"
require "tmpdir"
require "uri"

# Downloads a single file with tickstep/aliyunpan into Homebrew's cache.
#
# This class is intended to be passed as `url ..., using: AliyunpanDownloadStrategy`
# from a cask. Homebrew only accepts a subclass of AbstractDownloadStrategy.
# Formula dependencies are installed after cask fetch, so the CLI must already
# be on PATH and logged in. The strategy never runs `login`, `drive`, `config`,
# or other account-mutating commands, and it does not write a driveId into the
# cask. Cloud paths are taken from the `aliyunpan://` URL.
class AliyunpanDownloadError < RuntimeError; end

unless defined?(AbstractFileDownloadStrategy)
  raise NameError, "AliyunpanDownloadStrategy requires Homebrew's AbstractFileDownloadStrategy"
end

class AliyunpanDownloadStrategy < AbstractFileDownloadStrategy
  def fetch(timeout: nil)
    if usable_cached_file?
      put_already_downloaded
      maybe_create_symlink
      return
    end

    executable = locate_aliyunpan!
    pan_path = cloud_path
    archive_name = File.basename(pan_path)
    raise AliyunpanDownloadError, "cloud path is missing a filename: #{pan_path}" if archive_name.empty? || archive_name == "/"

    work_dir = Dir.mktmpdir("aliyunpan-fetch-")
    begin
      command = [
        executable,
        "download",
        "--saveto", work_dir,
        "--np",
        pan_path,
      ]
      stdout, stderr, status = run_command(command, chdir: work_dir, timeout: timeout)
      output = "#{stdout}#{stderr}"

      unless status.success?
        raise AliyunpanDownloadError, failure_message(output, status, pan_path)
      end

      artifact = File.join(work_dir, archive_name)
      unless File.file?(artifact) && File.size(artifact).positive?
        raise AliyunpanDownloadError, <<~MSG
          aliyunpan exited 0 but did not write #{archive_name} under #{work_dir}.
          The CLI may have skipped a same-name file or saved somewhere else.
          Cloud path: #{pan_path}
          #{output.strip}
        MSG
      end

      cached_location.dirname.mkpath
      FileUtils.rm_f(temporary_path)
      FileUtils.mv(artifact, temporary_path)
      FileUtils.rm_f(cached_location)
      File.rename(temporary_path, cached_location)
      maybe_create_symlink
    ensure
      FileUtils.remove_entry(work_dir) if work_dir && File.directory?(work_dir)
      FileUtils.rm_f(temporary_path)
    end
  end

  def clear_cache
    super
    FileUtils.rm_f(temporary_path)
  end

  private

  def usable_cached_file?
    File.file?(cached_location) && File.size(cached_location).positive?
  end

  def put_already_downloaded
    return unless respond_to?(:ohai) && !quiet_output?

    ohai "Already downloaded: #{cached_location}"
  end

  def quiet_output?
    respond_to?(:quiet?) && quiet?
  end

  def maybe_create_symlink
    return unless respond_to?(:create_symlink_to_cached_download)

    create_symlink_to_cached_download(cached_location)
  end

  def cloud_path
    uri = URI(url)
    path = uri.path.to_s
    path = URI::DEFAULT_PARSER.unescape(path)
    unless path.start_with?("/")
      raise AliyunpanDownloadError, "aliyunpan URL must include an absolute cloud path: #{url}"
    end

    path
  end

  def locate_aliyunpan!
    configured = meta[:aliyunpan_executable]
    configured = ENV["ALIYUNPAN"] if configured.nil? || configured.to_s.empty?
    if configured && !configured.to_s.empty?
      path = configured.to_s
      return path if executable_file?(path)

      raise AliyunpanDownloadError, missing_cli_message(path)
    end

    found = which_aliyunpan
    return found if found

    raise AliyunpanDownloadError, missing_cli_message("aliyunpan")
  end

  def executable_file?(path)
    File.file?(path) && File.executable?(path)
  end

  # brew install sanitizes ENV["PATH"] to Homebrew shims plus /usr/bin:/bin:/usr/sbin:/sbin,
  # so a CLI installed into HOMEBREW_PREFIX/bin (or only present on the user's original
  # PATH, saved as HOMEBREW_PATH) would otherwise be invisible.
  def which_aliyunpan
    candidate_directories.each do |dir|
      candidate = File.join(dir, "aliyunpan")
      return candidate if executable_file?(candidate)
    end
    nil
  end

  def candidate_directories
    dirs = []
    dirs.concat(split_path_env("PATH"))
    dirs.concat(homebrew_prefix_bindirs)
    dirs.concat(split_path_env("HOMEBREW_PATH"))
    dirs.uniq
  end

  def split_path_env(key)
    ENV.fetch(key, "").split(File::PATH_SEPARATOR).reject(&:empty?)
  end

  def homebrew_prefix_bindirs
    prefixes = []
    prefixes << ENV["HOMEBREW_PREFIX"] unless ENV["HOMEBREW_PREFIX"].to_s.empty?
    prefixes << HOMEBREW_PREFIX.to_s if defined?(HOMEBREW_PREFIX) && !HOMEBREW_PREFIX.to_s.empty?
    prefixes.uniq.map { |prefix| File.join(prefix, "bin") }
  end

  def run_command(command, chdir:, timeout:)
    capture = lambda do
      Open3.capture3(*command, chdir: chdir, stdin_data: "")
    end

    if timeout
      Timeout.timeout(timeout, &capture)
    else
      capture.call
    end
  rescue Timeout::Error
    raise AliyunpanDownloadError, "Timed out running aliyunpan after #{timeout}s"
  end

  def failure_message(output, status, pan_path)
    if output.match?(/未登录/)
      return <<~MSG
        aliyunpan is not logged in. Run `aliyunpan login` yourself first.
        This cask will not start an interactive login during brew install.
      MSG
    end

    <<~MSG
      aliyunpan download failed (exit #{status.exitstatus}) for #{pan_path}.
      Confirm the file exists on the current Aliyun drive (the packages live
      on the backup drive / 备份盘; check with `aliyunpan who` and `aliyunpan ls`).
      #{output.strip}
    MSG
  end

  def missing_cli_message(path)
    <<~MSG
      The `aliyunpan` CLI was not found (looked for #{path}).
      Install tickstep/aliyunpan from https://github.com/tickstep/aliyunpan,
      make sure the binary is executable, and run `aliyunpan login` before
      `brew install`. Homebrew sanitizes PATH during cask fetches, so this
      strategy also looks in HOMEBREW_PREFIX/bin and HOMEBREW_PATH.
      To override the lookup for one command, set ALIYUNPAN to the absolute
      path of the `aliyunpan` binary. Homebrew formula dependencies are
      installed after a cask is fetched, so this CLI must already be present;
      do not rely on `depends_on formula`.
    MSG
  end
end
