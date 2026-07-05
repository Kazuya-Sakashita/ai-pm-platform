require "digest"

class AuthTokenRevocation < ApplicationRecord
  REASONS = %w[logout logout_everywhere admin_forced incident replay_suspected key_compromise].freeze

  validates :jti_digest, presence: true, length: { is: 64 }, uniqueness: true
  validates :sid, :actor_subject, length: { maximum: 120 }, allow_blank: true
  validates :expires_at, presence: true
  validates :reason, inclusion: { in: REASONS }

  scope :active_at, ->(time) { where("expires_at > ?", time) }

  def self.digest_jti(jti)
    Digest::SHA256.hexdigest(jti.to_s)
  end
end
