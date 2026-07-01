FactoryBot.define do
  factory :github_issue_publish_attempt do
    issue_draft
    project { issue_draft.requirement.minute.meeting.project }
    github_repository { "Kazuya-Sakashita/ai-pm-platform" }
    idempotency_digest { Digest::SHA256.hexdigest(SecureRandom.uuid) }
    status { "started" }
    started_at { Time.current }
  end
end
