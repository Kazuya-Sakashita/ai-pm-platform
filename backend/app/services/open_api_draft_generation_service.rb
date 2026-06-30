class OpenApiDraftGenerationService
  def initialize(requirement, provider: OpenApiDraftGeneration::DeterministicProvider.new)
    @requirement = requirement
    @provider = provider
  end

  def call
    attributes = provider.generate(requirement)

    requirement.open_api_drafts.create!(
      status: attributes.fetch(:status, "draft"),
      title: attributes.fetch(:title),
      content: attributes.fetch(:content),
      validation_errors: attributes.fetch(:validation_errors, []),
      generated_by_model: attributes.fetch(:generated_by_model)
    )
  end

  private

  attr_reader :requirement, :provider
end
