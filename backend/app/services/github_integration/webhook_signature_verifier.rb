require "openssl"

module GithubIntegration
  class WebhookSignatureVerifier
    SIGNATURE_PREFIX = "sha256=".freeze

    def initialize(secret: ENV["GITHUB_WEBHOOK_SECRET"], previous_secret: ENV["GITHUB_WEBHOOK_PREVIOUS_SECRET"])
      @secrets = [secret, previous_secret].filter_map { |value| value.to_s.presence }.uniq
    end

    def verify!(payload:, signature:)
      raise secret_missing_error if secrets.empty?
      raise signature_invalid_error unless signature.to_s.start_with?(SIGNATURE_PREFIX)

      return true if secrets.any? { |candidate| secure_compare(signature.to_s, expected_signature(candidate, payload)) }

      raise signature_invalid_error
    end

    private

    attr_reader :secrets

    def expected_signature(secret, payload)
      "#{SIGNATURE_PREFIX}#{OpenSSL::HMAC.hexdigest("SHA256", secret, payload.to_s)}"
    end

    def secure_compare(actual, expected)
      actual.bytesize == expected.bytesize &&
        ActiveSupport::SecurityUtils.secure_compare(actual, expected)
    end

    def secret_missing_error
      WebhookError.new(
        code: "github_webhook_secret_not_configured",
        message: "GitHub Webhook secretが設定されていません。",
        safe_detail: "GitHub Webhook secretが設定されていません。",
        http_status: :unauthorized
      )
    end

    def signature_invalid_error
      WebhookError.new(
        code: "github_webhook_signature_invalid",
        message: "GitHub Webhook署名が不正です。",
        safe_detail: "GitHub Webhook署名が不正です。",
        http_status: :unauthorized
      )
    end
  end
end
