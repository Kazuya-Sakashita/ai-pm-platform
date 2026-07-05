require "rails_helper"

RSpec.describe "API V1 auth sessions", type: :request do
  let(:keyring_json) do
    JSON.generate(keys: [
      { kid: "test-active", secret: Authentication::JwtVerifier::DEVELOPMENT_SECRET, status: "active" }
    ])
  end

  it "requires a session-backed JWT for session APIs" do
    with_env("AUTH_JWT_KEYRING_JSON" => keyring_json) do
      get "/api/v1/auth/sessions", headers: auth_headers("actor-without-session-claims")
    end

    body = JSON.parse(response.body)
    expect(response).to have_http_status(:unauthorized)
    expect(body.dig("error", "code")).to eq("invalid_token")
  end

  it "lists only the current actor sessions without leaking internal session metadata" do
    headers, auth_actor, current_session, raw_jti = session_auth_headers(actor_id: "session-list-owner", jti: "raw-current-jti")
    current_session.update!(ip_hash: "private-current-ip-hash", user_agent_hash: "private-current-ua-hash")
    other_session = create(
      :auth_session,
      auth_actor: auth_actor,
      actor_subject: auth_actor.subject,
      sid: "private-other-sid",
      ip_hash: "private-other-ip-hash",
      user_agent_hash: "private-other-ua-hash"
    )
    foreign_session = create(:auth_session, sid: "private-foreign-sid")

    with_env("AUTH_JWT_KEYRING_JSON" => keyring_json) do
      get "/api/v1/auth/sessions", headers: headers
    end

    body = JSON.parse(response.body)
    session_ids = body.fetch("data").map { |session| session.fetch("id") }
    body_text = response.body

    expect(response).to have_http_status(:ok)
    expect(session_ids).to include(current_session.id, other_session.id)
    expect(session_ids).not_to include(foreign_session.id)
    expect(body.fetch("data").find { |session| session.fetch("id") == current_session.id }.fetch("current")).to be(true)
    expect(body.dig("meta", "current_session_id")).to eq(current_session.id)
    expect(body_text).not_to include(current_session.sid, other_session.sid, foreign_session.sid, raw_jti)
    expect(body_text).not_to include("private-current-ip-hash", "private-current-ua-hash", "private-other-ip-hash", "private-other-ua-hash")
  end

  it "revokes the current session and rejects the same token afterwards" do
    project = create(:project)
    headers, _auth_actor, current_session, raw_jti = session_auth_headers(actor_id: "current-logout-owner", jti: "raw-current-logout-jti")
    create(:project_membership, project: project, actor_id: "current-logout-owner", role: "owner")

    with_env("AUTH_JWT_KEYRING_JSON" => keyring_json) do
      delete "/api/v1/auth/sessions/current", headers: headers
    end

    body = JSON.parse(response.body)
    expect(response).to have_http_status(:ok)
    expect(body.dig("data", "id")).to eq(current_session.id)
    expect(body.dig("data", "status")).to eq("revoked")
    expect(response.body).not_to include(current_session.sid, raw_jti)

    event = SecurityEvent.order(:created_at).last
    expect(event.action).to eq("auth.session.revoked")
    expect(event.metadata.to_json).not_to include(current_session.sid, raw_jti, "Authorization")

    with_env("AUTH_JWT_KEYRING_JSON" => keyring_json) do
      get "/api/v1/projects", headers: headers
    end

    body = JSON.parse(response.body)
    expect(response).to have_http_status(:unauthorized)
    expect(body.dig("error", "code")).to eq("session_revoked")
    expect(body.to_s).not_to include(project.name)
  end

  it "revokes another owned session and hides foreign sessions behind not_found" do
    headers, auth_actor, current_session = session_auth_headers(actor_id: "device-revoke-owner", jti: "raw-device-revoke-jti")
    owned_session = create(:auth_session, auth_actor: auth_actor, actor_subject: auth_actor.subject, sid: "owned-private-sid")
    foreign_session = create(:auth_session, sid: "foreign-private-sid")

    with_env("AUTH_JWT_KEYRING_JSON" => keyring_json) do
      delete "/api/v1/auth/sessions/#{owned_session.id}", headers: headers
    end

    body = JSON.parse(response.body)
    expect(response).to have_http_status(:ok)
    expect(body.dig("data", "id")).to eq(owned_session.id)
    expect(body.dig("data", "status")).to eq("revoked")
    expect(response.body).not_to include(owned_session.sid, current_session.sid)

    with_env("AUTH_JWT_KEYRING_JSON" => keyring_json) do
      delete "/api/v1/auth/sessions/#{foreign_session.id}", headers: headers
    end

    body = JSON.parse(response.body)
    expect(response).to have_http_status(:not_found)
    expect(body.dig("error", "code")).to eq("not_found")
    expect(response.body).not_to include(foreign_session.sid)
  end

  it "logs out everywhere by revoking active sessions and advancing actor session version" do
    headers, auth_actor, current_session, raw_jti = session_auth_headers(actor_id: "logout-everywhere-owner", jti: "raw-everywhere-jti")
    create(:auth_session, auth_actor: auth_actor, actor_subject: auth_actor.subject, sid: "second-private-sid")
    create(:auth_session, auth_actor: auth_actor, actor_subject: auth_actor.subject, sid: "already-revoked-private-sid", status: "revoked")

    with_env("AUTH_JWT_KEYRING_JSON" => keyring_json) do
      post "/api/v1/auth/logout-everywhere", headers: headers
    end

    body = JSON.parse(response.body)
    expect(response).to have_http_status(:ok)
    expect(body.dig("data", "revoked_session_count")).to eq(2)
    expect(body.dig("data", "session_version")).to eq(2)
    expect(auth_actor.reload.session_version).to eq(2)
    expect(auth_actor.auth_sessions.where(status: "active")).to be_empty
    expect(response.body).not_to include(current_session.sid, raw_jti)

    event = SecurityEvent.order(:created_at).last
    expect(event.action).to eq("auth.sessions.revoked")
    expect(event.metadata.to_json).not_to include(current_session.sid, "second-private-sid", raw_jti)

    with_env("AUTH_JWT_KEYRING_JSON" => keyring_json) do
      get "/api/v1/projects", headers: headers
    end

    body = JSON.parse(response.body)
    expect(response).to have_http_status(:unauthorized)
    expect(%w[session_revoked session_version_stale]).to include(body.dig("error", "code"))
  end
end
