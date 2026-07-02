class IssueDraft < ApplicationRecord
  STATUSES = %w[draft in_review needs_changes approved publishing published publish_failed].freeze

  belongs_to :requirement
  has_many :github_issue_publish_attempts, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
  validates :title, presence: true, length: { maximum: 160 }
  validates :body, presence: true
  validates :acceptance_criteria, :labels, presence: true

  before_validation :set_defaults

  def api_json
    {
      id: id,
      requirement_id: requirement_id,
      status: status,
      title: title,
      body: body,
      acceptance_criteria: acceptance_criteria,
      labels: labels,
      github_issue_number: github_issue_number,
      github_issue_url: github_issue_url,
      publish_error: publish_error,
      github_reconciliation: github_reconciliation_api_json,
      created_at: iso_time(created_at),
      updated_at: iso_time(updated_at)
    }.compact
  end

  private

  def github_reconciliation_api_json
    attempt = github_issue_publish_attempts
              .where(status: "reconciliation_required")
              .order(created_at: :desc)
              .first
    return { pending: false } unless attempt

    {
      pending: true,
      attempt_id: attempt.id,
      status: attempt.status,
      safe_error_code: attempt.safe_error_code,
      safe_error_detail: attempt.safe_error_detail,
      github_issue_number: attempt.github_issue_number,
      github_issue_url: attempt.github_issue_url,
      reconciliation_retry_count: attempt.reconciliation_retry_count,
      next_reconciliation_retry_at: iso_time(attempt.next_reconciliation_retry_at),
      reconciliation_cooldown_active: attempt.reconciliation_cooldown_active?,
      completed_at: iso_time(attempt.completed_at)
    }.compact
  end

  def set_defaults
    self.status ||= "draft"
    self.acceptance_criteria ||= []
    self.labels ||= []
  end
end
