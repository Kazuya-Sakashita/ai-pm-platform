class Minute < ApplicationRecord
  STATUSES = %w[draft generating generated in_review needs_changes approved failed].freeze

  belongs_to :meeting
  has_many :requirements, foreign_key: :minutes_id, inverse_of: :minute, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
  validates :summary, presence: true

  before_validation :set_defaults

  def api_json
    {
      id: id,
      meeting_id: meeting_id,
      status: status,
      summary: summary,
      decisions: decisions,
      open_questions: open_questions,
      action_items: action_items,
      generated_by_model: generated_by_model,
      created_at: iso_time(created_at),
      updated_at: iso_time(updated_at)
    }.compact
  end

  private

  def set_defaults
    self.status ||= "generated"
    self.decisions ||= []
    self.open_questions ||= []
    self.action_items ||= []
  end
end
