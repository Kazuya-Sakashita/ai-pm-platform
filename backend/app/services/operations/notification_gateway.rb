require "json"
require "net/http"
require "uri"

module Operations
  class NotificationGateway
    DEFAULT_TIMEOUT_SECONDS = 5

    Result = Struct.new(:success?, :status, :code, :message, :details, keyword_init: true)

    def initialize(
      webhook_url: ENV["OPERATIONS_NOTIFICATION_WEBHOOK_URL"].presence,
      channel: ENV["OPERATIONS_NOTIFICATION_CHANNEL"].presence || "operations",
      timeout_seconds: DEFAULT_TIMEOUT_SECONDS
    )
      @webhook_url = webhook_url
      @channel = channel
      @timeout_seconds = timeout_seconds
    end

    def deliver(event:, payload:)
      return skipped_result("webhook_url_not_configured") if webhook_url.blank?

      uri = webhook_uri
      return failure_result("webhook_url_invalid") unless uri

      response = post_payload(uri, event, payload)
      return success_result(response.code.to_i) if response.code.to_i.between?(200, 299)

      failure_result("notification_http_error", http_status: response.code.to_i)
    rescue JSON::GeneratorError, SocketError, Timeout::Error, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout
      failure_result("notification_delivery_failed")
    end

    private

    attr_reader :webhook_url, :channel, :timeout_seconds

    def webhook_uri
      uri = URI.parse(webhook_url)
      return uri if uri.is_a?(URI::HTTP) && %w[http https].include?(uri.scheme)

      nil
    rescue URI::InvalidURIError
      nil
    end

    def post_payload(uri, event, payload)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(message_payload(event, payload))

      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: timeout_seconds,
        read_timeout: timeout_seconds
      ) do |http|
        http.request(request)
      end
    end

    def message_payload(event, payload)
      {
        text: message_text(event, payload)
      }
    end

    def message_text(event, payload)
      lines = [
        "AI PM operations通知",
        "event: #{event}",
        "channel: #{channel}"
      ]

      payload.each do |key, value|
        lines << "#{key}: #{notification_value(value)}"
      end

      lines.join("\n")
    end

    def notification_value(value)
      case value
      when Array
        value.map { |item| notification_value(item) }.join(" / ")
      when Hash
        value.map { |key, item_value| "#{key}=#{item_value}" }.join(", ")
      else
        value.to_s
      end
    end

    def success_result(http_status)
      Result.new(
        success?: true,
        status: "sent",
        code: "notification_sent",
        message: "運用通知を送信しました。",
        details: { http_status: http_status, channel: channel }
      )
    end

    def skipped_result(code)
      Result.new(
        success?: true,
        status: "skipped",
        code: code,
        message: "運用通知は送信されませんでした。",
        details: { channel: channel }
      )
    end

    def failure_result(code, details = {})
      Result.new(
        success?: false,
        status: "failed",
        code: code,
        message: "運用通知の送信に失敗しました。",
        details: details.merge(channel: channel)
      )
    end
  end
end
