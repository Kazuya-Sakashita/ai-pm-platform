class Job < ApplicationRecord
  JOB_TYPES = %w[ai_generation github_publish github_reconciliation github_connect validation].freeze
  STATUSES = %w[queued running succeeded failed cancelled].freeze

  belongs_to :project

  validates :job_type, inclusion: { in: JOB_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :target_type, presence: true
  validates :progress, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  before_validation :set_defaults

  def api_json
    {
      id: id,
      project_id: project_id,
      job_type: job_type,
      status: status,
      target_type: target_type,
      target_id: target_id,
      progress: progress,
      error_code: error_code,
      error_message: error_message,
      safe_error_detail: safe_error_detail,
      created_at: iso_time(created_at),
      updated_at: iso_time(updated_at)
    }.compact
  end

  private

  def set_defaults
    self.status ||= "queued"
    self.progress ||= 0
  end
end
