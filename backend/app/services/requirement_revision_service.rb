class RequirementRevisionService
  REVIEWED_FIELDS = %w[
    background
    goal
    user_stories
    functional_requirements
    non_functional_requirements
    acceptance_criteria
    out_of_scope
    open_questions
    risks
  ].freeze

  Result = Struct.new(
    :requirement,
    :changed_fields,
    :approval_reset,
    :stale_issue_draft_ids,
    :stale_open_api_draft_ids,
    keyword_init: true
  )

  def initialize(requirement, attributes)
    @requirement = requirement
    @attributes = attributes.to_h.with_indifferent_access
  end

  def call
    changed_fields = reviewed_changed_fields
    approval_reset = requirement.status == "approved" && changed_fields.any?
    update_attributes = attributes.dup
    stale_issue_draft_ids = []
    stale_open_api_draft_ids = []

    if approval_reset
      update_attributes[:status] = "needs_changes"
      update_attributes[:approved_at] = nil
      update_attributes[:approved_by] = nil
      update_attributes[:approval_note] = nil
    end

    Requirement.transaction do
      requirement.update!(update_attributes)

      if approval_reset
        stale_issue_draft_ids = stale_issue_drafts
        stale_open_api_draft_ids = stale_open_api_drafts
      end
    end

    Result.new(
      requirement: requirement,
      changed_fields: changed_fields,
      approval_reset: approval_reset,
      stale_issue_draft_ids: stale_issue_draft_ids,
      stale_open_api_draft_ids: stale_open_api_draft_ids
    )
  end

  private

  attr_reader :requirement, :attributes

  def reviewed_changed_fields
    REVIEWED_FIELDS.select do |field|
      attributes.key?(field) && requirement.public_send(field) != attributes[field]
    end
  end

  def stale_issue_drafts
    scope = stale_scope(requirement.issue_drafts)
    ids = scope.pluck(:id)
    scope.update_all(status: "stale", updated_at: Time.current) if ids.any?
    ids
  end

  def stale_open_api_drafts
    scope = stale_scope(requirement.open_api_drafts)
    ids = scope.pluck(:id)
    scope.update_all(status: "stale", updated_at: Time.current) if ids.any?
    ids
  end

  def stale_scope(scope)
    scope.where.not(status: "stale")
  end
end
