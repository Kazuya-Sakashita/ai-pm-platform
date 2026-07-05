class SecurityEvent < ApplicationRecord
  SEVERITIES = %w[info warning critical].freeze

  belongs_to :project, optional: true

  validates :actor_id, presence: true, length: { maximum: 120 }
  validates :action, :target_type, :target_id, presence: true
  validates :severity, inclusion: { in: SEVERITIES }

  def self.record!(action:, target_type:, target_id:, actor_id: "system", project: nil, severity: "info", summary: nil, metadata: {})
    create!(
      project: project,
      actor_id: actor_id,
      action: action,
      target_type: target_type,
      target_id: target_id,
      severity: severity,
      summary: summary,
      metadata: metadata
    )
  end
end
