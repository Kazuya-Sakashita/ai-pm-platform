require "rails_helper"

RSpec.describe RequirementRevisionService do
  it "承認済みRequirementのレビュー対象フィールドが変わる場合は承認状態を差し戻す" do
    requirement = create(
      :requirement,
      status: "approved",
      open_questions: [],
      approved_at: 1.hour.ago,
      approved_by: "reviewer-actor",
      approval_note: "承認済み"
    )

    result = described_class.new(requirement, { goal: "変更後の目的" }).call

    expect(result.approval_reset).to be(true)
    expect(result.changed_fields).to eq(["goal"])
    expect(requirement.reload.status).to eq("needs_changes")
    expect(requirement.goal).to eq("変更後の目的")
    expect(requirement.approved_at).to be_nil
    expect(requirement.approved_by).to be_nil
    expect(requirement.approval_note).to be_nil
  end

  it "承認状態を差し戻す場合は下流Draftをstaleにする" do
    requirement = create(
      :requirement,
      status: "approved",
      open_questions: [],
      approved_at: 1.hour.ago,
      approved_by: "reviewer-actor",
      approval_note: "承認済み"
    )
    issue_draft = create(:issue_draft, requirement: requirement, status: "approved")
    published_issue_draft = create(:issue_draft, requirement: requirement, status: "published")
    already_stale_issue_draft = create(:issue_draft, requirement: requirement, status: "stale")
    open_api_draft = create(:open_api_draft, requirement: requirement, status: "approved")
    valid_open_api_draft = create(:open_api_draft, requirement: requirement, status: "valid")
    already_stale_open_api_draft = create(:open_api_draft, requirement: requirement, status: "stale")

    result = described_class.new(requirement, { goal: "下流成果物を再確認する目的" }).call

    expect(result.approval_reset).to be(true)
    expect(result.stale_issue_draft_ids).to match_array([issue_draft.id, published_issue_draft.id])
    expect(result.stale_open_api_draft_ids).to match_array([open_api_draft.id, valid_open_api_draft.id])
    expect(issue_draft.reload.status).to eq("stale")
    expect(published_issue_draft.reload.status).to eq("stale")
    expect(already_stale_issue_draft.reload.status).to eq("stale")
    expect(open_api_draft.reload.status).to eq("stale")
    expect(valid_open_api_draft.reload.status).to eq("stale")
    expect(already_stale_open_api_draft.reload.status).to eq("stale")
  end

  it "承認済みRequirementでも内容差分がない場合は承認状態を維持する" do
    approved_at = 1.hour.ago
    requirement = create(
      :requirement,
      status: "approved",
      open_questions: [],
      approved_at: approved_at,
      approved_by: "reviewer-actor",
      approval_note: "承認済み"
    )
    issue_draft = create(:issue_draft, requirement: requirement, status: "approved")
    open_api_draft = create(:open_api_draft, requirement: requirement, status: "approved")

    result = described_class.new(requirement, { goal: requirement.goal }).call

    expect(result.approval_reset).to be(false)
    expect(result.changed_fields).to eq([])
    expect(result.stale_issue_draft_ids).to eq([])
    expect(result.stale_open_api_draft_ids).to eq([])
    expect(requirement.reload.status).to eq("approved")
    expect(requirement.approved_by).to eq("reviewer-actor")
    expect(requirement.approval_note).to eq("承認済み")
    expect(issue_draft.reload.status).to eq("approved")
    expect(open_api_draft.reload.status).to eq("approved")
  end
end
