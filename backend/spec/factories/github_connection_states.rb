FactoryBot.define do
  factory :github_connection_state do
    project
    repository_owner { "Kazuya-Sakashita" }
    repository_name { "ai-pm-platform" }
    nonce_digest { Digest::SHA256.hexdigest(SecureRandom.hex(32)) }
    state_digest { Digest::SHA256.hexdigest(SecureRandom.hex(64)) }
    redirect_uri { "https://app.ai-pm-platform.test/integrations/github/callback" }
    expires_at { 15.minutes.from_now }
  end
end
