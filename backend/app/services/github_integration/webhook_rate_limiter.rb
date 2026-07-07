require "digest"

module GithubIntegration
  class WebhookRateLimiter
    DEFAULT_LIMIT = 120
    DEFAULT_WINDOW_SECONDS = 60
    CACHE_KEY_PREFIX = "github_webhook_rate_limit".freeze

    class << self
      def default_store
        cache = Rails.cache
        return cache unless cache.class.name == "ActiveSupport::Cache::NullStore"

        fallback_store
      end

      def reset_fallback_store!
        @fallback_store = ActiveSupport::Cache::MemoryStore.new
      end

      private

      def fallback_store
        @fallback_store ||= ActiveSupport::Cache::MemoryStore.new
      end
    end

    def initialize(
      store: self.class.default_store,
      limit: ENV.fetch("GITHUB_WEBHOOK_RATE_LIMIT_PER_MINUTE", DEFAULT_LIMIT).to_i,
      window_seconds: DEFAULT_WINDOW_SECONDS,
      clock: -> { Time.current }
    )
      @store = store
      @limit = positive_integer(limit, DEFAULT_LIMIT)
      @window_seconds = positive_integer(window_seconds, DEFAULT_WINDOW_SECONDS)
      @clock = clock
    end

    def check!(remote_ip:)
      count = increment_counter(cache_key(remote_ip))
      return true if count <= limit

      raise WebhookError.new(
        code: "github_webhook_rate_limited",
        message: "GitHub Webhook request rate limit exceeded.",
        safe_detail: "GitHub Webhook requestが一時的に制限されています。",
        http_status: :too_many_requests,
        headers: { "Retry-After" => window_seconds.to_s }
      )
    end

    private

    attr_reader :store, :limit, :window_seconds, :clock

    def cache_key(remote_ip)
      bucket = clock.call.to_i / window_seconds
      remote_ip_digest = Digest::SHA256.hexdigest(remote_ip.to_s.presence || "unknown")
      "#{CACHE_KEY_PREFIX}:#{remote_ip_digest}:#{bucket}"
    end

    def increment_counter(key)
      count = store.read(key).to_i + 1
      store.write(key, count, expires_in: window_seconds + 5)
      count
    end

    def positive_integer(value, fallback)
      integer = Integer(value)
      integer.positive? ? integer : fallback
    rescue ArgumentError, TypeError
      fallback
    end
  end
end
