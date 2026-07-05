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
end
