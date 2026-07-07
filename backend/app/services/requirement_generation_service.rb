class RequirementGenerationService
  def initialize(minutes, provider: nil)
    @minutes = minutes
    @provider = provider
  end

  def call
    block_sensitive_content!
    attributes = provider.generate(minutes)

    minutes.requirements.create!(
      status: attributes.fetch(:status, "generated"),
      background: attributes.fetch(:background),
      goal: attributes.fetch(:goal),
      user_stories: attributes.fetch(:user_stories, []),
      functional_requirements: attributes.fetch(:functional_requirements, []),
      non_functional_requirements: attributes.fetch(:non_functional_requirements, []),
      acceptance_criteria: attributes.fetch(:acceptance_criteria, []),
      out_of_scope: attributes.fetch(:out_of_scope, []),
      open_questions: attributes.fetch(:open_questions, []),
      risks: attributes.fetch(:risks, []),
      generated_by_model: attributes.fetch(:generated_by_model)
    )
  end

  private

  attr_reader :minutes

  def provider
    @provider ||= RequirementGeneration::ProviderFactory.build
  end

  def block_sensitive_content!
    result = SensitiveContentScanner.scan(requirement_source_text)
    return unless result.blocked?

    raise RequirementGeneration::ProviderError.new(
      code: "sensitive_content_blocked",
      message: "Requirement生成入力にブロック対象の機密情報が含まれています: #{result.finding_types.join(', ')}",
      safe_detail: "要件定義生成に使う議事録に機密性の高い内容が含まれています。AI生成前にレビューしてください。",
      http_status: :unprocessable_entity
    )
  end

  def requirement_source_text
    [
      minutes.summary,
      normalized_items(minutes.decisions),
      minutes.open_questions,
      normalized_items(minutes.action_items)
    ].flatten.compact.join("\n")
  end

  def normalized_items(items)
    Array(items).map do |item|
      item.is_a?(Hash) ? item["text"] || item[:text] : item
    end
  end
end
