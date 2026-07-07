module Operations
  class FailedJobDiscardApprovalService
    APPROVAL_TTL = 30.minutes

    Result = Struct.new(:success?, :data, :code, :message, :http_status, :details, keyword_init: true)

    def initialize(
      project:,
      actor_id:,
      failed_job_id: nil,
      approval_id: nil,
      reason_template: nil,
      discard_safety_confirmed: false,
      approval_note: nil,
      rejection_reason: nil,
      clock: -> { Time.current }
    )
      @project = project
      @actor_id = actor_id
      @failed_job_id = failed_job_id
      @approval_id = approval_id
      @reason_template = reason_template.to_s
      @discard_safety_confirmed = ActiveModel::Type::Boolean.new.cast(discard_safety_confirmed)
      @approval_note = approval_note.to_s.strip
      @rejection_reason = rejection_reason.to_s.strip
      @clock = clock
    end

    def request
      return invalid_reason_template unless discard_reason_template_label
      return discard_confirmation_required unless discard_safety_confirmed

      failed_execution = find_failed_execution
      return failed_job_not_found unless failed_execution

      job = failed_execution.job
      project_boundary = FailedJobProjectResolver.new(job).call
      return failed_job_project_boundary_rejected(project_boundary) unless project_boundary.verified_for?(project)

      existing_approval = active_existing_approval(failed_execution)
      return expire_approval(existing_approval) if existing_approval&.expired?(now)
      return success_result(existing_approval) if existing_approval

      approval = project.failed_job_discard_approvals.create!(
        failed_job_id: failed_execution.id.to_s,
        solid_queue_job_id: failed_execution.job_id.to_s,
        product_job_id: project_boundary.product_job.id,
        queue_name: job&.queue_name || "unknown",
        class_name: job&.class_name || "unknown",
        reason_template: reason_template,
        discard_safety_confirmed: true,
        requested_by_actor_id: actor_id,
        requested_by_role: actor_role(actor_id),
        expires_at: now + APPROVAL_TTL
      )
      record_audit_log!(
        action: "operations.failed_job_discard_approval_requested",
        actor_id: actor_id,
        summary: "失敗ジョブ破棄の二人承認が依頼されました。",
        approval: approval
      )

      success_result(approval)
    rescue ActiveRecord::ActiveRecordError
      unavailable_result
    end

    def approve
      approval = find_approval
      return approval_not_found unless approval
      return approval_note_required if approval_note.blank?
      return approval_not_pending(approval) unless approval.pending?
      return expire_approval(approval) if approval.expired?(now)
      return same_actor_rejected(approval) if approval.requested_by_actor_id == actor_id

      approval.update!(
        status: "approved",
        approved_by_actor_id: actor_id,
        approved_by_role: actor_role(actor_id),
        approval_note: approval_note,
        approved_at: now
      )
      record_audit_log!(
        action: "operations.failed_job_discard_approval_approved",
        actor_id: actor_id,
        summary: "失敗ジョブ破棄の二人承認が承認されました。",
        approval: approval
      )

      success_result(approval)
    rescue ActiveRecord::ActiveRecordError
      unavailable_result
    end

    def reject
      approval = find_approval
      return approval_not_found unless approval
      return rejection_reason_required if rejection_reason.blank?
      return approval_not_pending(approval) unless approval.pending?
      return expire_approval(approval) if approval.expired?(now)

      approval.update!(
        status: "rejected",
        rejected_by_actor_id: actor_id,
        rejected_by_role: actor_role(actor_id),
        rejection_reason: rejection_reason,
        rejected_at: now
      )
      record_audit_log!(
        action: "operations.failed_job_discard_approval_rejected",
        actor_id: actor_id,
        summary: "失敗ジョブ破棄の二人承認が却下されました。",
        approval: approval
      )

      success_result(approval)
    rescue ActiveRecord::ActiveRecordError
      unavailable_result
    end

    private

    attr_reader :project, :actor_id, :failed_job_id, :approval_id, :reason_template, :discard_safety_confirmed, :approval_note, :rejection_reason, :clock

    def find_failed_execution
      SolidQueue::FailedExecution.includes(:job).find_by(id: failed_job_id)
    rescue NameError
      nil
    end

    def find_approval
      project.failed_job_discard_approvals.find_by(id: approval_id)
    end

    def active_existing_approval(failed_execution)
      project.failed_job_discard_approvals
        .where(
          failed_job_id: failed_execution.id.to_s,
          reason_template: reason_template,
          status: %w[pending approved]
        )
        .recent_first
        .first
    end

    def expire_approval(approval)
      approval.update!(status: "expired") if approval.pending? || approval.approved?
      record_audit_log!(
        action: "operations.failed_job_discard_approval_expired",
        actor_id: actor_id,
        summary: "失敗ジョブ破棄の二人承認が期限切れになりました。",
        approval: approval
      )
      Result.new(
        success?: false,
        code: "failed_job_discard_approval_expired",
        message: "失敗ジョブ破棄の承認期限が切れています。",
        http_status: :unprocessable_entity,
        details: approval.api_json
      )
    end

    def failed_job_project_boundary_rejected(project_boundary)
      AuditLog.record!(
        project: project,
        action: "operations.failed_job_discard_approval_project_boundary_rejected",
        target: project,
        actor_id: actor_id,
        summary: "失敗ジョブ破棄承認のProject境界検証に失敗しました。",
        metadata: {
          failed_job_id: failed_job_id,
          operator_actor_id: actor_id
        }.merge(project_boundary.safe_metadata(project: project))
      )
      failed_job_not_found
    end

    def record_audit_log!(action:, actor_id:, summary:, approval:)
      AuditLog.record!(
        project: project,
        action: action,
        target: approval,
        actor_id: actor_id,
        summary: summary,
        metadata: approval.safe_metadata
      )
    end

    def discard_reason_template_label
      FailedJobOperationService::DISCARD_REASON_TEMPLATES[reason_template]
    end

    def actor_role(target_actor_id)
      project.project_memberships.active.find_by(actor_id: target_actor_id)&.role
    end

    def now
      clock.call
    end

    def success_result(approval)
      Result.new(success?: true, data: approval.api_json)
    end

    def invalid_reason_template
      Result.new(
        success?: false,
        code: "failed_job_reason_template_invalid",
        message: "失敗ジョブ破棄理由が不正です。",
        http_status: :unprocessable_entity,
        details: { reason_template: reason_template, allowed_reason_templates: FailedJobOperationService::DISCARD_REASON_TEMPLATES.keys }
      )
    end

    def discard_confirmation_required
      Result.new(
        success?: false,
        code: "failed_job_discard_confirmation_required",
        message: "失敗ジョブを破棄承認依頼する前にリスク確認が必要です。",
        http_status: :unprocessable_entity,
        details: { discard_safety_confirmed: false }
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

    def approval_not_found
      Result.new(
        success?: false,
        code: "failed_job_discard_approval_not_found",
        message: "失敗ジョブ破棄承認が見つかりませんでした。",
        http_status: :not_found,
        details: { approval_id: approval_id }
      )
    end

    def approval_note_required
      Result.new(
        success?: false,
        code: "failed_job_discard_approval_note_required",
        message: "失敗ジョブ破棄承認コメントが必要です。",
        http_status: :unprocessable_entity,
        details: { approval_note: "required" }
      )
    end

    def rejection_reason_required
      Result.new(
        success?: false,
        code: "failed_job_discard_rejection_reason_required",
        message: "失敗ジョブ破棄承認の却下理由が必要です。",
        http_status: :unprocessable_entity,
        details: { rejection_reason: "required" }
      )
    end

    def approval_not_pending(approval)
      Result.new(
        success?: false,
        code: "failed_job_discard_approval_not_pending",
        message: "失敗ジョブ破棄承認は保留中ではありません。",
        http_status: :unprocessable_entity,
        details: approval.api_json
      )
    end

    def same_actor_rejected(approval)
      Result.new(
        success?: false,
        code: "failed_job_discard_approval_same_actor",
        message: "申請者と同じactorは失敗ジョブ破棄を承認できません。",
        http_status: :unprocessable_entity,
        details: approval.api_json
      )
    end

    def unavailable_result
      Result.new(
        success?: false,
        code: "failed_job_discard_approval_unavailable",
        message: "失敗ジョブ破棄承認を処理できません。",
        http_status: :unprocessable_entity,
        details: {}
      )
    end
  end
end
