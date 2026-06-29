FactoryBot.define do
  factory :job do
    project
    job_type { "ai_generation" }
    status { "queued" }
    target_type { "meeting" }
    target_id { SecureRandom.uuid }
    progress { 0 }
  end
end
