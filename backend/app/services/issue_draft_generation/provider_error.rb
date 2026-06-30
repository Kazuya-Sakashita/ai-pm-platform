module IssueDraftGeneration
  class ProviderError < StandardError
    attr_reader :code, :safe_detail, :http_status

    def initialize(code:, message:, safe_detail:, http_status: :bad_gateway)
      super(message)
      @code = code
      @safe_detail = safe_detail
      @http_status = http_status
    end
  end
end
