class GithubWebhookDelivery < ApplicationRecord
  STATUSES = %w[processing processed ignored failed].freeze

  validates :delivery_digest, presence: true, uniqueness: true, length: { is: 64 }
  validates :event, presence: true, length: { maximum: 120 }
  validates :status, inclusion: { in: STATUSES }
end
