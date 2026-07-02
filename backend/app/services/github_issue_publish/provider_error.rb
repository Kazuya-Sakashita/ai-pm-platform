module GithubIssuePublish
  class ProviderError < StandardError
    attr_reader :code, :safe_detail, :http_status, :safe_metadata

    def initialize(code:, message:, safe_detail:, http_status: :bad_gateway, safe_metadata: {})
      super(message)
      @code = code
      @safe_detail = safe_detail
      @http_status = http_status
      @safe_metadata = safe_metadata.compact
    end
  end
end
