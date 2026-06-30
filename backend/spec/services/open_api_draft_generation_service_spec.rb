require "rails_helper"

RSpec.describe OpenApiDraftGenerationService do
  it "creates an editable OpenAPI draft from an approved requirement" do
    requirement = create(
      :requirement,
      status: "approved",
      open_questions: [],
      goal: "Expose approved requirements as implementation-ready API drafts.",
      functional_requirements: ["FR-001: Create OpenAPI draft from approved requirement."],
      acceptance_criteria: ["Given an approved requirement, then an OpenAPI draft is stored."]
    )

    open_api_draft = described_class.new(requirement).call

    expect(open_api_draft).to be_persisted
    expect(open_api_draft.status).to eq("draft")
    expect(open_api_draft.title).to include("Expose approved requirements")
    expect(open_api_draft.content).to include("openapi: 3.1.0")
    expect(open_api_draft.content).to include("paths:")
    expect(open_api_draft.validation_errors).to eq([])
    expect(open_api_draft.generated_by_model).to eq("deterministic-openapi-draft-placeholder-v1")
  end

  it "uses an injected provider" do
    requirement = create(:requirement, status: "approved", open_questions: [])
    provider = instance_double(
      OpenApiDraftGeneration::DeterministicProvider,
      generate: {
        status: "valid",
        title: "Custom OpenAPI draft",
        content: "openapi: 3.1.0\ninfo:\n  title: Custom\n  version: 0.1.0\npaths: {}\n",
        validation_errors: [],
        generated_by_model: "provider-test"
      }
    )

    open_api_draft = described_class.new(requirement, provider: provider).call

    expect(open_api_draft.status).to eq("valid")
    expect(open_api_draft.title).to eq("Custom OpenAPI draft")
    expect(open_api_draft.content).to include("title: Custom")
    expect(open_api_draft.generated_by_model).to eq("provider-test")
  end
end
