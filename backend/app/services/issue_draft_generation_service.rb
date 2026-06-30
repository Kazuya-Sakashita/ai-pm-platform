class IssueDraftGenerationService
  def initialize(requirement, provider: IssueDraftGeneration::DeterministicProvider.new)
    @requirement = requirement
    @provider = provider
  end

  def call
    attributes = provider.generate(requirement)

    requirement.issue_drafts.create!(
      status: attributes.fetch(:status, "draft"),
      title: attributes.fetch(:title),
      body: attributes.fetch(:body),
      acceptance_criteria: attributes.fetch(:acceptance_criteria, []),
      labels: attributes.fetch(:labels, [])
    )
  end

  private

  attr_reader :requirement, :provider
end
