class AuthActor < ApplicationRecord
  STATUSES = %w[active suspended disabled].freeze

  has_many :auth_sessions,
    primary_key: :subject,
    foreign_key: :actor_subject,
    dependent: :destroy,
    inverse_of: :auth_actor

  validates :subject, presence: true, length: { maximum: 120 }, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :session_version, numericality: { only_integer: true, greater_than: 0 }
  validates :email_digest, length: { maximum: 128 }, allow_blank: true

  scope :active, -> { where(status: "active") }

  def active?
    status == "active"
  end
end
