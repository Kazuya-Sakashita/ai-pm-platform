class AuditLog < ApplicationRecord
  belongs_to :project

  validates :action, :target_type, :target_id, presence: true

  def self.record!(project:, action:, target:, actor_id: "system", summary: nil, metadata: {})
    create!(
      project: project,
      actor_id: actor_id,
      action: action,
      target_type: target.class.name.underscore,
      target_id: target.id,
      summary: summary,
      metadata: metadata
    )
  end

  def api_json
    {
      id: id,
      project_id: project_id,
      actor_id: actor_id,
      action: action,
      target_type: target_type,
      target_id: target_id,
      summary: summary,
      metadata: metadata,
      created_at: iso_time(created_at)
    }.compact
  end
end
