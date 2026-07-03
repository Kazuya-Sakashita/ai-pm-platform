# frozen_string_literal: true

class IssueDraftReconciliationHistorySerializer
  DEFAULT_LIMIT = 5
  RETRY_APPROVED_ACTION = "issue_draft.github_publish_retry_approved"

  def initialize(issue_draft, limit: DEFAULT_LIMIT)
    @issue_draft = issue_draft
    @limit = limit
  end

  def as_json
    attempts.map do |attempt|
      retry_metadata = retry_metadata_by_attempt_id[attempt.id] || {}
      {
        attempt_id: attempt.id,
        status: attempt.status,
        safe_error_code: attempt.safe_error_code,
        safe_error_detail: safe_error_detail(attempt),
        github_repository: attempt.github_repository,
        github_issue_number: attempt.github_issue_number,
        github_issue_url: attempt.github_issue_url,
        reconciliation_retry_count: attempt.reconciliation_retry_count,
        next_reconciliation_retry_at: iso_time(attempt.next_reconciliation_retry_at),
        reconciliation_cooldown_active: attempt.reconciliation_cooldown_active?,
        retry_approver: retry_metadata["resolution_approver"],
        retry_reason_template: retry_metadata["retry_reason_template"],
        retry_reason_template_label: retry_metadata["retry_reason_template_label"],
        started_at: iso_time(attempt.started_at),
        github_created_at: iso_time(attempt.github_created_at),
        completed_at: iso_time(attempt.completed_at),
        reconciled_at: iso_time(attempt.reconciled_at)
      }.compact
    end
  end

  private

  attr_reader :issue_draft, :limit

  def attempts
    @attempts ||= issue_draft.github_issue_publish_attempts.order(created_at: :desc).limit(limit).to_a
  end

  def retry_metadata_by_attempt_id
    return {} if attempts.empty?

    attempt_ids = attempts.map(&:id)
    AuditLog.where(
      target_type: "issue_draft",
      target_id: issue_draft.id,
      action: RETRY_APPROVED_ACTION
    ).order(created_at: :desc).each_with_object({}) do |audit_log, metadata_by_attempt_id|
      attempt_id = audit_log.metadata["attempt_id"]
      next unless attempt_ids.include?(attempt_id)

      metadata_by_attempt_id[attempt_id] ||= audit_log.metadata
    end
  end

  def safe_error_detail(attempt)
    return if attempt.status == "retry_approved"

    attempt.safe_error_detail
  end

  def iso_time(value)
    value&.iso8601
  end
end
