class FailedJobDiscardApproval < ApplicationRecord
  STATUSES = %w[pending approved rejected expired consumed].freeze

  belongs_to :project

  validates :failed_job_id, :solid_queue_job_id, :queue_name, :class_name, :reason_template, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :requested_by_actor_id, :expires_at, presence: true
  validates :discard_safety_confirmed, acceptance: true

  scope :recent_first, -> { order(created_at: :desc) }

  def pending?
    status == "pending"
  end

  def approved?
    status == "approved"
  end

  def consumed?
    status == "consumed"
  end

  def expired?(now = Time.current)
    expires_at <= now
  end

  def api_json
    {
      id: id,
      project_id: project_id,
      failed_job_id: integer_value(failed_job_id),
      job_id: integer_value(solid_queue_job_id),
      product_job_id: product_job_id,
      queue_name: queue_name,
      class_name: class_name,
      reason_template: reason_template,
      discard_safety_confirmed: discard_safety_confirmed,
      status: status,
      requested_by_actor_id: requested_by_actor_id,
      requested_by_role: requested_by_role,
      approved_by_actor_id: approved_by_actor_id,
      approved_by_role: approved_by_role,
      rejected_by_actor_id: rejected_by_actor_id,
      rejected_by_role: rejected_by_role,
      consumed_by_actor_id: consumed_by_actor_id,
      consumed_by_role: consumed_by_role,
      approval_note_present: approval_note.present? || nil,
      rejection_reason_present: rejection_reason.present? || nil,
      expires_at: iso_time(expires_at),
      approved_at: iso_time(approved_at),
      rejected_at: iso_time(rejected_at),
      consumed_at: iso_time(consumed_at),
      created_at: iso_time(created_at),
      updated_at: iso_time(updated_at)
    }.compact
  end

  def safe_metadata
    api_json.except(:approval_note_present, :rejection_reason_present).merge(
      approval_note_present: approval_note.present?,
      rejection_reason_present: rejection_reason.present?
    )
  end

  private

  def integer_value(value)
    Integer(value)
  rescue ArgumentError, TypeError
    value
  end
end
