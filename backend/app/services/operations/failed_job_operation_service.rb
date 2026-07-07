module Operations
  class FailedJobOperationService
    REASON_TEMPLATES = {
      "transient_failure_recovered" => "一時的な障害が解消したため再実行します。",
      "operator_confirmed_safe_retry" => "運用者が副作用リスクを確認したため再実行します。",
      "manually_resolved" => "手動対応済みのため破棄します。",
      "unsafe_to_retry" => "再実行による副作用を避けるため破棄します。"
    }.freeze

    ACTIONS = %w[retry discard].freeze

    Result = Struct.new(:success?, :data, :code, :message, :http_status, :details, keyword_init: true)

    def initialize(project:, actor_id:, failed_job_id:, action:, reason_template:)
      @project = project
      @actor_id = actor_id
      @failed_job_id = failed_job_id
      @action = action.to_s
      @reason_template = reason_template.to_s
    end

    def call
      return invalid_action unless ACTIONS.include?(action)
      return invalid_reason_template if reason_template_label.blank?

      failed_execution = find_failed_execution
      return failed_job_not_found unless failed_execution

      job = failed_execution.job
      project_boundary = FailedJobProjectResolver.new(job).call
      return failed_job_project_boundary_rejected(project_boundary) unless project_boundary.verified_for?(project)

      data = operation_data(failed_execution, job, project_boundary)

      perform_operation!(failed_execution)
      record_audit_log!(data)

      Result.new(success?: true, data: data.merge(operated_at: Time.current.iso8601))
    rescue ActiveRecord::ActiveRecordError
      Result.new(
        success?: false,
        code: "failed_job_operation_unavailable",
        message: "Failed job operation is unavailable.",
        http_status: :unprocessable_entity,
        details: { failed_job_id: failed_job_id }
      )
    end

    private

    attr_reader :project, :actor_id, :failed_job_id, :action, :reason_template

    def find_failed_execution
      SolidQueue::FailedExecution.includes(:job).find_by(id: failed_job_id)
    rescue NameError
      nil
    end

    def perform_operation!(failed_execution)
      action == "retry" ? failed_execution.retry : failed_execution.discard
    end

    def operation_data(failed_execution, job, project_boundary)
      {
        failed_job_id: failed_execution.id,
        job_id: failed_execution.job_id,
        product_job_id: project_boundary.product_job.id,
        project_id: project.id,
        project_boundary_status: "verified",
        action: action,
        queue_name: job&.queue_name || "unknown",
        class_name: job&.class_name || "unknown",
        active_job_id: job&.active_job_id,
        reason_template: reason_template
      }.compact
    end

    def record_audit_log!(data)
      AuditLog.record!(
        project: project,
        action: audit_action,
        target: project,
        actor_id: actor_id,
        summary: audit_summary,
        metadata: data.merge(
          operator_actor_id: actor_id,
          reason_template_label: reason_template_label
        )
      )
    end

    def failed_job_project_boundary_rejected(project_boundary)
      record_boundary_rejection!(project_boundary)
      failed_job_not_found
    end

    def record_boundary_rejection!(project_boundary)
      AuditLog.record!(
        project: project,
        action: "operations.failed_job_project_boundary_rejected",
        target: project,
        actor_id: actor_id,
        summary: "失敗ジョブ操作のProject境界検証に失敗しました。",
        metadata: {
          failed_job_id: failed_job_id,
          operator_actor_id: actor_id
        }.merge(project_boundary.safe_metadata(project: project))
      )
    end

    def audit_action
      action == "retry" ? "operations.failed_job_retried" : "operations.failed_job_discarded"
    end

    def audit_summary
      action == "retry" ? "失敗ジョブの再実行が要求されました。" : "失敗ジョブの破棄が要求されました。"
    end

    def reason_template_label
      REASON_TEMPLATES[reason_template]
    end

    def invalid_action
      Result.new(
        success?: false,
        code: "failed_job_operation_invalid",
        message: "失敗ジョブ操作が不正です。",
        http_status: :unprocessable_entity,
        details: { action: action }
      )
    end

    def invalid_reason_template
      Result.new(
        success?: false,
        code: "failed_job_reason_template_invalid",
        message: "失敗ジョブ操作理由が不正です。",
        http_status: :unprocessable_entity,
        details: { reason_template: reason_template, allowed_reason_templates: REASON_TEMPLATES.keys }
      )
    end

    def failed_job_not_found
      Result.new(
        success?: false,
        code: "failed_job_not_found",
        message: "失敗ジョブが見つかりませんでした。",
        http_status: :not_found,
        details: { failed_job_id: failed_job_id }
      )
    end
  end
end
