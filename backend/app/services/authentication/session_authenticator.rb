module Authentication
  class SessionAuthenticator
    Result = Struct.new(:auth_actor, :auth_session, :jti_digest, keyword_init: true)

    def initialize(require_lifecycle_claims: self.class.require_lifecycle_claims?)
      @require_lifecycle_claims = require_lifecycle_claims
    end

    def self.require_lifecycle_claims?
      ActiveModel::Type::Boolean.new.cast(ENV.fetch("AUTH_JWT_REQUIRE_SESSION_CLAIMS", "false"))
    end

    def authenticate!(payload, header:, now:)
      return nil unless should_authenticate_session?(payload)

      actor_subject = payload.fetch("sub").to_s
      sid = string_claim(payload, "sid")
      jti = string_claim(payload, "jti")
      session_version = integer_claim(payload, "sv")
      issued_at = integer_claim(payload, "iat")
      raise_error("invalid_token", "Authentication token is invalid.") if [sid, jti, session_version, issued_at].any?(&:blank?)

      jti_digest = AuthTokenRevocation.digest_jti(jti)
      if AuthTokenRevocation.active_at(now).exists?(jti_digest: jti_digest)
        record_rejection("token_revoked", actor_subject: actor_subject, sid: sid, jti_digest: jti_digest, kid: header["kid"])
        raise_error("token_revoked", "Authentication token has been revoked.")
      end

      auth_session = AuthSession.includes(:auth_actor).find_by(sid: sid)
      unless auth_session
        record_rejection("session_not_found", actor_subject: actor_subject, sid: sid, jti_digest: jti_digest, kid: header["kid"])
        raise_error("session_not_found", "Authentication session was not found.")
      end

      raise_error("invalid_token", "Authentication token is invalid.") unless auth_session.actor_subject == actor_subject

      auth_actor = auth_session.auth_actor
      if !auth_actor.active? || auth_session.revoked?
        record_rejection("session_revoked", actor_subject: actor_subject, sid: sid, jti_digest: jti_digest, kid: header["kid"], session_status: auth_session.status, actor_status: auth_actor.status)
        raise_error("session_revoked", "Authentication session has been revoked.")
      end

      if auth_session.status == "expired" || auth_session.expired_at?(now)
        record_rejection("session_expired", actor_subject: actor_subject, sid: sid, jti_digest: jti_digest, kid: header["kid"], session_status: auth_session.status)
        raise_error("session_expired", "Authentication session has expired.")
      end

      if stale_session_version?(auth_actor, auth_session, session_version, issued_at)
        record_rejection("session_version_stale", actor_subject: actor_subject, sid: sid, jti_digest: jti_digest, kid: header["kid"])
        raise_error("session_version_stale", "Authentication session is no longer current.")
      end

      Result.new(auth_actor: auth_actor, auth_session: auth_session, jti_digest: jti_digest)
    end

    private

    attr_reader :require_lifecycle_claims

    def should_authenticate_session?(payload)
      return true if require_lifecycle_claims

      %w[sid sv jti].any? { |key| payload.key?(key) }
    end

    def stale_session_version?(auth_actor, auth_session, session_version, issued_at)
      return true unless session_version == auth_actor.session_version
      return true unless session_version == auth_session.session_version

      revoked_at = auth_actor.sessions_revoked_at
      revoked_at.present? && Time.at(issued_at) <= revoked_at
    end

    def string_claim(payload, key)
      value = payload[key].to_s
      return nil if value.blank? || value.length > 120

      value
    end

    def integer_claim(payload, key)
      return nil unless payload.key?(key)

      Integer(payload[key])
    rescue ArgumentError, TypeError
      nil
    end

    def record_rejection(code, actor_subject:, sid:, jti_digest:, kid:, session_status: nil, actor_status: nil)
      SecurityEvent.record!(
        action: "auth.token.rejected",
        target_type: "token",
        target_id: jti_digest.first(16),
        actor_id: actor_subject.presence || "unknown",
        severity: "warning",
        summary: code,
        metadata: {
          code: code,
          sid: sid,
          kid: kid.to_s.presence,
          jti_digest_prefix: jti_digest.first(16),
          session_status: session_status,
          actor_status: actor_status
        }.compact
      )
    rescue StandardError
      nil
    end

    def raise_error(code, safe_detail, http_status = :unauthorized)
      raise Authentication::JwtVerifier::Error.new(code: code, safe_detail: safe_detail, http_status: http_status)
    end
  end
end
