require "rails_helper"

RSpec.describe IssueDraftGenerationService do
  it "creates an editable issue draft from an approved requirement" do
    requirement = create(
      :requirement,
      status: "approved",
      open_questions: [],
      goal: "Generate GitHub Issue drafts from approved requirements.",
      functional_requirements: ["FR-001: Generate a GitHub Issue draft."],
      acceptance_criteria: ["Given an approved requirement, when issue draft generation runs, then a draft is stored."]
    )

    issue_draft = described_class.new(requirement).call

    expect(issue_draft).to be_persisted
    expect(issue_draft.status).to eq("draft")
    expect(issue_draft.title).to include("Generate GitHub Issue drafts")
    expect(issue_draft.body).to include("## Functional Requirements")
    expect(issue_draft.body).to include("FR-001: Generate a GitHub Issue draft.")
    expect(issue_draft.acceptance_criteria).to include(/Given an approved requirement/)
    expect(issue_draft.labels).to include("ai-generated", "needs-review")
  end

  it "uses an injected provider" do
    requirement = create(:requirement, status: "approved", open_questions: [])
    provider = instance_double(
      IssueDraftGeneration::DeterministicProvider,
      generate: {
        status: "draft",
        title: "Custom issue draft",
        body: "Custom body",
        acceptance_criteria: ["Custom acceptance criterion"],
        labels: ["custom"]
      }
    )

    issue_draft = described_class.new(requirement, provider: provider).call

    expect(issue_draft.title).to eq("Custom issue draft")
    expect(issue_draft.labels).to eq(["custom"])
  end
end
