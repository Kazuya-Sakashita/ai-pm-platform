FactoryBot.define do
  factory :auth_token_revocation do
    jti_digest { AuthTokenRevocation.digest_jti("revoked-token") }
    expires_at { 30.minutes.from_now }
    reason { "incident" }
  end
end
