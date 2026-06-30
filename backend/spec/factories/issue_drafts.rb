FactoryBot.define do
  factory :issue_draft do
    requirement { association :requirement, status: "approved", open_questions: [] }
    status { "draft" }
    title { "Generate requirements from approved minutes" }
    body { "## Background\nRequirement draft body." }
    acceptance_criteria { ["Given approved requirements, when the draft is generated, then it can be reviewed."] }
    labels { %w[ai-generated requirement needs-review] }
  end
end
