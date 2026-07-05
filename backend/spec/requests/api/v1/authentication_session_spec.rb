require "rails_helper"

RSpec.describe "API V1 authentication session foundation", type: :request do
  let(:keyring_json) do
    JSON.generate(keys: [
      { kid: "test-active", secret: Authentication::JwtVerifier::DEVELOPMENT_SECRET, status: "active" }
    ])
  end

  it "accepts a session-backed JWT for protected project APIs" do
    project = create(:project, name: "Session protected")
    headers, = session_auth_headers(actor_id: "session-project-owner")
    create(:project_membership, project: project, actor_id: "session-project-owner", role: "owner")

    with_env("AUTH_JWT_KEYRING_JSON" => keyring_json) do
      get "/api/v1/projects", headers: headers
    end

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig("data", 0, "name")).to eq("Session protected")
  end

  it "rejects a revoked session before project authorization" do
    project = create(:project, name: "Do not leak")
    headers, _actor, auth_session = session_auth_headers(actor_id: "revoked-project-owner", jti: "request-revoked-session")
    create(:project_membership, project: project, actor_id: "revoked-project-owner", role: "owner")
    auth_session.update!(status: "revoked", revoked_at: Time.current, revocation_reason: "admin_forced")

    with_env("AUTH_JWT_KEYRING_JSON" => keyring_json) do
      get "/api/v1/projects", headers: headers
    end

    body = JSON.parse(response.body)
    expect(response).to have_http_status(:unauthorized)
    expect(body.dig("error", "code")).to eq("session_revoked")
    expect(body.to_s).not_to include("Do not leak", "request-revoked-session")
  end

  it "does not fall back to X-Actor-Id when Bearer authentication fails" do
    project = create(:project, name: "Spoofed")
    create(:project_membership, project: project, actor_id: "spoofed-owner", role: "owner")

    get "/api/v1/projects", headers: {
      "Authorization" => "Bearer not-a-jwt",
      "X-Actor-Id" => "spoofed-owner"
    }

    body = JSON.parse(response.body)
    expect(response).to have_http_status(:unauthorized)
    expect(body.dig("error", "code")).to eq("invalid_token")
    expect(body.to_s).not_to include("Spoofed")
  end
end
