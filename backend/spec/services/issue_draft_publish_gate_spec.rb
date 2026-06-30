require "rails_helper"

RSpec.describe IssueDraftPublishGate do
  it "allows an approved issue draft when the latest OpenAPI draft is valid and unblocked" do
    issue_draft = create(:issue_draft, status: "approved")
    open_api_draft = create(:open_api_draft, requirement: issue_draft.requirement, status: "valid")

    result = described_class.new(issue_draft).call

    expect(result.allowed).to be(true)
    expect(result.details).to include(openapi_draft_id: open_api_draft.id)
  end

  it "blocks unapproved issue drafts" do
    issue_draft = create(:issue_draft, status: "draft")
    create(:open_api_draft, requirement: issue_draft.requirement, status: "valid")

    result = described_class.new(issue_draft).call

    expect(result.allowed).to be(false)
    expect(result.code).to eq("issue_draft_review_required")
    expect(result.details).to include(issue_draft_status: "draft")
  end

  it "blocks when the latest OpenAPI draft is invalid" do
    issue_draft = create(:issue_draft, status: "approved")
    open_api_draft = create(:open_api_draft, requirement: issue_draft.requirement, status: "invalid")

    result = described_class.new(issue_draft).call

    expect(result.allowed).to be(false)
    expect(result.code).to eq("openapi_validation_required")
    expect(result.details).to include(openapi_draft_id: open_api_draft.id, openapi_draft_status: "invalid")
  end

  it "blocks when an OpenAPI validation review blocker is action-required" do
    issue_draft = create(:issue_draft, status: "approved")
    open_api_draft = create(:open_api_draft, requirement: issue_draft.requirement, status: "valid")
    review = create(
      :review,
      target_type: "openapi_draft",
      target_id: open_api_draft.id,
      reviewer_role: "OpenAPI Validator",
      status: "action_required"
    )

    result = described_class.new(issue_draft).call

    expect(result.allowed).to be(false)
    expect(result.code).to eq("openapi_review_blocker")
    expect(result.details).to include(review_id: review.id, review_status: "action_required")
  end
end
