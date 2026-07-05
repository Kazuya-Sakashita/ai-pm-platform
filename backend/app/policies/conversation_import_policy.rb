class ConversationImportPolicy
  READ_ROLES = %w[owner admin editor reviewer viewer auditor].freeze
  EDIT_ROLES = %w[owner admin editor].freeze
  REVIEW_ROLES = %w[owner admin editor reviewer].freeze
  APPROVE_ROLES = %w[owner admin reviewer].freeze
  ADMIN_ROLES = %w[owner admin].freeze

  ACTION_ROLES = {
    read: READ_ROLES,
    create: EDIT_ROLES,
    update: EDIT_ROLES,
    scan: EDIT_ROLES,
    generate_summary: EDIT_ROLES,
    anonymize: ADMIN_ROLES,
    update_summary_draft: REVIEW_ROLES,
    approve_summary_draft: APPROVE_ROLES
  }.freeze

  def initialize(project:, actor_id:)
    @project = project
    @actor_id = actor_id
  end

  def allowed?(action)
    allowed_roles = ACTION_ROLES.fetch(action)
    membership&.active? && allowed_roles.include?(membership.role)
  end

  def role
    membership&.role
  end

  private

  attr_reader :project, :actor_id

  def membership
    return nil if actor_id.blank?

    @membership ||= project.project_memberships.find_by(actor_id: actor_id)
  end
end
