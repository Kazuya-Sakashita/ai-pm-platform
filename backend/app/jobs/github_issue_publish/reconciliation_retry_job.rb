module GithubIssuePublish
  class ReconciliationRetryJob < ApplicationJob
    queue_as :github_reconciliation

    def perform(attempt_id, job_id = nil)
      attempt = GithubIssuePublishAttempt.find(attempt_id)
      job = Job.find_by(id: job_id)

      return cancel_job!(job, attempt) unless attempt.status == "reconciliation_required"
      return reschedule_if_still_cooling_down!(attempt, job) if attempt.reconciliation_cooldown_active?

      job&.update!(status: "running", progress: 10)

      result = GithubIssuePublish::ReconciliationService.new(attempt).call
      job&.update!(status: "succeeded", progress: 100)

      AuditLog.record!(
        project: attempt.project,
        action: "issue_draft.github_publish_reconciliation_retry_finished",
        target: attempt.issue_draft,
        summary: "GitHub Issue publish reconciliation retry finished.",
        metadata: {
          attempt_id: attempt.id,
          job_id: job&.id,
          result_status: result.status,
          match_count: result.matches.count,
          review_id: result.review&.id
        }.compact
      )
    rescue GithubIssuePublish::ProviderError => e
      job&.update!(
        status: "failed",
        progress: 100,
        error_code: e.code,
        error_message: e.message,
        safe_error_detail: e.safe_detail
      )
      AuditLog.record!(
        project: attempt.project,
        action: "issue_draft.github_publish_reconciliation_retry_failed",
        target: attempt.issue_draft,
        summary: "GitHub Issue publish reconciliation retry failed.",
        metadata: {
          attempt_id: attempt.id,
          job_id: job&.id,
          provider_error_code: e.code
        }.merge(e.safe_metadata).compact
      )
      raise
    end

    private

    def cancel_job!(job, attempt)
      job&.update!(
        status: "cancelled",
        progress: 100,
        safe_error_detail: "GitHub reconciliation attempt is no longer pending."
      )
      AuditLog.record!(
        project: attempt.project,
        action: "issue_draft.github_publish_reconciliation_retry_cancelled",
        target: attempt.issue_draft,
        summary: "GitHub Issue publish reconciliation retry was cancelled.",
        metadata: {
          attempt_id: attempt.id,
          job_id: job&.id,
          attempt_status: attempt.status
        }.compact
      )
    end

    def reschedule_if_still_cooling_down!(attempt, job)
      available_at = attempt.next_reconciliation_retry_at
      return unless available_at

      enqueued_job = GithubIssuePublish::ReconciliationRetryJob
        .set(wait_until: available_at)
        .perform_later(attempt.id, job&.id)
      queue_mapping = record_queue_mapping(job, enqueued_job, available_at)

      AuditLog.record!(
        project: attempt.project,
        action: "issue_draft.github_publish_reconciliation_retry_rescheduled",
        target: attempt.issue_draft,
        summary: "GitHub Issue publish reconciliation retry remained in cooldown and was rescheduled.",
        metadata: {
          attempt_id: attempt.id,
          job_id: job&.id,
          solid_queue_job_id: queue_mapping&.solid_queue_job_id,
          active_job_id: queue_mapping&.active_job_id,
          product_job_mapping_source: queue_mapping ? "explicit" : nil,
          next_reconciliation_retry_at: available_at.iso8601
        }.compact
      )
    end

    def record_queue_mapping(job, enqueued_job, scheduled_at)
      return nil unless job

      JobQueueMapping.record_solid_queue!(
        product_job: job,
        active_job: enqueued_job,
        queue_name: GithubIssuePublish::ReconciliationRetryJob.queue_name,
        job_class_name: GithubIssuePublish::ReconciliationRetryJob.name,
        scheduled_at: scheduled_at
      )
    rescue ActiveRecord::ActiveRecordError => e
      AuditLog.record!(
        project: job.project,
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
