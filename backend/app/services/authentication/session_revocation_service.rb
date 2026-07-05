module Authentication
  class SessionRevocationService
    def initialize(auth_actor:, operator_actor_id:, current_session: nil, now: Time.current)
      @auth_actor = auth_actor
      @operator_actor_id = operator_actor_id
      @current_session = current_session
      @now = now
    end

    def revoke_session!(auth_session, reason:)
      AuthSession.transaction do
        revoke!(auth_session, reason: reason)
        record_session_revoke!(auth_session, reason: reason)
      end

      auth_session
    end

    def logout_everywhere!
      revoked_count = 0
      next_version = nil

      AuthActor.transaction do
        auth_actor.lock!
        next_version = auth_actor.session_version + 1
        auth_actor.update!(session_version: next_version, sessions_revoked_at: now)

        sessions = auth_actor.auth_sessions.where(status: "active")
        revoked_count = sessions.count
        sessions.find_each { |auth_session| revoke!(auth_session, reason: "logout_everywhere") }

        SecurityEvent.record!(
          action: "auth.sessions.revoked",
          target_type: "auth_actor",
          target_id: auth_actor.subject,
          actor_id: operator_actor_id,
          severity: "info",
          summary: "logout_everywhere",
          metadata: {
            reason: "logout_everywhere",
            revoked_session_count: revoked_count,
            session_version: next_version
          }
        )
      end

      {
        revoked_session_count: revoked_count,
        session_version: next_version,
        sessions_revoked_at: now
      }
    end

    private

    attr_reader :auth_actor, :operator_actor_id, :current_session, :now

    def revoke!(auth_session, reason:)
      return unless auth_session.active?

      auth_session.update!(
        status: "revoked",
        revoked_at: now,
        revoked_by_actor_id: operator_actor_id,
        revocation_reason: reason
      )
    end

    def record_session_revoke!(auth_session, reason:)
      SecurityEvent.record!(
        action: "auth.session.revoked",
        target_type: "auth_session",
        target_id: auth_session.id,
        actor_id: operator_actor_id,
        severity: reason == "admin_forced" ? "warning" : "info",
        summary: reason,
        metadata: {
          reason: reason,
          current: current_session&.id == auth_session.id,
          session_status: auth_session.status
        }
      )
    end
  end
end
