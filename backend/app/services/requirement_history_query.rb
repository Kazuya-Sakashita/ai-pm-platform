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
    (audit_events + review_events).sort_by { |event| event[:occurred_at].to_s }.reverse
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

  def review_events
    Review.where(target_type: "requirement", target_id: requirement.id).flat_map do |review|
      events = [review_event(review, "review_requested", "レビューを依頼", review.created_at, review_status: "open")]

      if review.status == "resolved"
        events << review_event(review, "review_resolved", "レビューを解決", review.updated_at, review_status: "resolved")
      elsif review.status == "accepted_risk"
        events << review_event(review, "review_risk_accepted", "リスク受容を記録", review.updated_at, review_status: "accepted_risk")
      end

      events
    end
  end

  def review_event(review, event_type, title, occurred_at, review_status:)
    {
      id: "review-#{review.id}-#{event_type}",
      source_type: "review",
      event_type: event_type,
      title: title,
      reviewer_role: review.reviewer_role,
      review_status: review_status,
      occurred_at: iso_time(occurred_at)
    }
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
