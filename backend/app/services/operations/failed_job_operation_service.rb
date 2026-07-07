module Operations
  class FailedJobOperationService
    RETRY_REASON_TEMPLATES = {
      "transient_failure_recovered" => "一時的な障害が解消したため再実行します。",
      "operator_confirmed_safe_retry" => "運用者が副作用リスクを確認したため再実行します。"
    }.freeze

    DISCARD_REASON_TEMPLATES = {
      "manually_resolved" => "手動対応済みのため破棄します。",
      "unsafe_to_retry" => "再実行による副作用を避けるため破棄します。"
    }.freeze

    REASON_TEMPLATES = RETRY_REASON_TEMPLATES.merge(DISCARD_REASON_TEMPLATES).freeze

    ACTIONS = %w[retry discard].freeze

    Result = Struct.new(:success?, :data, :code, :message, :http_status, :details, keyword_init: true)

    def initialize(project:, actor_id:, failed_job_id:, action:, reason_template:, discard_safety_confirmed: false)
      @project = project
      @actor_id = actor_id
      @failed_job_id = failed_job_id
      @action = action.to_s
      @reason_template = reason_template.to_s
      @discard_safety_confirmed = ActiveModel::Type::Boolean.new.cast(discard_safety_confirmed)
    end

    def call
      return invalid_action unless ACTIONS.include?(action)
      return invalid_reason_template if reason_template_label.blank?
      return discard_confirmation_required if discard? && !discard_safety_confirmed

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

    attr_reader :project, :actor_id, :failed_job_id, :action, :reason_template, :discard_safety_confirmed

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
        reason_template: reason_template,
        discard_safety_confirmed: discard? ? true : nil
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
      retry? ? "operations.failed_job_retried" : "operations.failed_job_discarded"
    end

    def audit_summary
      retry? ? "失敗ジョブの再実行が要求されました。" : "失敗ジョブの破棄が要求されました。"
    end

    def reason_template_label
      reason_templates_for_action[reason_template]
    end

    def reason_templates_for_action
      retry? ? RETRY_REASON_TEMPLATES : DISCARD_REASON_TEMPLATES
    end

    def retry?
      action == "retry"
    end

    def discard?
      action == "discard"
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
        details: { action: action, reason_template: reason_template, allowed_reason_templates: reason_templates_for_action.keys }
      )
    end

    def discard_confirmation_required
      Result.new(
        success?: false,
        code: "failed_job_discard_confirmation_required",
        message: "失敗ジョブを破棄する前にリスク確認が必要です。",
        http_status: :unprocessable_entity,
        details: { action: action, discard_safety_confirmed: false }
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
