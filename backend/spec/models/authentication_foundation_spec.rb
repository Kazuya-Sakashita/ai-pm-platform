require "rails_helper"

RSpec.describe "Authentication foundation models" do
  it "stores only jti digests for token revocations" do
    raw_jti = "raw-token-id"
    revocation = create(:auth_token_revocation, jti_digest: AuthTokenRevocation.digest_jti(raw_jti))

    expect(revocation.jti_digest).to eq(Digest::SHA256.hexdigest(raw_jti))
    expect(revocation.attributes.to_s).not_to include(raw_jti)
  end

  it "records security events with safe metadata" do
    event = SecurityEvent.record!(
      action: "auth.session.revoked",
      target_type: "auth_session",
      target_id: "session-1",
      actor_id: "admin-actor",
      severity: "warning",
      metadata: { code: "session_revoked", jti_digest_prefix: "abc123" }
    )

    expect(event).to be_persisted
    expect(event.metadata).to eq("code" => "session_revoked", "jti_digest_prefix" => "abc123")
  end
end
