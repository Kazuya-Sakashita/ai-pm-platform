module ConversationSummaryGeneration
  class ProviderFactory
    DEFAULT_PROVIDER = "deterministic"

    def self.build
      new.build
    end

    def build
      case configured_provider
      when "deterministic"
        DeterministicProvider.new
      when "openai"
        OpenaiProvider.new
      when "auto"
        openai_configured? ? OpenaiProvider.new : DeterministicProvider.new
      else
        raise ProviderError.new(
          code: "conversation_summary_provider_not_supported",
          message: "Unsupported conversation summary provider: #{configured_provider}",
          safe_detail: "DM整理providerがサポートされていません。",
          http_status: :unprocessable_entity
        )
      end
    end

    private

    def configured_provider
      ENV.fetch("CONVERSATION_SUMMARY_GENERATION_PROVIDER", DEFAULT_PROVIDER).to_s.downcase
    end

    def openai_configured?
      ENV["OPENAI_API_KEY"].present?
    end
  end
end
