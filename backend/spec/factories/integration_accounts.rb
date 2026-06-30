FactoryBot.define do
  factory :integration_account do
    project
    provider { "github" }
    status { "connected" }
    external_account_id { "123456" }
    repository_owner { "Kazuya-Sakashita" }
    repository_name { "ai-pm-platform" }
    github_installation_id { "123456" }
    github_account_login { "Kazuya-Sakashita" }
    github_account_type { "User" }
    granted_permissions { { "metadata" => "read", "issues" => "write" } }
  end
end
