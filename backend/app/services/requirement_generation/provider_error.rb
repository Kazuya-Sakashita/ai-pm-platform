module RequirementGeneration
  class ProviderError < StandardError
    attr_reader :code, :safe_detail, :http_status, :request_id

    def initialize(code:, message:, safe_detail:, http_status: :bad_gateway, request_id: nil)
      super(message)
      @code = code
      @safe_detail = safe_detail
      @http_status = http_status
      @request_id = request_id
    end
  end
end
