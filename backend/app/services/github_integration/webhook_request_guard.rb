module GithubIntegration
  class WebhookRequestGuard
    DEFAULT_MAX_BYTES = 1_048_576

    def initialize(
      max_bytes: ENV.fetch("GITHUB_WEBHOOK_MAX_BYTES", DEFAULT_MAX_BYTES).to_i,
      rate_limiter: WebhookRateLimiter.new
    )
      @max_bytes = positive_integer(max_bytes, DEFAULT_MAX_BYTES)
      @rate_limiter = rate_limiter
    end

    def check_content_length!(content_length)
      length = integer_or_nil(content_length)
      return true if length.nil? || length <= max_bytes

      raise payload_too_large_error
    end

    def check_rate_limit!(remote_ip:)
      rate_limiter.check!(remote_ip: remote_ip)
    end

    def check_payload_size!(payload)
      return true if payload.to_s.bytesize <= max_bytes

      raise payload_too_large_error
    end

    private

    attr_reader :max_bytes, :rate_limiter

    def payload_too_large_error
      WebhookError.new(
        code: "github_webhook_payload_too_large",
        message: "GitHub Webhook payload is too large.",
        safe_detail: "GitHub Webhook payloadが上限を超えています。",
        http_status: :payload_too_large
      )
    end

    def integer_or_nil(value)
      return if value.blank?

      Integer(value)
    rescue ArgumentError, TypeError
      nil
    end

    def positive_integer(value, fallback)
      integer = Integer(value)
      integer.positive? ? integer : fallback
    rescue ArgumentError, TypeError
      fallback
    end
  end
end
