FactoryBot.define do
  factory :project_membership do
    project
    sequence(:actor_id) { |n| "actor-#{n}" }
    role { "editor" }
    status { "active" }
  end
end
