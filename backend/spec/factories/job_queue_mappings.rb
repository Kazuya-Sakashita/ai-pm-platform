FactoryBot.define do
  factory :job_queue_mapping do
    association :product_job, factory: :job
    project { product_job.project }
    provider { "solid_queue" }
    sequence(:solid_queue_job_id) { |number| number }
    active_job_id { SecureRandom.uuid }
    queue_name { "github_reconciliation" }
    job_class_name { "GithubIssuePublish::ReconciliationRetryJob" }
    scheduled_at { 1.minute.from_now }
  end
end
