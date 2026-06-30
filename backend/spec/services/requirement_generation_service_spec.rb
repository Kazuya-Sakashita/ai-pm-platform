require "rails_helper"

RSpec.describe RequirementGenerationService do
  it "creates an editable requirement draft from approved minutes" do
    minutes = create(
      :minute,
      status: "approved",
      summary: "Review gates must be enforced.",
      decisions: [{ "text" => "Generate requirements only after approval." }],
      open_questions: ["Who owns requirement review?"],
      action_items: [{ "text" => "Create a requirement editor.", "status" => "open" }]
    )

    requirement = described_class.new(minutes).call

    expect(requirement).to be_persisted
    expect(requirement.status).to eq("generated")
    expect(requirement.background).to include("Review gates")
    expect(requirement.goal).to include("Generate requirements only after approval")
    expect(requirement.functional_requirements).to include(/Generate requirements only after approval/)
    expect(requirement.acceptance_criteria.first).to include("Given approved minutes")
    expect(requirement.open_questions).to include("Who owns requirement review?")
    expect(requirement.generated_by_model).to eq("deterministic-requirements-placeholder-v1")
  end

  it "uses an injected provider" do
    minutes = create(:minute, status: "approved")
    provider = instance_double(
      RequirementGeneration::DeterministicProvider,
      generate: {
        status: "generated",
        background: "Custom background",
        goal: "Custom goal",
        functional_requirements: ["Custom functional requirement"],
        acceptance_criteria: ["Custom acceptance criterion"],
        generated_by_model: "provider-test"
      }
    )

    requirement = described_class.new(minutes, provider: provider).call

    expect(requirement.background).to eq("Custom background")
    expect(requirement.functional_requirements).to eq(["Custom functional requirement"])
    expect(requirement.generated_by_model).to eq("provider-test")
  end
end
