class IntegrationAccount < ApplicationRecord
  PROVIDERS = %w[github].freeze
  STATUSES = %w[not_connected connected error revoked].freeze

  belongs_to :project

  validates :provider, inclusion: { in: PROVIDERS }
  validates :status, inclusion: { in: STATUSES }
  validates :repository_owner, :repository_name, presence: true, length: { maximum: 120 }
  validates :repository_owner, :repository_name, format: { with: /\A[^\s\/]+\z/ }
  validates :github_installation_id, presence: true, if: :connected?
  validates :granted_permissions, presence: true

  before_validation :set_defaults
  before_validation :normalize_repository

  def connected?
    status == "connected"
  end

  def github_repository
    "#{repository_owner}/#{repository_name}"
  end

  def issues_write_granted?
    permission = granted_permissions["issues"] || granted_permissions[:issues]
    permission == "write"
  end

  def api_json
    {
      id: id,
      project_id: project_id,
      provider: provider,
      status: status,
      external_account_id: external_account_id,
      repository_owner: repository_owner,
      repository_name: repository_name,
      github_installation_id: github_installation_id,
      github_account_login: github_account_login,
      github_account_type: github_account_type,
      granted_permissions: granted_permissions,
      last_sync_at: iso_time(last_sync_at),
      last_error_safe: last_error_safe,
      created_at: iso_time(created_at),
      updated_at: iso_time(updated_at)
    }.compact
  end

  private

  def set_defaults
    self.provider ||= "github"
    self.status ||= "not_connected"
    self.granted_permissions ||= {}
  end

  def normalize_repository
    self.repository_owner = repository_owner.to_s.strip
    self.repository_name = repository_name.to_s.strip
  end
end
