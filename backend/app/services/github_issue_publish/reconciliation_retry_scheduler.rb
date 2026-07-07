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

      enqueued_job = GithubIssuePublish::ReconciliationRetryJob
        .set(wait_until: available_at)
        .perform_later(attempt.id, job.id)
      queue_mapping = record_queue_mapping(job, enqueued_job)

      AuditLog.record!(
        project: attempt.project,
        action: "issue_draft.github_publish_reconciliation_retry_scheduled",
        target: attempt.issue_draft,
        summary: "GitHub Issue publish reconciliation retry was scheduled.",
        metadata: {
          attempt_id: attempt.id,
          job_id: job.id,
          solid_queue_job_id: queue_mapping&.solid_queue_job_id,
          active_job_id: queue_mapping&.active_job_id,
          product_job_mapping_source: queue_mapping ? "explicit" : nil,
          reconciliation_retry_count: attempt.reconciliation_retry_count,
          next_reconciliation_retry_at: available_at.iso8601,
          safe_error_code: attempt.safe_error_code
        }.compact
      )

      job
    end

    private

    attr_reader :attempt, :available_at

    def record_queue_mapping(job, enqueued_job)
      JobQueueMapping.record_solid_queue!(
        product_job: job,
        active_job: enqueued_job,
        queue_name: GithubIssuePublish::ReconciliationRetryJob.queue_name,
        job_class_name: GithubIssuePublish::ReconciliationRetryJob.name,
        scheduled_at: available_at
      )
    rescue ActiveRecord::ActiveRecordError => e
      AuditLog.record!(
        project: attempt.project,
        action: "job_queue_mapping.record_failed",
        target: job,
        summary: "Solid Queue job mappingの保存に失敗しました。",
        metadata: {
          job_id: job.id,
          active_job_id: enqueued_job&.job_id,
          provider_job_id_present: enqueued_job&.provider_job_id.present?,
          error_class: e.class.name
        }.compact
      )
      nil
    end
  end
end
