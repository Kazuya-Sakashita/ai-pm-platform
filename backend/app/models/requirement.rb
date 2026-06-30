class Requirement < ApplicationRecord
  STATUSES = %w[draft generating generated in_review needs_changes approved failed].freeze

  belongs_to :minute, foreign_key: :minutes_id, inverse_of: :requirements

  validates :status, inclusion: { in: STATUSES }
  validates :background, :goal, presence: true
  validates :functional_requirements, :acceptance_criteria, presence: true

  before_validation :set_defaults

  def api_json
    {
      id: id,
      minutes_id: minutes_id,
      status: status,
      background: background,
      goal: goal,
      user_stories: user_stories,
      functional_requirements: functional_requirements,
      non_functional_requirements: non_functional_requirements,
      acceptance_criteria: acceptance_criteria,
      out_of_scope: out_of_scope,
      open_questions: open_questions,
      risks: risks,
      generated_by_model: generated_by_model,
      created_at: iso_time(created_at),
      updated_at: iso_time(updated_at)
    }.compact
  end

  private

  def set_defaults
    self.status ||= "generated"
    self.user_stories ||= []
    self.functional_requirements ||= []
    self.non_functional_requirements ||= []
    self.acceptance_criteria ||= []
    self.out_of_scope ||= []
    self.open_questions ||= []
    self.risks ||= []
  end
end
