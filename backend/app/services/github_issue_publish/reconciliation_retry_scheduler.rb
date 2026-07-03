module GithubIssuePublish
  class ReconciliationRetryScheduler
    def self.call(attempt, available_at:)
      new(attempt, available_at: available_at).call
    end

    def initialize(attempt, available_at:)
      @attempt = attempt
      @available_at = available_at
    end

    def call
      return unless available_at
      return unless attempt.status == "reconciliation_required"

      job = attempt.project.jobs.create!(
        job_type: "github_reconciliation",
        status: "queued",
        target_type: "github_issue_publish_attempt",
        target_id: attempt.id,
        progress: 0
      )

      GithubIssuePublish::ReconciliationRetryJob
        .set(wait_until: available_at)
        .perform_later(attempt.id, job.id)

      AuditLog.record!(
        project: attempt.project,
        action: "issue_draft.github_publish_reconciliation_retry_scheduled",
        target: attempt.issue_draft,
        summary: "GitHub Issue publish reconciliation retry was scheduled.",
        metadata: {
          attempt_id: attempt.id,
          job_id: job.id,
          reconciliation_retry_count: attempt.reconciliation_retry_count,
          next_reconciliation_retry_at: available_at.iso8601,
          safe_error_code: attempt.safe_error_code
        }.compact
      )

      job
    end

    private

    attr_reader :attempt, :available_at
  end
end
