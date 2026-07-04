class Project < ApplicationRecord
  STATUSES = %w[active archived].freeze

  has_many :meetings, dependent: :destroy
  has_many :jobs, dependent: :destroy
  has_many :audit_logs, dependent: :destroy
  has_many :integration_accounts, dependent: :destroy
  has_many :github_connection_states, dependent: :destroy
  has_many :github_issue_publish_attempts, dependent: :destroy
  has_many :conversation_imports, dependent: :destroy

  validates :name, presence: true, length: { maximum: 120 }
  validates :status, inclusion: { in: STATUSES }

  before_validation :set_default_status

  def api_json
    {
      id: id,
      name: name,
      description: description,
      status: status,
      github_repo: github_repo,
      created_at: iso_time(created_at),
      updated_at: iso_time(updated_at)
    }.compact
  end

  private

  def set_default_status
    self.status ||= "active"
  end
end
