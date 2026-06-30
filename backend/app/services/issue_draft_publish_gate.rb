class IssueDraftPublishGate
  Result = Struct.new(:allowed, :code, :message, :details, keyword_init: true)

  def initialize(issue_draft)
    @issue_draft = issue_draft
  end

  def call
    return blocked("issue_draft_review_required", "Issue draft must be approved before publishing.", issue_draft_status: issue_draft.status) unless issue_draft.status == "approved"

    open_api_draft = latest_open_api_draft
    return blocked("openapi_draft_required", "Valid OpenAPI draft is required before publishing.", openapi_draft_status: nil) unless open_api_draft
    return blocked("openapi_validation_required", "OpenAPI draft must be valid before publishing.", openapi_draft_id: open_api_draft.id, openapi_draft_status: open_api_draft.status) unless %w[valid approved].include?(open_api_draft.status)

    blocker = validation_blocker(open_api_draft)
    return blocked("openapi_review_blocker", "OpenAPI validation blocker must be resolved before publishing.", openapi_draft_id: open_api_draft.id, review_id: blocker.id, review_status: blocker.status) if blocker

    Result.new(allowed: true, details: { openapi_draft_id: open_api_draft.id })
  end

  private

  attr_reader :issue_draft

  def latest_open_api_draft
    @latest_open_api_draft ||= issue_draft.requirement.open_api_drafts.order(created_at: :desc).first
  end

  def validation_blocker(open_api_draft)
    Review.where(
      target_type: "openapi_draft",
      target_id: open_api_draft.id,
      reviewer_role: "OpenAPI Validator",
      status: "action_required"
    ).order(created_at: :desc).first
  end

  def blocked(code, message, details)
    Result.new(allowed: false, code: code, message: message, details: details)
  end
end
