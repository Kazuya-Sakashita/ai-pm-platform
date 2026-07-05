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
    @current_actor_id ||= request.headers["X-Actor-Id"].presence
  end

  def authorize_conversation_import!(project, action)
    unless current_actor_id
      render_error(
        "conversation_import_actor_required",
        "Conversation import actor is required.",
        :unauthorized,
        { action: action }
      )
      return false
    end

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
end
