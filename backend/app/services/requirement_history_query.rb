class RequirementHistoryQuery
  AUDIT_EVENT_DETAILS = {
    "requirement.generated" => ["generated", "要件定義を生成"],
    "requirement.updated" => ["updated", "要件定義を更新"],
    "requirement.approved" => ["approved", "要件定義を承認"]
  }.freeze

  def initialize(requirement)
    @requirement = requirement
  end

  def call
    (audit_events + review_state_events).sort_by { |event| event[:occurred_at].to_s }.reverse
  end

  private

  attr_reader :requirement

  def audit_events
    requirement_project.audit_logs
                       .where(target_type: "requirement", target_id: requirement.id, action: AUDIT_EVENT_DETAILS.keys)
                       .map { |log| audit_event(log) }
  end

  def audit_event(log)
    event_type, title = AUDIT_EVENT_DETAILS.fetch(log.action)
    metadata = log.metadata || {}

    {
      id: log.id,
      source_type: "audit_log",
      event_type: event_type,
      title: title,
      action: log.action,
      actor_id: log.actor_id,
      summary: log.summary,
      changed_fields: array_metadata(metadata, "changed_fields"),
      changes: array_metadata(metadata, "field_changes"),
      approval_reset: metadata_value(metadata, "approval_reset"),
      stale_issue_draft_count: metadata_value(metadata, "stale_issue_draft_count"),
      stale_open_api_draft_count: metadata_value(metadata, "stale_open_api_draft_count"),
      occurred_at: iso_time(log.created_at)
    }.compact
  end

  def review_state_events
    ReviewStateEvent.where(target_type: "requirement", target_id: requirement.id)
                    .includes(:review)
                    .map { |event| review_event(event) }
  end

  def review_event(event)
    {
      id: event.id,
      source_type: "review_event",
      event_type: event.event_type,
      title: review_event_title(event.event_type),
      actor_id: event.actor_id,
      review_id: event.review_id,
      reviewer_role: event.review.reviewer_role,
      review_status: event.to_status,
      from_status: event.from_status,
      to_status: event.to_status,
      reason_code: event.reason_code,
      reason_summary: event.reason_summary,
      issue_numbers: event.issue_numbers,
      occurred_at: iso_time(event.occurred_at)
    }.compact
  end

  def review_event_title(event_type)
    {
      "review_requested" => "レビューを依頼",
      "review_action_required" => "レビュー対応が必要",
      "review_resolved" => "レビューを解決",
      "review_risk_accepted" => "リスク受容を記録",
      "review_reopened" => "レビューを再オープン"
    }.fetch(event_type, event_type)
  end

  def requirement_project
    requirement.minute.meeting.project
  end

  def array_metadata(metadata, key)
    value = metadata_value(metadata, key)
    value.is_a?(Array) ? value : []
  end

  def metadata_value(metadata, key)
    return metadata[key] if metadata.key?(key)

    metadata[key.to_sym]
  end

  def iso_time(value)
    value&.iso8601
  end
end
