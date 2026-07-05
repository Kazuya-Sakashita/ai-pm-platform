class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_validation_error

  private

  def render_not_found(error)
    render_error("not_found", error.message, :not_found)
  end

  def render_validation_error(error)
    render_error(
      "validation_error",
      "Validation failed",
      :unprocessable_entity,
      error.record.errors.to_hash
    )
  end

  def render_error(code, message, status, details = {})
    render json: {
      error: {
        code: code,
        message: message,
        details: details
      },
      request_id: request.request_id
    }, status: status
  end

  def pagination_meta(scope)
    {
      page: 1,
      per_page: scope.size,
      total_count: scope.size,
      total_pages: 1
    }
  end

  def current_actor_id
    return @current_actor_id if defined?(@current_actor_id)

    @current_actor_id = actor_id_from_authorization_header || legacy_actor_id
  end

  def require_actor!(action:)
    return true if current_actor_id.present?

    if authentication_error
      render_error(authentication_error.code, authentication_error.safe_detail, authentication_error.http_status, { action: action })
    else
      render_error("authentication_required", "Authentication is required.", :unauthorized, { action: action })
    end

    false
  end

  def authorize_conversation_import!(project, action)
    return false unless require_actor!(action: action)

    policy = ConversationImportPolicy.new(project: project, actor_id: current_actor_id)
    return true if policy.allowed?(action)

    render_error(
      "conversation_import_forbidden",
      "Conversation import access is forbidden.",
      :forbidden,
      { action: action }
    )
    false
  end

  def authorize_project!(project, action)
    return false unless require_actor!(action: "project_#{action}")

    allowed_roles = {
      read: ProjectMembership::ROLES,
      update: %w[owner admin],
      archive: %w[owner admin]
    }.fetch(action)
    membership = project.project_memberships.find_by(actor_id: current_actor_id)
    return true if membership&.active? && allowed_roles.include?(membership.role)

    render_error(
      "project_forbidden",
      "Project access is forbidden.",
      :forbidden,
      { action: action }
    )
    false
  end

  def authorize_project_membership_management!(action, membership: nil)
    return false unless require_actor!(action: "project_membership_#{action}")

    actor_membership = project.project_memberships.active.find_by(actor_id: current_actor_id)
    allowed_roles = %w[owner admin]
    return true if actor_membership && allowed_roles.include?(actor_membership.role)

    render_error(
      "project_membership_forbidden",
      "Project membership access is forbidden.",
      :forbidden,
      { action: action, membership_id: membership&.id }.compact
    )
    false
  end

  def authentication_error
    current_actor_id unless defined?(@current_actor_id)
    @authentication_error
  end

  def actor_id_from_authorization_header
    authorization = request.authorization.to_s
    return nil if authorization.blank?

    token = authorization[/\ABearer\s+(.+)\z/i, 1]
    unless token
      @authentication_error = Authentication::JwtVerifier::Error.new(
        code: "invalid_token",
        safe_detail: "Authentication token is invalid."
      )
      return nil
    end

    Authentication::JwtVerifier.new.verify!(token).actor_id
  rescue Authentication::JwtVerifier::Error => e
    @authentication_error = e
    nil
  end

  def legacy_actor_id
    return nil unless legacy_actor_header_allowed?

    request.headers["X-Actor-Id"].presence
  end

  def legacy_actor_header_allowed?
    return false if Rails.env.production?

    ActiveModel::Type::Boolean.new.cast(ENV.fetch("AUTH_ALLOW_LEGACY_ACTOR_HEADER", "true"))
  end
end
