FactoryBot.define do
  factory :security_event do
    actor_id { "system" }
    action { "auth.token.rejected" }
    target_type { "token" }
    target_id { "token-digest" }
    severity { "warning" }
    metadata { {} }
  end
end
