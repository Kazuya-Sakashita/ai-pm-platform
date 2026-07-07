module GithubIntegration
  class WebhookError < StandardError
    attr_reader :code, :safe_detail, :http_status, :headers

    def initialize(code:, message:, safe_detail:, http_status: :unprocessable_entity, headers: {})
      super(message)
      @code = code
      @safe_detail = safe_detail
      @http_status = http_status
      @headers = headers
    end
  end
end
