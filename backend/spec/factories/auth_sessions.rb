FactoryBot.define do
  factory :auth_session do
    association :auth_actor
    sequence(:sid) { |n| "session-#{n}" }
    actor_subject { auth_actor.subject }
    status { "active" }
    session_version { auth_actor.session_version }
    issued_at { Time.current }
    expires_at { 30.minutes.from_now }
  end
end
