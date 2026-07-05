class ProjectMembership < ApplicationRecord
  ROLES = %w[owner admin editor reviewer viewer auditor].freeze
  STATUSES = %w[active revoked].freeze

  belongs_to :project

  validates :actor_id, presence: true, length: { maximum: 120 }, uniqueness: { scope: :project_id }
  validates :role, inclusion: { in: ROLES }
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: "active") }

  def active?
    status == "active"
  end

  def api_json
    {
      id: id,
      project_id: project_id,
      actor_id: actor_id,
      role: role,
      status: status,
      created_at: iso_time(created_at),
      updated_at: iso_time(updated_at)
    }
  end
end
