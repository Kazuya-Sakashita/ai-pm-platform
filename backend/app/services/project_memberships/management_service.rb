module ProjectMemberships
  class ManagementService
    class Error < StandardError
      attr_reader :code, :http_status, :details

      def initialize(code:, message:, http_status:, details: {})
        super(message)
        @code = code
        @http_status = http_status
        @details = details
      end
    end

    def initialize(project:, actor_id:)
      @project = project
      @actor_id = actor_id
    end

    def create!(actor_id:, role:)
      actor_id = actor_id.to_s.strip
      role = role.to_s
      validate_role!(role)
      require_owner!("project_membership_owner_required") if role == "owner"
      raise_error("project_membership_already_exists", "Project membership already exists.", :unprocessable_entity) if existing_membership?(actor_id)

      membership = nil
      ProjectMembership.transaction do
        membership = project.project_memberships.create!(actor_id: actor_id, role: role, status: "active")
        record_audit!(
          action: "project_membership.created",
          membership: membership,
          metadata: {
            membership_id: membership.id,
            target_actor_id: membership.actor_id,
            role_after: membership.role,
            status_after: membership.status
          }
        )
      end
      membership
    end

    def update_role!(membership:, role:)
      role = role.to_s
      validate_role!(role)
      require_owner!("project_membership_owner_required") if owner_role_change?(membership, role)

      ProjectMembership.transaction do
        project.project_memberships.lock.load
        membership.lock!
        previous_role = membership.role
        previous_status = membership.status
        ensure_active!(membership)
        ensure_last_owner_safe!(membership, changing_to_role: role)

        membership.update!(role: role)
        record_audit!(
          action: "project_membership.role_changed",
          membership: membership,
          metadata: {
            membership_id: membership.id,
            target_actor_id: membership.actor_id,
            role_before: previous_role,
            role_after: membership.role,
            status_before: previous_status,
            status_after: membership.status
          }
        )
      end
      membership
    end

    def revoke!(membership:)
      require_owner!("project_membership_owner_required") if membership.role == "owner"

      ProjectMembership.transaction do
        project.project_memberships.lock.load
        membership.lock!
        previous_status = membership.status
        ensure_active!(membership)
        ensure_last_owner_safe!(membership, revoking: true)

        membership.update!(status: "revoked")
        record_audit!(
          action: "project_membership.revoked",
          membership: membership,
          metadata: {
            membership_id: membership.id,
            target_actor_id: membership.actor_id,
            role_before: membership.role,
            role_after: membership.role,
            status_before: previous_status,
            status_after: membership.status
          }
        )
      end
      membership
    end

    private

    attr_reader :project, :actor_id

    def existing_membership?(target_actor_id)
      project.project_memberships.exists?(actor_id: target_actor_id)
    end

    def actor_membership
      @actor_membership ||= project.project_memberships.active.find_by(actor_id: actor_id)
    end

    def require_owner!(code)
      return if actor_membership&.role == "owner"

      raise_error(code, "Project membership owner permission is required.", :forbidden)
    end

    def owner_role_change?(membership, next_role)
      membership.role == "owner" || next_role == "owner"
    end

    def validate_role!(role)
      return if ProjectMembership::ROLES.include?(role)

      raise_error("project_membership_role_invalid", "Project membership role is invalid.", :unprocessable_entity, { role: role })
    end

    def ensure_active!(membership)
      return if membership.active?

      raise_error("project_membership_inactive", "Project membership is not active.", :unprocessable_entity)
    end

    def ensure_last_owner_safe!(membership, changing_to_role: nil, revoking: false)
      return unless membership.role == "owner"
      return if changing_to_role == "owner" && !revoking
      return if active_owner_count > 1

      raise_error("last_owner_required", "At least one active project owner is required.", :conflict)
    end

    def active_owner_count
      project.project_memberships.where(role: "owner", status: "active").count
    end

    def record_audit!(action:, membership:, metadata:)
      AuditLog.record!(
        project: project,
        action: action,
        target: membership,
        actor_id: actor_id,
        metadata: metadata
      )
    end

    def raise_error(code, message, http_status, details = {})
      raise Error.new(code: code, message: message, http_status: http_status, details: details)
    end
  end
end
