class MinutesGenerationService
  DEFAULT_PROVIDER = "auto"

  def initialize(meeting, provider: nil)
    @meeting = meeting
    @provider = provider || default_provider
  end

  def call
    attributes = provider.generate(meeting)

    meeting.minutes.create!(
      status: attributes.fetch(:status, "generated"),
      summary: attributes.fetch(:summary),
      decisions: attributes.fetch(:decisions, []),
      open_questions: attributes.fetch(:open_questions, []),
      action_items: attributes.fetch(:action_items, []),
      generated_by_model: attributes.fetch(:generated_by_model)
    )
  end

  private

  attr_reader :meeting, :provider

  def default_provider
    case configured_provider
    when "auto"
      openai_configured? ? MinutesGeneration::OpenaiProvider.new : MinutesGeneration::DeterministicProvider.new
    when "openai"
      MinutesGeneration::OpenaiProvider.new
    when "deterministic"
      MinutesGeneration::DeterministicProvider.new
    else
      raise MinutesGeneration::ProviderError.new(
        code: "minutes_provider_not_supported",
        message: "Unsupported minutes generation provider: #{configured_provider}",
        safe_detail: "Minutes generation provider is not supported.",
        http_status: :unprocessable_entity
      )
    end
  end

  def configured_provider
    ENV.fetch("MINUTES_GENERATION_PROVIDER", DEFAULT_PROVIDER).to_s.downcase
  end

  def openai_configured?
    ENV["OPENAI_API_KEY"].present?
  end
end
