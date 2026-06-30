class RequirementGenerationService
  def initialize(minutes, provider: RequirementGeneration::DeterministicProvider.new)
    @minutes = minutes
    @provider = provider
  end

  def call
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

  attr_reader :minutes, :provider
end
