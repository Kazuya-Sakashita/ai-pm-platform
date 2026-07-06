class OpenApiDraftReviewGateService
  REVIEWER_ROLE = "OpenAPI Validator"
  FRAMEWORK = ["OpenAPI Validation", "G-STACK", "ISO25010"].freeze

  def initialize(open_api_draft, validation_result)
    @open_api_draft = open_api_draft
    @validation_result = validation_result
  end

  def call
    validation_result.fetch(:valid) ? resolve_blocker : upsert_blocker
  end

  private

  attr_reader :open_api_draft, :validation_result

  def upsert_blocker
    review = validation_review || Review.new(
      target_type: "openapi_draft",
      target_id: open_api_draft.id,
      reviewer_role: REVIEWER_ROLE
    )

    transition_service.mark_action_required!(
      review: review,
      reason_code: "openapi_validation_failed",
      reason_text: validation_messages.first,
      attributes: {
        framework: FRAMEWORK,
        positives: ["OpenAPI validation ran and produced actionable findings."],
        improvements: validation_messages.presence || ["OpenAPI draft is invalid and must be corrected before implementation."],
        priority: ["P0: Fix OpenAPI validation errors before implementation or publish."],
        next_actions: next_actions,
        issue_numbers: ["ISSUE-004"],
        resolution_note: nil
      }
    )

    review
  end

  def resolve_blocker
    review = validation_review
    return unless review && review.status != "accepted_risk"

    transition_service.resolve!(
      review: review,
      resolution_note: "OpenAPI validation passed at #{Time.current.iso8601}.",
      reason_code: "openapi_validation_passed",
      issue_numbers: ["ISSUE-004"]
    )

    review.update!(
      framework: FRAMEWORK,
      positives: ["OpenAPI validation passed."],
      improvements: ["No active OpenAPI validation blocker remains."],
      priority: ["P0: Keep OpenAPI validation green before implementation or publish."],
      next_actions: ["Proceed to human API review or GitHub Issue publication gate."],
      issue_numbers: ["ISSUE-004"]
    )

    review
  end

  def transition_service
    @transition_service ||= ReviewTransitionService.new(
      project: open_api_draft.requirement.minute.meeting.project,
      actor_id: "system",
      sensitive_handling: :redact
    )
  end

  def validation_review
    @validation_review ||= Review.where(
      target_type: "openapi_draft",
      target_id: open_api_draft.id,
      reviewer_role: REVIEWER_ROLE
    ).order(created_at: :desc).first
  end

  def validation_messages
    validation_result.fetch(:errors).map do |issue|
      "#{issue.fetch(:path)} #{issue.fetch(:code, issue.fetch(:severity))}: #{issue.fetch(:message)}"
    end
  end

  def next_actions
    validation_result.fetch(:errors).map do |issue|
      "Fix #{issue.fetch(:path)}: #{issue.fetch(:message)}"
    end.presence || ["Fix OpenAPI validation errors and rerun validation."]
  end
end
