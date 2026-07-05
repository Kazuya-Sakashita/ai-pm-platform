FactoryBot.define do
  factory :auth_actor do
    sequence(:subject) { |n| "actor-#{n}" }
    status { "active" }
    session_version { 1 }
  end
end
