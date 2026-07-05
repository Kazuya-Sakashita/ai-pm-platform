class AuthSession < ApplicationRecord
  STATUSES = %w[active revoked expired].freeze
  REVOCATION_REASONS = %w[logout logout_everywhere admin_forced incident replay_suspected key_compromise].freeze

  belongs_to :auth_actor,
    primary_key: :subject,
    foreign_key: :actor_subject,
    inverse_of: :auth_sessions

  validates :sid, presence: true, length: { maximum: 120 }, uniqueness: true
  validates :actor_subject, presence: true, length: { maximum: 120 }
  validates :status, inclusion: { in: STATUSES }
  validates :session_version, numericality: { only_integer: true, greater_than: 0 }
  validates :issued_at, :expires_at, presence: true
  validates :revocation_reason, inclusion: { in: REVOCATION_REASONS }, allow_blank: true
  validates :ip_hash, :user_agent_hash, length: { maximum: 128 }, allow_blank: true

  scope :active, -> { where(status: "active") }

  def active?
    status == "active"
  end

  def expired_at?(time)
    expires_at <= time
  end

  def revoked?
    status == "revoked"
  end

  def api_json(current_session_id: nil)
    {
      id: id,
      status: status,
      current: id == current_session_id,
      issued_at: issued_at,
      expires_at: expires_at,
      last_seen_at: last_seen_at,
      revoked_at: revoked_at,
      revocation_reason: revocation_reason,
      created_at: created_at,
      updated_at: updated_at
    }
  end
end
