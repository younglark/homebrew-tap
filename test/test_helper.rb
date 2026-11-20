# frozen_string_literal: true

require "digest"
require "fileutils"
require "minitest/autorun"
require "pathname"
require "tmpdir"
require "uri"

# Minimal Homebrew-compatible cache contract for tests. Not loaded under real Homebrew.
unless defined?(AbstractDownloadStrategy)
  module Utils
    module_function

    def safe_filename(basename)
      basename.gsub(/[[:cntrl:]\/]/, "")
    end
  end

  class AbstractDownloadStrategy
    attr_reader :url, :cache, :meta, :name, :version

    def initialize(url, name, version, **meta)
      @url = url
      @name = name
      @version = version
      @cache = Pathname.new(meta.fetch(:cache).to_s)
      @meta = meta
    end

    def fetch(timeout: nil); end

    def clear_cache
      FileUtils.rm_rf(cached_location)
    end
  end

  class AbstractFileDownloadStrategy < AbstractDownloadStrategy
    def temporary_path
      @temporary_path ||= Pathname.new("#{cached_location}.incomplete")
    end

    def cached_location
      return @cached_location if defined?(@cached_location) && @cached_location

      url_sha256 = Digest::SHA256.hexdigest(url)
      @cached_location = @cache / "downloads" / "#{url_sha256}--#{Utils.safe_filename(resolved_basename)}"
    end

    def basename
      cached_location.basename.sub(/^[\da-f]{64}--/, "")
    end

    def parse_basename(url, search_query: true)
      uri = URI(url)
      File.basename(URI::DEFAULT_PARSER.unescape(uri.path.to_s))
    end

    def create_symlink_to_cached_download(target_cached_location)
      # Homebrew creates a named symlink beside the hashed cache file.
      # Tests only need the method to exist.
    end

    private

    def resolved_basename
      parse_basename(url)
    end
  end
end

require_relative "../lib/aliyunpan_download_strategy"

FIXTURE_BODY = "fixture-body-v1\n"
# Independent known-good SHA-256 of FIXTURE_BODY (sha256sum of the literal bytes).
FIXTURE_SHA256 = "9e4615e5f785ae0c4f2eb2349be8dfa8f53cc64cef1ce0ca843300daf4c8558b"
FAKE_CLI = File.expand_path("fixtures/fake_aliyunpan", __dir__)
TAP_ROOT = File.expand_path("..", __dir__)

def verify_sha256!(path, expected)
  actual = Digest::SHA256.file(path).hexdigest
  raise "SHA256 mismatch: expected #{expected}, got #{actual}" unless actual == expected
end
