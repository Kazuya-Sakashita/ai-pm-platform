class Meeting < ApplicationRecord
  SOURCE_TYPES = %w[manual discord_log transcript].freeze
  STATUSES = %w[draft generating generated in_review needs_changes approved failed].freeze

  belongs_to :project

  validates :title, presence: true, length: { maximum: 160 }
  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :raw_text, presence: true, length: { maximum: 50_000 }
  validates :status, inclusion: { in: STATUSES }

  before_validation :set_defaults

  def api_json
    {
      id: id,
      project_id: project_id,
      title: title,
      source_type: source_type,
      meeting_date: meeting_date&.iso8601,
      participants: participants,
      raw_text: raw_text,
      status: status,
      created_at: iso_time(created_at),
      updated_at: iso_time(updated_at)
    }.compact
  end

  private

  def set_defaults
    self.source_type ||= "manual"
    self.status ||= "draft"
    self.participants ||= []
    self.tags ||= []
  end
end
