require "rails_helper"

RSpec.describe RequirementApprovalGate do
  it "未決事項が残る場合は承認をブロックする" do
    requirement = create(:requirement, open_questions: ["承認者を決める。"])

    result = described_class.new(requirement).call

    expect(result.allowed).to be(false)
    expect(result.code).to eq("review_required")
    expect(result.details).to include(open_questions: ["承認者を決める。"])
  end

  it "要件定義レビューが未解決の場合は承認をブロックする" do
    requirement = create(:requirement, open_questions: [])
    open_review = create(:review, target_type: "requirement", target_id: requirement.id, status: "open")
    action_required_review = create(:review, target_type: "requirement", target_id: requirement.id, status: "action_required")
    create(:review, target_type: "requirement", target_id: requirement.id, status: "resolved")

    result = described_class.new(requirement).call

    expect(result.allowed).to be(false)
    expect(result.code).to eq("review_required")
    expect(result.details.fetch(:review_ids)).to eq([open_review.id, action_required_review.id])
    expect(result.details.fetch(:review_statuses)).to include(open_review.id => "open", action_required_review.id => "action_required")
  end

  it "レビューが解決済みまたはリスク受容済みの場合は承認を許可する" do
    requirement = create(:requirement, open_questions: [])
    create(:review, target_type: "requirement", target_id: requirement.id, status: "resolved")
    create(:review, target_type: "requirement", target_id: requirement.id, status: "accepted_risk")

    result = described_class.new(requirement).call

    expect(result.allowed).to be(true)
  end
end
