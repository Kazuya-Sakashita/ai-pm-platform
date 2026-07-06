class ReviewStateEvent < ApplicationRecord
  EVENT_TYPES = %w[
    review_requested
    review_action_required
    review_resolved
    review_risk_accepted
    review_reopened
  ].freeze

  belongs_to :review
  belongs_to :project

  validates :target_type, :target_id, :event_type, :to_status, :actor_id, :occurred_at, presence: true
  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :from_status, inclusion: { in: Review::STATUSES }, allow_blank: true
  validates :to_status, inclusion: { in: Review::STATUSES }

  before_validation :set_defaults

  def api_json
    {
      id: id,
      review_id: review_id,
      project_id: project_id,
      target_type: target_type,
      target_id: target_id,
      event_type: event_type,
      from_status: from_status,
      to_status: to_status,
      actor_id: actor_id,
      reviewer_role: review.reviewer_role,
      reason_code: reason_code,
      reason_summary: reason_summary,
      issue_numbers: issue_numbers,
      metadata: metadata,
      occurred_at: iso_time(occurred_at),
      created_at: iso_time(created_at)
    }.compact
  end

  private

  def set_defaults
    self.issue_numbers ||= []
    self.metadata ||= {}
    self.occurred_at ||= Time.current
  end
end
