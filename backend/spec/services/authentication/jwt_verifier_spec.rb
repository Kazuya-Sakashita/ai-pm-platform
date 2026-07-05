require "rails_helper"

RSpec.describe Authentication::JwtVerifier do
  it "returns the actor id from a valid token" do
    token = jwt_token(actor_id: "dm-editor")

    result = described_class.new.verify!(token)

    expect(result.actor_id).to eq("dm-editor")
    expect(result.claims).to include("sub" => "dm-editor")
  end

  it "rejects malformed tokens with a safe error" do
    expect { described_class.new.verify!("not-a-jwt") }
      .to raise_error(Authentication::JwtVerifier::Error) { |error|
        expect(error.code).to eq("invalid_token")
        expect(error.safe_detail).to eq("Authentication token is invalid.")
      }
  end

  it "rejects expired tokens" do
    token = jwt_token(expires_at: 1.hour.ago)

    expect { described_class.new.verify!(token) }
      .to raise_error(Authentication::JwtVerifier::Error) { |error|
        expect(error.code).to eq("token_expired")
      }
  end

  it "rejects tokens signed with the wrong secret" do
    token = jwt_token(secret: "wrong-secret")

    expect { described_class.new.verify!(token) }
      .to raise_error(Authentication::JwtVerifier::Error) { |error|
        expect(error.code).to eq("invalid_token")
      }
  end

  it "rejects unexpected algorithms" do
    token = jwt_token(algorithm: "none")

    expect { described_class.new.verify!(token) }
      .to raise_error(Authentication::JwtVerifier::Error) { |error|
        expect(error.code).to eq("invalid_token")
      }
  end

  it "returns auth session context for a keyring and session backed token" do
    keyring_json = JSON.generate(keys: [
      { kid: "test-active", secret: Authentication::JwtVerifier::DEVELOPMENT_SECRET, status: "active" }
    ])

    with_env("AUTH_JWT_KEYRING_JSON" => keyring_json) do
      headers, _actor, auth_session, jti = session_auth_headers(actor_id: "session-actor")
      token = headers.fetch("Authorization").delete_prefix("Bearer ")

      result = described_class.new.verify!(token)

      expect(result.actor_id).to eq("session-actor")
      expect(result.auth_session).to eq(auth_session)
      expect(result.jti_digest).to eq(AuthTokenRevocation.digest_jti(jti))
      expect(result.kid).to eq("test-active")
    end
  end

  it "accepts verify-only keys from secret_env for migration windows" do
    keyring_json = JSON.generate(keys: [
      { kid: "verify-only", secret_env: "TEST_VERIFY_ONLY_JWT_SECRET", status: "verify_only" }
    ])

    with_env("AUTH_JWT_KEYRING_JSON" => keyring_json, "TEST_VERIFY_ONLY_JWT_SECRET" => "verify-only-secret") do
      token = jwt_token(kid: "verify-only", secret: "verify-only-secret")

      result = described_class.new.verify!(token)

      expect(result.actor_id).to eq("dm-editor")
      expect(result.kid).to eq("verify-only")
    end
  end

  it "rejects unknown signing keys with a safe error" do
    token = jwt_token(kid: "missing-key")

    with_env("AUTH_JWT_KEYRING_JSON" => JSON.generate(keys: [])) do
      expect { described_class.new.verify!(token) }
        .to raise_error(Authentication::JwtVerifier::Error) { |error|
          expect(error.code).to eq("signing_key_unknown")
          expect(error.safe_detail).to eq("Authentication token key is unknown.")
        }
    end
  end

  it "rejects retired signing keys" do
    keyring_json = JSON.generate(keys: [
      { kid: "retired-key", status: "retired" }
    ])
    token = jwt_token(kid: "retired-key")

    with_env("AUTH_JWT_KEYRING_JSON" => keyring_json) do
      expect { described_class.new.verify!(token) }
        .to raise_error(Authentication::JwtVerifier::Error) { |error|
          expect(error.code).to eq("signing_key_retired")
        }
    end
  end

  it "rejects disabled signing keys" do
    keyring_json = JSON.generate(keys: [
      { kid: "disabled-key", status: "disabled" }
    ])
    token = jwt_token(kid: "disabled-key")

    with_env("AUTH_JWT_KEYRING_JSON" => keyring_json) do
      expect { described_class.new.verify!(token) }
        .to raise_error(Authentication::JwtVerifier::Error) { |error|
          expect(error.code).to eq("signing_key_not_active")
        }
    end
  end

  it "rejects tokens beyond the configured maximum access token ttl" do
    token = jwt_token(issued_at: Time.current, expires_at: 1.hour.from_now)

    with_env("AUTH_JWT_MAX_ACCESS_TOKEN_TTL_SECONDS" => "60") do
      expect { described_class.new.verify!(token) }
        .to raise_error(Authentication::JwtVerifier::Error) { |error|
          expect(error.code).to eq("invalid_token")
        }
    end
  end

  it "requires lifecycle claims when configured" do
    token = jwt_token(actor_id: "missing-session-claims")

    with_env("AUTH_JWT_REQUIRE_SESSION_CLAIMS" => "true") do
      expect { described_class.new.verify!(token) }
        .to raise_error(Authentication::JwtVerifier::Error) { |error|
          expect(error.code).to eq("invalid_token")
        }
    end
  end

  it "rejects revoked jti values and records safe security event metadata" do
    keyring_json = JSON.generate(keys: [
      { kid: "test-active", secret: Authentication::JwtVerifier::DEVELOPMENT_SECRET, status: "active" }
    ])
    raw_jti = "raw-jti-never-store"

    with_env("AUTH_JWT_KEYRING_JSON" => keyring_json) do
      headers, = session_auth_headers(actor_id: "revoked-token-actor", jti: raw_jti)
      create(:auth_token_revocation, jti_digest: AuthTokenRevocation.digest_jti(raw_jti), expires_at: 10.minutes.from_now)
      token = headers.fetch("Authorization").delete_prefix("Bearer ")

      expect { described_class.new.verify!(token) }
        .to raise_error(Authentication::JwtVerifier::Error) { |error|
          expect(error.code).to eq("token_revoked")
        }

      event = SecurityEvent.last
      expect(event.action).to eq("auth.token.rejected")
      expect(event.metadata.to_s).to include(AuthTokenRevocation.digest_jti(raw_jti).first(16))
      expect(event.metadata.to_s).not_to include(raw_jti)
    end
  end

  it "rejects revoked sessions" do
    keyring_json = JSON.generate(keys: [
      { kid: "test-active", secret: Authentication::JwtVerifier::DEVELOPMENT_SECRET, status: "active" }
    ])

    with_env("AUTH_JWT_KEYRING_JSON" => keyring_json) do
      headers, _actor, auth_session = session_auth_headers(actor_id: "revoked-session-actor")
      auth_session.update!(status: "revoked", revoked_at: Time.current, revocation_reason: "admin_forced")
      token = headers.fetch("Authorization").delete_prefix("Bearer ")

      expect { described_class.new.verify!(token) }
        .to raise_error(Authentication::JwtVerifier::Error) { |error|
          expect(error.code).to eq("session_revoked")
        }
    end
  end

  it "rejects expired sessions" do
    keyring_json = JSON.generate(keys: [
      { kid: "test-active", secret: Authentication::JwtVerifier::DEVELOPMENT_SECRET, status: "active" }
    ])

    with_env("AUTH_JWT_KEYRING_JSON" => keyring_json) do
      issued_at = 2.minutes.ago
      headers, _actor, auth_session = session_auth_headers(actor_id: "expired-session-actor", issued_at: issued_at, expires_at: 1.minute.from_now)
      auth_session.update!(status: "expired")
      token = headers.fetch("Authorization").delete_prefix("Bearer ")

      expect { described_class.new.verify!(token) }
        .to raise_error(Authentication::JwtVerifier::Error) { |error|
          expect(error.code).to eq("session_expired")
        }
    end
  end

  it "rejects stale session versions" do
    keyring_json = JSON.generate(keys: [
      { kid: "test-active", secret: Authentication::JwtVerifier::DEVELOPMENT_SECRET, status: "active" }
    ])

    with_env("AUTH_JWT_KEYRING_JSON" => keyring_json) do
      headers, auth_actor, = session_auth_headers(actor_id: "stale-session-actor")
      auth_actor.update!(session_version: 2)
      token = headers.fetch("Authorization").delete_prefix("Bearer ")

      expect { described_class.new.verify!(token) }
        .to raise_error(Authentication::JwtVerifier::Error) { |error|
          expect(error.code).to eq("session_version_stale")
        }
    end
  end

  it "rejects missing sessions" do
    keyring_json = JSON.generate(keys: [
      { kid: "test-active", secret: Authentication::JwtVerifier::DEVELOPMENT_SECRET, status: "active" }
    ])

    with_env("AUTH_JWT_KEYRING_JSON" => keyring_json) do
      headers, _actor, auth_session = session_auth_headers(actor_id: "missing-session-actor")
      auth_session.destroy!
      token = headers.fetch("Authorization").delete_prefix("Bearer ")

      expect { described_class.new.verify!(token) }
        .to raise_error(Authentication::JwtVerifier::Error) { |error|
          expect(error.code).to eq("session_not_found")
        }
    end
  end
end
