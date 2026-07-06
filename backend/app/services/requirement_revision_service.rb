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
    :field_changes,
    :approval_reset,
    :stale_issue_draft_ids,
    :stale_open_api_draft_ids,
    keyword_init: true
  )
  PREVIEW_LIMIT = 120
  REDACTED_PREVIEW = "機密情報を含むため非表示".freeze

  def initialize(requirement, attributes)
    @requirement = requirement
    @attributes = attributes.to_h.with_indifferent_access
  end

  def call
    changed_fields = reviewed_changed_fields
    field_changes = build_field_changes(changed_fields)
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
      field_changes: field_changes,
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

  def build_field_changes(changed_fields)
    changed_fields.map do |field|
      {
        field: field,
        before: safe_value_snapshot(requirement.public_send(field)),
        after: safe_value_snapshot(attributes[field])
      }
    end
  end

  def safe_value_snapshot(value)
    items = normalized_items(value)
    scan_result = SensitiveContentScanner.scan(items.join("\n"))
    snapshot = {
      item_count: items.size,
      redacted: scan_result.blocked?
    }

    if scan_result.blocked?
      snapshot[:preview] = REDACTED_PREVIEW
      snapshot[:finding_categories] = scan_result.finding_categories
    elsif items.any?
      snapshot[:preview] = preview_text(items)
    end

    snapshot
  end

  def normalized_items(value)
    raw_items = value.is_a?(Array) ? value : [value]
    raw_items.filter_map do |item|
      text = item.to_s.strip
      text.presence
    end
  end

  def preview_text(items)
    text = items.first(2).join(" / ")
    return text if text.length <= PREVIEW_LIMIT

    "#{text[0, PREVIEW_LIMIT]}..."
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
