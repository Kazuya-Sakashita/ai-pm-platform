FactoryBot.define do
  factory :review do
    target_type { "meeting" }
    target_id { SecureRandom.uuid }
    status { "open" }
    reviewer_role { "Tech Lead" }
    framework { ["G-STACK"] }
    positives { ["Clear scope"] }
    improvements { ["Add contract checks"] }
    priority { ["P0: Add request specs"] }
    next_actions { ["Implement API"] }
    issue_numbers { ["ISSUE-015"] }
  end
end
