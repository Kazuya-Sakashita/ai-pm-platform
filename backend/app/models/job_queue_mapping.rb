class JobQueueMapping < ApplicationRecord
  PROVIDERS = %w[solid_queue].freeze

  belongs_to :project
  belongs_to :product_job, class_name: "Job", foreign_key: :job_id, inverse_of: :queue_mappings

  validates :provider, inclusion: { in: PROVIDERS }
  validates :solid_queue_job_id, presence: true, uniqueness: { scope: :provider }
  validate :project_matches_product_job

  before_validation :set_project_from_product_job

  def self.record_solid_queue!(product_job:, active_job:, queue_name:, job_class_name:, scheduled_at:)
    solid_queue_job_id = Integer(active_job&.provider_job_id, exception: false)
    return nil if product_job.blank? || solid_queue_job_id.blank?

    mapping = find_or_initialize_by(provider: "solid_queue", solid_queue_job_id: solid_queue_job_id)
    mapping.assign_attributes(
      product_job: product_job,
      project: product_job.project,
      active_job_id: active_job&.job_id,
      queue_name: queue_name,
      job_class_name: job_class_name,
      scheduled_at: scheduled_at
    )
    mapping.save!
    mapping
  end

  private

  def set_project_from_product_job
    self.project ||= product_job&.project
  end

  def project_matches_product_job
    return if project.blank? || product_job.blank?
    return if project_id == product_job.project_id

    errors.add(:project_id, "must match product job project")
  end
end
