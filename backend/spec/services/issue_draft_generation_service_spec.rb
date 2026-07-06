require "rails_helper"

RSpec.describe IssueDraftGenerationService do
  it "creates an editable issue draft from an approved requirement" do
    requirement = create(
      :requirement,
      status: "approved",
      open_questions: [],
      goal: "承認済み要件からGitHub Issueドラフトを生成する。",
      functional_requirements: ["FR-001: GitHub Issueドラフトを生成する。"],
      acceptance_criteria: ["承認済み要件からIssueドラフトを生成したとき、編集可能なドラフトが保存されている。"]
    )

    issue_draft = described_class.new(requirement).call

    expect(issue_draft).to be_persisted
    expect(issue_draft.status).to eq("draft")
    expect(issue_draft.title).to include("GitHub Issueドラフトを生成")
    expect(issue_draft.body).to include("## 機能要件")
    expect(issue_draft.body).to include("FR-001: GitHub Issueドラフトを生成する。")
    expect(issue_draft.body).to include("## レビューゲート")
    expect(issue_draft.acceptance_criteria).to include(/承認済み要件/)
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
