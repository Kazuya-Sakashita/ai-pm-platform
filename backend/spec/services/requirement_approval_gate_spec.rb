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

  it "期限内のリスク受容済みレビューは承認を許可する" do
    requirement = create(:requirement, open_questions: [])
    create(:review, target_type: "requirement", target_id: requirement.id, status: "resolved")
    create(
      :review,
      target_type: "requirement",
      target_id: requirement.id,
      status: "accepted_risk",
      accepted_risk: {
        "reason" => "MVPでは許容する。",
        "residual_risk" => "後続Issueで対応する。",
        "approved_by" => "Kazuya Reviewer",
        "expires_at" => 1.week.from_now.iso8601,
        "linked_issue_number" => "#3",
        "accepted_at" => Time.current.iso8601
      }
    )

    result = described_class.new(requirement).call

    expect(result.allowed).to be(true)
  end

  it "期限切れのリスク受容済みレビューは承認をブロックする" do
    requirement = create(:requirement, open_questions: [])
    review = create(
      :review,
      target_type: "requirement",
      target_id: requirement.id,
      status: "accepted_risk",
      accepted_risk: {
        "reason" => "一時的に許容する。",
        "residual_risk" => "承認期限後は再レビューする。",
        "approved_by" => "Kazuya Reviewer",
        "expires_at" => 1.day.ago.iso8601,
        "linked_issue_number" => "#3",
        "accepted_at" => 2.days.ago.iso8601
      }
    )

    result = described_class.new(requirement).call

    expect(result.allowed).to be(false)
    expect(result.code).to eq("review_required")
    expect(result.details.fetch(:expired_accepted_risk_review_ids)).to eq([review.id])
    expect(result.details.fetch(:accepted_risk_expires_at)).to include(review.id => review.accepted_risk.fetch("expires_at"))
  end

  it "期限がないリスク受容済みレビューは承認をブロックする" do
    requirement = create(:requirement, open_questions: [])
    review = create(:review, target_type: "requirement", target_id: requirement.id, status: "accepted_risk", accepted_risk: {})

    result = described_class.new(requirement).call

    expect(result.allowed).to be(false)
    expect(result.details.fetch(:expired_accepted_risk_review_ids)).to eq([review.id])
  end
end
