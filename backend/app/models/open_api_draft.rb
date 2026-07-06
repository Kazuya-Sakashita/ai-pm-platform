class OpenApiDraft < ApplicationRecord
  STATUSES = %w[draft invalid valid in_review needs_changes approved stale].freeze

  belongs_to :requirement, inverse_of: :open_api_drafts

  validates :status, inclusion: { in: STATUSES }
  validates :title, :content, presence: true
  validate :validation_errors_array

  before_validation :set_defaults

  def api_json
    {
      id: id,
      requirement_id: requirement_id,
      status: status,
      title: title,
      content: content,
      validation_errors: validation_errors,
      created_at: iso_time(created_at),
      updated_at: iso_time(updated_at)
    }.compact
  end

  private

  def set_defaults
    self.status ||= "draft"
    self.validation_errors ||= []
  end

  def validation_errors_array
    errors.add(:validation_errors, "must be an array") unless validation_errors.is_a?(Array)
  end
end
