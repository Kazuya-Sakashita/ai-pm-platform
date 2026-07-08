#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "digest"
require "json"
require "net/http"
require "openssl"
require "optparse"
require "time"
require "uri"

class GithubWebhookLiveSmoke
  API_VERSION = "2022-11-28"
  DEFAULT_API_BASE_URL = "https://api.github.com"
  DEFAULT_LIMIT = 10

  Result = Struct.new(:ok, :payload, keyword_init: true)

  def initialize(env:, stdout:, stderr:)
    @env = env
    @stdout = stdout
    @stderr = stderr
  end

  def run(argv)
    options = parse_options(argv)
    result = execute(options)
    stdout.puts(JSON.pretty_generate(result.payload))
    result.ok ? 0 : 1
  rescue OptionParser::ParseError => e
    stderr.puts("引数が不正です: #{e.message}")
    stderr.puts(parser_help)
    2
  end

  private

  attr_reader :env, :stdout, :stderr

  def execute(options)
    checked_at = Time.now.utc.iso8601
    failures = configuration_failures

    base_payload = {
      checked_at: checked_at,
      api_base_url: options.fetch(:api_base_url),
      app_id_configured: present?(env["GITHUB_APP_ID"]),
      private_key_configured: present?(private_key_pem),
      webhook_secret_configured: present?(env["GITHUB_WEBHOOK_SECRET"]),
      hook_config: nil,
      recent_deliveries: [],
      safe_failures: failures
    }

    hard_failures = failures & %w[github_app_id_missing github_app_private_key_missing]
    return Result.new(ok: false, payload: with_next_actions(base_payload)) if hard_failures.any?

    token = app_jwt(app_id: env.fetch("GITHUB_APP_ID"), private_key_pem: private_key_pem)
    hook_config = get_json(
      api_base_url: options.fetch(:api_base_url),
      path: "/app/hook/config",
      token: token
    )
    deliveries = get_json(
      api_base_url: options.fetch(:api_base_url),
      path: "/app/hook/deliveries?per_page=#{options.fetch(:limit)}",
      token: token
    )

    safe_hook = safe_hook_config(hook_config)
    safe_deliveries = Array(deliveries).map { |delivery| safe_delivery(delivery) }
    safe_failures = failures + hook_failures(safe_hook) + delivery_failures(safe_deliveries)
    payload = base_payload.merge(
      hook_config: safe_hook,
      recent_deliveries: safe_deliveries,
      safe_failures: safe_failures.uniq
    )

    Result.new(ok: smoke_ok?(payload), payload: with_next_actions(payload))
  rescue OpenSSL::PKey::RSAError
    Result.new(
      ok: false,
      payload: with_next_actions(
        base_payload.merge(safe_failures: base_payload.fetch(:safe_failures) + [
          "github_app_private_key_invalid"
        ])
      )
    )
  rescue StandardError => e
    Result.new(
      ok: false,
      payload: with_next_actions(
        base_payload.merge(safe_failures: base_payload.fetch(:safe_failures) + [
          safe_error_code(e)
        ])
      )
    )
  end

  def parse_options(argv)
    options = {
      api_base_url: env.fetch("GITHUB_API_BASE_URL", DEFAULT_API_BASE_URL),
      limit: DEFAULT_LIMIT
    }

    option_parser.parse!(argv)
    options.merge(@parsed_options || {})
  end

  def option_parser
    @option_parser ||= OptionParser.new do |opts|
      opts.banner = "Usage: github-webhook-live-smoke.rb [options]"
      opts.on("--api-base-url URL", "GitHub API base URL") { |value| parsed_options[:api_base_url] = value }
      opts.on("--limit N", Integer, "Recent delivery count, default #{DEFAULT_LIMIT}") do |value|
        parsed_options[:limit] = [[value, 1].max, 30].min
      end
    end
  end

  def parsed_options
    @parsed_options ||= {}
  end

  def parser_help
    option_parser.to_s
  end

  def configuration_failures
    failures = []
    failures << "github_app_id_missing" unless present?(env["GITHUB_APP_ID"])
    failures << "github_app_private_key_missing" unless present?(private_key_pem)
    failures << "github_webhook_secret_missing" unless present?(env["GITHUB_WEBHOOK_SECRET"])
    failures
  end

  def private_key_pem
    @private_key_pem ||= begin
      if present?(env["GITHUB_APP_PRIVATE_KEY_BASE64"])
        Base64.decode64(env.fetch("GITHUB_APP_PRIVATE_KEY_BASE64"))
      elsif present?(env["GITHUB_APP_PRIVATE_KEY"])
        env.fetch("GITHUB_APP_PRIVATE_KEY").gsub("\\n", "\n")
      end
    end
  end

  def app_jwt(app_id:, private_key_pem:)
    issued_at = Time.now.to_i - 60
    expires_at = issued_at + 540
    signing_input = [
      base64_json({ alg: "RS256", typ: "JWT" }),
      base64_json({ iat: issued_at, exp: expires_at, iss: app_id.to_s })
    ].join(".")
    signature = OpenSSL::PKey::RSA.new(private_key_pem)
                                  .sign(OpenSSL::Digest::SHA256.new, signing_input)

    "#{signing_input}.#{base64_url(signature)}"
  end

  def get_json(api_base_url:, path:, token:)
    uri = URI.join("#{api_base_url}/", path.delete_prefix("/"))
    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "application/vnd.github+json"
    request["Authorization"] = "Bearer #{token}"
    request["X-GitHub-Api-Version"] = API_VERSION

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end

    raise "github_api_http_#{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue JSON::ParserError
    raise "github_api_invalid_json"
  end

  def safe_hook_config(config)
    url = safe_url(config["url"])
    {
      url: url,
      content_type: config["content_type"],
      insecure_ssl: config["insecure_ssl"].to_s,
      secret_configured_on_github: present?(config["secret"])
    }
  end

  def safe_delivery(delivery)
    raw_identifier = delivery["guid"] || delivery["id"]
    {
      delivery_digest: digest_identifier(raw_identifier),
      event: delivery["event"],
      action: delivery["action"],
      status: delivery["status"],
      status_code: delivery["status_code"],
      delivered_at: delivery["delivered_at"],
      duration: delivery["duration"],
      redelivery: delivery["redelivery"],
      installation_id: delivery["installation_id"]&.to_s,
      repository_id: delivery["repository_id"]&.to_s
    }.compact
  end

  def hook_failures(hook_config)
    failures = []
    failures << "github_webhook_url_missing" unless present?(hook_config[:url])
    failures << "github_webhook_url_placeholder" if hook_config[:url].to_s.include?("example.com")
    failures << "github_webhook_insecure_ssl_enabled" if hook_config[:insecure_ssl] == "1"
    failures
  end

  def delivery_failures(deliveries)
    return [] if deliveries.empty?

    failed_delivery = deliveries.any? do |delivery|
      status_code = delivery[:status_code].to_i
      status_code < 200 || status_code >= 300
    end
    failed_delivery ? ["github_webhook_recent_delivery_failed"] : []
  end

  def smoke_ok?(payload)
    payload.fetch(:safe_failures).empty? &&
      present?(payload.dig(:hook_config, :url)) &&
      payload.dig(:hook_config, :insecure_ssl) != "1"
  end

  def with_next_actions(payload)
    failures = Array(payload[:safe_failures]).uniq
    payload.merge(
      safe_failures: failures,
      next_actions: next_actions_for(failures)
    )
  end

  def next_actions_for(failures)
    actions = failures.flat_map do |failure|
      case failure
      when "github_app_id_missing"
        ["GITHUB_APP_IDをruntimeへ設定する。"]
      when "github_app_private_key_missing"
        ["GITHUB_APP_PRIVATE_KEY_BASE64またはGITHUB_APP_PRIVATE_KEYをruntimeへ設定する。"]
      when "github_app_private_key_invalid"
        ["GitHub App private keyを再発行し、base64化した値をruntimeへ設定し直す。"]
      when "github_webhook_secret_missing"
        ["GitHub App settingsのWebhook secretと同じ値をGITHUB_WEBHOOK_SECRETへ設定する。"]
      when "github_webhook_url_missing", "github_webhook_url_placeholder"
        ["GitHub App settingsのWebhook URLをowned staging/production endpointの/api/v1/webhooks/githubへ変更する。"]
      when "github_webhook_insecure_ssl_enabled"
        ["GitHub App settingsでSSL verificationを有効にする。"]
      when "github_webhook_recent_delivery_failed"
        ["Webhook URLとsecret設定後にGitHub deliveryを再送または再triggerし、2xx deliveryを確認する。"]
      else
        ["safe failure #{failure} をrunbookに照らして確認する。"]
      end
    end
    actions.uniq
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

  def digest_identifier(value)
    return nil unless present?(value)

    Digest::SHA256.hexdigest(value.to_s)
  end

  def base64_json(value)
    base64_url(JSON.generate(value))
  end

  def base64_url(value)
    Base64.urlsafe_encode64(value, padding: false)
  end

  def present?(value)
    !value.nil? && !value.to_s.empty?
  end

  def safe_error_code(error)
    message = error.message.to_s
    return message if message.match?(/\Agithub_[a-z0-9_]+(?:_\d{3})?\z/)

    error.class.name.gsub(/[^a-zA-Z0-9]+/, "_").downcase
  end
end

if $PROGRAM_NAME == __FILE__
  exit GithubWebhookLiveSmoke.new(env: ENV, stdout: $stdout, stderr: $stderr).run(ARGV)
end
