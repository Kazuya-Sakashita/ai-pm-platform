module Api
  module V1
    class AuthSessionsController < ApplicationController
      def index
        return unless require_session_actor!(action: "auth_session_read")

        sessions = current_auth_actor.auth_sessions.order(current_order)
        render json: {
          data: sessions.map { |auth_session| auth_session.api_json(current_session_id: current_auth_session.id) },
          meta: {
            current_session_id: current_auth_session.id,
            active_count: sessions.count(&:active?),
            total_count: sessions.size
          }
        }
      end

      def destroy
        return unless require_session_actor!(action: "auth_session_revoke")

        auth_session = current_auth_actor.auth_sessions.find_by(id: params[:auth_session_id])
        return render_not_found_session unless auth_session

        Authentication::SessionRevocationService.new(
          auth_actor: current_auth_actor,
          operator_actor_id: current_actor_id,
          current_session: current_auth_session
        ).revoke_session!(auth_session, reason: "logout")

        render json: { data: auth_session.api_json(current_session_id: current_auth_session.id) }
      end

      def destroy_current
        return unless require_session_actor!(action: "auth_session_logout")

        Authentication::SessionRevocationService.new(
          auth_actor: current_auth_actor,
          operator_actor_id: current_actor_id,
          current_session: current_auth_session
        ).revoke_session!(current_auth_session, reason: "logout")

        render json: { data: current_auth_session.api_json(current_session_id: current_auth_session.id) }
      end

      def logout_everywhere
        return unless require_session_actor!(action: "auth_session_logout_everywhere")

        result = Authentication::SessionRevocationService.new(
          auth_actor: current_auth_actor,
          operator_actor_id: current_actor_id,
          current_session: current_auth_session
        ).logout_everywhere!

        render json: { data: result }
      end

      private

      def require_session_actor!(action:)
        return false unless require_actor!(action: action)
        return true if current_auth_session && current_auth_context&.jti_digest.present?

        render_error("invalid_token", "Authentication token is invalid.", :unauthorized, { action: action })
        false
      end

      def current_auth_actor
        @current_auth_actor ||= current_auth_session.auth_actor
      end

      def current_auth_session
        current_auth_context&.auth_session
      end

      def current_order
        Arel.sql("CASE WHEN id = #{ActiveRecord::Base.connection.quote(current_auth_session.id)} THEN 0 ELSE 1 END, created_at DESC")
      end

      def render_not_found_session
        render_error("not_found", "Resource not found", :not_found)
      end
    end
  end
end
