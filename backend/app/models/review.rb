class Review < ApplicationRecord
  TARGET_TYPES = %w[meeting minutes requirement issue_draft openapi_draft architecture security release].freeze
  STATUSES = %w[open action_required resolved accepted_risk].freeze

  validates :target_type, inclusion: { in: TARGET_TYPES }
  validates :target_id, :reviewer_role, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :framework, :improvements, :priority, :next_actions, presence: true

  before_validation :set_defaults

  def api_json
    {
      id: id,
      target_type: target_type,
      target_id: target_id,
      status: status,
      reviewer_role: reviewer_role,
      framework: framework,
      positives: positives,
      improvements: improvements,
      priority: priority,
      next_actions: next_actions,
      issue_numbers: issue_numbers,
      accepted_risk: accepted_risk,
      created_at: iso_time(created_at),
      updated_at: iso_time(updated_at)
    }.compact
  end

  private

  def set_defaults
    self.status ||= "open"
    self.framework ||= []
    self.positives ||= []
    self.improvements ||= []
    self.priority ||= []
    self.next_actions ||= []
    self.issue_numbers ||= []
  end
end
