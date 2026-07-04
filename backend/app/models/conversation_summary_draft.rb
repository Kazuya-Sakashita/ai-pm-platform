class ConversationSummaryDraft < ApplicationRecord
  STATUSES = %w[draft needs_revision approved rejected stale].freeze

  belongs_to :conversation_import

  validates :status, inclusion: { in: STATUSES }
  validates :summary, presence: true
  validates :confidence, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }

  before_validation :set_defaults

  def api_json
    {
      id: id,
      conversation_import_id: conversation_import_id,
      status: status,
      summary: summary,
      decisions: decisions,
      open_questions: open_questions,
      action_items: action_items,
      issue_candidates: issue_candidates,
      requirement_candidates: requirement_candidates,
      risks: risks,
      participants: participants,
      source_quotes: source_quotes,
      confidence: confidence&.to_f,
      generated_by_model: model,
      created_at: iso_time(created_at),
      updated_at: iso_time(updated_at)
    }.compact
  end

  private

  def set_defaults
    self.status ||= "draft"
    self.provider ||= "deterministic"
    self.generated_at ||= Time.current
    self.decisions ||= []
    self.open_questions ||= []
    self.action_items ||= []
    self.issue_candidates ||= []
    self.requirement_candidates ||= []
    self.risks ||= []
    self.participants ||= []
    self.source_quotes ||= []
    self.validation_errors ||= []
  end
end
