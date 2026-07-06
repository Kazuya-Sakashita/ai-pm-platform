require "rails_helper"

RSpec.describe OpenApiDraftReviewGateService do
  let(:open_api_draft) { create(:open_api_draft) }

  it "creates an action-required review when validation fails" do
    result = {
      valid: false,
      errors: [
        { path: "$.paths", code: "empty_paths", severity: "error", message: "At least one path is required." }
      ],
      warnings: []
    }

    review = described_class.new(open_api_draft, result).call

    expect(review).to be_persisted
    expect(review.status).to eq("action_required")
    expect(review.target_type).to eq("openapi_draft")
    expect(review.target_id).to eq(open_api_draft.id)
    expect(review.reviewer_role).to eq("OpenAPI Validator")
    expect(review.framework).to include("OpenAPI Validation", "G-STACK")
    expect(review.improvements.first).to include("$.paths empty_paths")
    expect(review.next_actions.first).to include("Fix $.paths")
    event = review.review_state_events.find_by!(event_type: "review_action_required")
    expect(event).to have_attributes(
      project_id: open_api_draft.requirement.minute.meeting.project.id,
      actor_id: "system",
      from_status: nil,
      to_status: "action_required"
    )
  end

  it "updates the existing validation blocker instead of duplicating it" do
    create(
      :review,
      target_type: "openapi_draft",
      target_id: open_api_draft.id,
      reviewer_role: "OpenAPI Validator",
      status: "action_required"
    )
    result = {
      valid: false,
      errors: [
        { path: "$.info.version", code: "missing_info_version", severity: "error", message: "Info version is required." }
      ],
      warnings: []
    }

    review = described_class.new(open_api_draft, result).call

    expect(Review.where(target_type: "openapi_draft", target_id: open_api_draft.id, reviewer_role: "OpenAPI Validator").count).to eq(1)
    expect(review.status).to eq("action_required")
    expect(review.improvements.first).to include("$.info.version missing_info_version")
  end

  it "resolves an existing validation blocker when validation passes" do
    review = create(
      :review,
      target_type: "openapi_draft",
      target_id: open_api_draft.id,
      reviewer_role: "OpenAPI Validator",
      status: "action_required"
    )
    result = { valid: true, errors: [], warnings: [] }

    resolved_review = described_class.new(open_api_draft, result).call

    expect(resolved_review.id).to eq(review.id)
    expect(resolved_review.status).to eq("resolved")
    expect(resolved_review.resolution_note).to include("OpenAPI validation passed")
    event = review.review_state_events.find_by!(event_type: "review_resolved")
    expect(event).to have_attributes(
      actor_id: "system",
      from_status: "action_required",
      to_status: "resolved",
      reason_code: "openapi_validation_passed"
    )
  end

  it "does not overwrite an accepted risk when validation passes" do
    create(
      :review,
      target_type: "openapi_draft",
      target_id: open_api_draft.id,
      reviewer_role: "OpenAPI Validator",
      status: "accepted_risk",
      accepted_risk: {
        reason: "Temporary exception",
        residual_risk: "Manual API review required",
        expires_at: 1.week.from_now.iso8601,
        linked_issue_number: "ISSUE-004",
        accepted_at: Time.current.iso8601
      }
    )
    result = { valid: true, errors: [], warnings: [] }

    review = described_class.new(open_api_draft, result).call

    expect(review).to be_nil
    expect(Review.where(target_type: "openapi_draft", target_id: open_api_draft.id, reviewer_role: "OpenAPI Validator").first.status).to eq("accepted_risk")
  end
end
