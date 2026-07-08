#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require "time"
require "uri"

class RequirementOpenaiLiveReadiness
  ROOT = File.expand_path("..", __dir__)
  DEFAULT_FIXTURE_PATH = "docs/evaluation/fixtures/requirement_generation/cases.json"
  DEFAULT_RESPONSES_URL = "https://api.openai.com/v1/responses"

  def initialize(env:, stdout:, stderr:)
    @env = env
    @stdout = stdout
    @stderr = stderr
  end

  def run(argv)
    options = parse_options(argv)
    payload = execute(options)
    stdout.puts(JSON.pretty_generate(payload))
    payload.fetch(:safe_failures).empty? ? 0 : 1
  rescue OptionParser::ParseError => e
    stderr.puts("引数が不正です: #{e.message}")
    stderr.puts(option_parser.to_s)
    2
  end

  private

  attr_reader :env, :stdout, :stderr

  def execute(options)
    payload = base_payload(options)
    failures = configuration_failures(payload)
    payload.merge(
      safe_failures: failures,
      next_actions: next_actions_for(failures),
      suggested_commands: suggested_commands(payload)
    )
  end

  def base_payload(options)
    fixture_path = options.fetch(:fixture_path)
    output_path = options.fetch(:output_path)
    responses_url = env.fetch("OPENAI_RESPONSES_URL", DEFAULT_RESPONSES_URL)

    {
      checked_at: Time.now.utc.iso8601,
      openai_api_key_configured: present?(env["OPENAI_API_KEY"]),
      openai_requirement_model_configured: present?(env["OPENAI_REQUIREMENT_MODEL"]),
      openai_responses_url: safe_url(responses_url),
      openai_responses_url_https: https_url?(responses_url),
      fixture_path: fixture_path,
      fixture_present: File.file?(expand_path(fixture_path)),
      output_path: output_path,
      output_directory_writable: output_directory_writable?(output_path),
      safe_failures: [],
      next_actions: [],
      suggested_commands: []
    }
  end

  def parse_options(argv)
    parsed_options.clear
    option_parser.parse!(argv)
    {
      fixture_path: parsed_options.fetch(:fixture_path, DEFAULT_FIXTURE_PATH),
      output_path: parsed_options.fetch(:output_path, default_output_path)
    }
  end

  def option_parser
    @option_parser ||= OptionParser.new do |opts|
      opts.banner = "Usage: requirement-openai-live-readiness.rb [options]"
      opts.on("--fixtures PATH", "評価fixture JSON") { |value| parsed_options[:fixture_path] = value }
      opts.on("--output PATH", "OpenAI live評価結果のMarkdown出力先") { |value| parsed_options[:output_path] = value }
    end
  end

  def parsed_options
    @parsed_options ||= {}
  end

  def default_output_path
    "docs/evaluation/#{Time.now.utc.strftime("%Y%m%d")}_requirement_generation_openai_live.md"
  end

  def configuration_failures(payload)
    failures = []
    failures << "openai_api_key_missing" unless payload.fetch(:openai_api_key_configured)
    failures << "openai_requirement_model_missing" unless payload.fetch(:openai_requirement_model_configured)
    failures << "openai_responses_url_invalid_or_insecure" unless payload.fetch(:openai_responses_url_https)
    failures << "requirement_generation_fixture_missing" unless payload.fetch(:fixture_present)
    failures << "requirement_generation_output_directory_unwritable" unless payload.fetch(:output_directory_writable)
    failures
  end

  def next_actions_for(failures)
    failures.flat_map do |failure|
      case failure
      when "openai_api_key_missing"
        ["OPENAI_API_KEYを安全なsecret storeまたはローカル.envへ設定する。"]
      when "openai_requirement_model_missing"
        ["OPENAI_REQUIREMENT_MODELをlive評価対象モデル名で設定する。"]
      when "openai_responses_url_invalid_or_insecure"
        ["OPENAI_RESPONSES_URLをhttps://api.openai.com/v1/responsesまたは同等のHTTPS endpointへ設定する。"]
      when "requirement_generation_fixture_missing"
        ["Requirement生成評価fixtureのpathを確認し、--fixturesで正しいpathを指定する。"]
      when "requirement_generation_output_directory_unwritable"
        ["docs/evaluation/など書き込み可能な出力先を--outputで指定する。"]
      else
        ["safe failure #{failure} をrunbookに照らして確認する。"]
      end
    end.uniq
  end

  def suggested_commands(payload)
    return [] unless payload.fetch(:fixture_present) && payload.fetch(:output_directory_writable)

    [
      "cd backend",
      "set -a; source ../.env; set +a",
      [
        "bundle exec ruby ../scripts/evaluate-requirement-generation.rb",
        "--provider openai",
        "--fixtures #{payload.fetch(:fixture_path)}",
        "--output #{payload.fetch(:output_path)}",
        "--enforce",
        "--quiet"
      ].join(" ")
    ]
  end

  def safe_url(raw_url)
    uri = URI.parse(raw_url.to_s)
    return nil unless uri.scheme && uri.host

    sanitized = URI::Generic.build(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.default_port == uri.port ? nil : uri.port,
      path: uri.path
    )
    sanitized.to_s
  rescue URI::InvalidURIError
    nil
  end

  def https_url?(raw_url)
    URI.parse(raw_url.to_s).scheme == "https"
  rescue URI::InvalidURIError
    false
  end

  def output_directory_writable?(output_path)
    directory = File.dirname(expand_path(output_path))
    File.directory?(directory) && File.writable?(directory)
  end

  def expand_path(path)
    File.expand_path(path, ROOT)
  end

  def present?(value)
    !value.nil? && !value.to_s.empty?
  end
end

if $PROGRAM_NAME == __FILE__
  exit RequirementOpenaiLiveReadiness.new(env: ENV, stdout: $stdout, stderr: $stderr).run(ARGV)
end
