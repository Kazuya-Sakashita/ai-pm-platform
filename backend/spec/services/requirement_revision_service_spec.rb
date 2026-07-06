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

    result = described_class.new(requirement, { goal: requirement.goal }).call

    expect(result.approval_reset).to be(false)
    expect(result.changed_fields).to eq([])
    expect(requirement.reload.status).to eq("approved")
    expect(requirement.approved_by).to eq("reviewer-actor")
    expect(requirement.approval_note).to eq("承認済み")
  end
end
