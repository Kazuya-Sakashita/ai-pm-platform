class IssueDraft < ApplicationRecord
  STATUSES = %w[draft in_review needs_changes approved publishing published publish_failed].freeze

  belongs_to :requirement

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
      created_at: iso_time(created_at),
      updated_at: iso_time(updated_at)
    }.compact
  end

  private

  def set_defaults
    self.status ||= "draft"
    self.acceptance_criteria ||= []
    self.labels ||= []
  end
end
