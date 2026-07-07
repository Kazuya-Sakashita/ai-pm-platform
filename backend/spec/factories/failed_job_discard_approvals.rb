FactoryBot.define do
  factory :failed_job_discard_approval do
    project
    failed_job_id { "456" }
    solid_queue_job_id { "123" }
    product_job_id { create(:job, project: project).id }
    queue_name { "github_reconciliation" }
    class_name { "GithubIssuePublish::ReconciliationRetryJob" }
    reason_template { "manually_resolved" }
    discard_safety_confirmed { true }
    status { "pending" }
    requested_by_actor_id { "operator-1" }
    requested_by_role { "admin" }
    expires_at { 30.minutes.from_now }

    trait :approved do
      status { "approved" }
      requested_by_actor_id { "requester-actor" }
      requested_by_role { "admin" }
      approved_by_actor_id { "approver-actor" }
      approved_by_role { "owner" }
      approval_note { "対象と復旧不要の根拠を確認しました。" }
      approved_at { 5.minutes.ago }
    end

    trait :expired do
      status { "approved" }
      requested_by_actor_id { "requester-actor" }
      requested_by_role { "admin" }
      approved_by_actor_id { "approver-actor" }
      approved_by_role { "owner" }
      approval_note { "対象と復旧不要の根拠を確認しました。" }
      approved_at { 35.minutes.ago }
      expires_at { 1.minute.ago }
    end
  end
end
