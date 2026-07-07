require "openssl"

module GithubIntegration
  class WebhookSignatureVerifier
    SIGNATURE_PREFIX = "sha256=".freeze

    def initialize(secret: ENV["GITHUB_WEBHOOK_SECRET"])
      @secret = secret.to_s
    end

    def verify!(payload:, signature:)
      raise secret_missing_error if secret.blank?
      raise signature_invalid_error unless signature.to_s.start_with?(SIGNATURE_PREFIX)

      expected = "#{SIGNATURE_PREFIX}#{OpenSSL::HMAC.hexdigest("SHA256", secret, payload.to_s)}"
      return true if secure_compare(signature.to_s, expected)

      raise signature_invalid_error
    end

    private

    attr_reader :secret

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
