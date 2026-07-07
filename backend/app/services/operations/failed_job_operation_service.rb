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

    def initialize(
      project:,
      actor_id:,
      failed_job_id:,
      action:,
      reason_template:,
      discard_safety_confirmed: false,
      discard_approval_id: nil,
      notification_service: FailedJobNotificationService.new
    )
      @project = project
      @actor_id = actor_id
      @failed_job_id = failed_job_id
      @action = action.to_s
      @reason_template = reason_template.to_s
      @discard_safety_confirmed = ActiveModel::Type::Boolean.new.cast(discard_safety_confirmed)
      @discard_approval_id = discard_approval_id.to_s.presence
      @notification_service = notification_service
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
      if discard?
        operation_error = perform_discard_operation_with_approval!(failed_execution, data)
        return operation_error if operation_error&.success? == false
      else
        perform_operation!(failed_execution)
        record_audit_log!(data)
      end
      notify_operation_executed(data)

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

    attr_reader :project, :actor_id, :failed_job_id, :action, :reason_template, :discard_safety_confirmed, :discard_approval_id, :notification_service

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
        product_job_mapping_source: project_boundary.product_job_mapping_source,
        action: action,
        queue_name: job&.queue_name || "unknown",
        class_name: job&.class_name || "unknown",
        active_job_id: job&.active_job_id,
        reason_template: reason_template,
        discard_safety_confirmed: discard? ? true : nil,
        discard_approval_id: discard_approval_id
      }.compact
    end

    def perform_discard_operation_with_approval!(failed_execution, data)
      return discard_approval_required if discard_approval_id.blank?

      operation_error = nil
      ActiveRecord::Base.transaction do
        approval = project.failed_job_discard_approvals.lock.find_by(id: discard_approval_id)
        operation_error = ensure_discard_approval!(approval, data)
        next if operation_error&.success? == false

        data.merge!(discard_approval_data(approval))
        perform_operation!(failed_execution)
        consume_discard_approval!(approval)
        data.merge!(
          discard_approval_status: approval.status,
          discard_approval_consumed_by_actor_id: approval.consumed_by_actor_id,
          discard_approval_consumed_at: approval.consumed_at.iso8601
        )
        record_audit_log!(data)
      end

      operation_error
    end

    def ensure_discard_approval!(approval, data)
      return discard_approval_not_found unless approval
      return discard_approval_expired(approval) if approval.expired?
      return discard_approval_not_approved(approval) unless approval.approved?
      return discard_approval_mismatch(approval) unless discard_approval_matches?(approval, data)

      Result.new(success?: true, data: { approval: approval })
    end

    def discard_approval_data(approval)
      {
        discard_approval_id: approval.id,
        discard_approval_status: approval.status,
        discard_approval_requested_by_actor_id: approval.requested_by_actor_id,
        discard_approval_approved_by_actor_id: approval.approved_by_actor_id,
        discard_approval_expires_at: approval.expires_at.iso8601
      }
    end

    def discard_approval_matches?(approval, data)
      approval.project_id == project.id &&
        approval.failed_job_id.to_s == data[:failed_job_id].to_s &&
        approval.solid_queue_job_id.to_s == data[:job_id].to_s &&
        approval.product_job_id == data[:product_job_id] &&
        approval.reason_template == reason_template &&
        approval.discard_safety_confirmed? &&
        approval.approved_by_actor_id.present? &&
        approval.requested_by_actor_id != approval.approved_by_actor_id
    end

    def consume_discard_approval!(approval)
      approval.update!(
        status: "consumed",
        consumed_by_actor_id: actor_id,
        consumed_by_role: actor_project_role,
        consumed_at: Time.current
      )
    end

    def actor_project_role
      project.project_memberships.active.find_by(actor_id: actor_id)&.role
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

    def notify_operation_executed(data)
      notification_service.notify_operation_executed(
        project: project,
        actor_id: actor_id,
        operation_data: data,
        audit_log_action: audit_action
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

    def discard_approval_required
      Result.new(
        success?: false,
        code: "failed_job_discard_approval_required",
        message: "失敗ジョブ破棄には二人承認が必要です。",
        http_status: :unprocessable_entity,
        details: { action: action, discard_approval_id: "required" }
      )
    end

    def discard_approval_not_found
      Result.new(
        success?: false,
        code: "failed_job_discard_approval_not_found",
        message: "失敗ジョブ破棄承認が見つかりませんでした。",
        http_status: :not_found,
        details: { discard_approval_id: discard_approval_id }
      )
    end

    def discard_approval_not_approved(approval)
      Result.new(
        success?: false,
        code: "failed_job_discard_approval_not_approved",
        message: "失敗ジョブ破棄承認が完了していません。",
        http_status: :unprocessable_entity,
        details: approval.api_json
      )
    end

    def discard_approval_expired(approval)
      approval.update!(status: "expired") if approval.pending? || approval.approved?
      AuditLog.record!(
        project: project,
        action: "operations.failed_job_discard_approval_expired",
        target: approval,
        actor_id: actor_id,
        summary: "失敗ジョブ破棄の二人承認が期限切れになりました。",
        metadata: approval.safe_metadata
      )
      Result.new(
        success?: false,
        code: "failed_job_discard_approval_expired",
        message: "失敗ジョブ破棄承認の期限が切れています。",
        http_status: :unprocessable_entity,
        details: approval.api_json
      )
    end

    def discard_approval_mismatch(approval)
      Result.new(
        success?: false,
        code: "failed_job_discard_approval_mismatch",
        message: "失敗ジョブ破棄承認の対象が一致しません。",
        http_status: :not_found,
        details: { discard_approval_id: approval.id, failed_job_id: failed_job_id }
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
