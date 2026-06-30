class GithubConnectionState < ApplicationRecord
  belongs_to :project

  validates :repository_owner, :repository_name, :nonce_digest, :state_digest, :expires_at, presence: true
  validates :nonce_digest, :state_digest, uniqueness: true
  validates :repository_owner, :repository_name, format: { with: /\A[^\s\/]+\z/ }

  before_validation :normalize_repository

  def github_repository
    "#{repository_owner}/#{repository_name}"
  end

  def consumed?
    consumed_at.present?
  end

  def expired?
    expires_at <= Time.current
  end

  def consume!
    with_lock do
      raise GithubIntegration::StateError, "GitHub connection state already used." if consumed?
      raise GithubIntegration::StateError, "GitHub connection state expired." if expired?

      update!(consumed_at: Time.current)
    end
  end

  private

  def normalize_repository
    self.repository_owner = repository_owner.to_s.strip
    self.repository_name = repository_name.to_s.strip
  end
end
