FactoryBot.define do
  factory :meeting do
    project
    title { "MVP planning" }
    source_type { "manual" }
    meeting_date { Date.new(2026, 6, 30) }
    participants { ["Product", "Engineering"] }
    raw_text { "Discussed MVP scope and review gates." }
    status { "draft" }
  end
end
