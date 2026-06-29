FactoryBot.define do
  factory :project do
    name { "AI PM Platform" }
    description { "Meeting-to-development workflow" }
    status { "active" }
    github_repo { "Kazuya-Sakashita/ai-pm-platform" }
  end
end
