module Api
  module V1
    class RequirementsController < ApplicationController
      def generate
        return unless require_actor!(action: "requirement_generate")

        minutes = Minute.find(params[:id])
        return unless authorize_project_role!(project_for(minutes), action: "requirement_generate", allowed_roles: project_write_roles)
        return render_review_required(minutes) unless minutes.status == "approved"

        job = project_for(minutes).jobs.create!(
          job_type: "ai_generation",
          status: "running",
          target_type: "requirement",
          progress: 10
        )

        requirement = RequirementGenerationService.new(minutes).call
        job.update!(
          status: "succeeded",
          target_id: requirement.id,
          progress: 100
        )

        AuditLog.record!(
          project: project_for(minutes),
          action: "requirement.generated",
          target: requirement,
          actor_id: current_actor_id,
          metadata: { minutes_id: minutes.id, job_id: job.id }
        )

        render json: { data: { job_id: job.id, status: job.status } }, status: :accepted
      rescue RequirementGeneration::ProviderError => e
        job&.update!(
          status: "failed",
          progress: 100,
          error_code: e.code,
          error_message: e.message,
          safe_error_detail: e.safe_detail
        )
        AuditLog.record!(
          project: project_for(minutes),
          action: "requirement.generation_failed",
          target: job,
          actor_id: current_actor_id,
          metadata: { minutes_id: minutes.id, provider_error_code: e.code }
        ) if job && minutes

        render_error(e.code, e.safe_detail, e.http_status, { job_id: job&.id }.compact)
      end

      def show
        return unless require_actor!(action: "requirement_read")
        return unless authorize_project_role!(project_for(requirement.minute), action: "requirement_read", allowed_roles: project_read_roles)

        render json: { data: requirement.api_json }
      end

      def update
        return unless require_actor!(action: "requirement_update")
        return unless authorize_project_role!(project_for(requirement.minute), action: "requirement_update", allowed_roles: project_write_roles)

        if params.key?(:status)
          return render_error(
            "requirement_direct_status_update_not_allowed",
            "要件定義の状態変更は専用APIまたはレビュー操作から実行してください。",
            :unprocessable_entity,
            { requirement_id: requirement.id, approve_endpoint: "/api/v1/requirements/#{requirement.id}/approve" }
          )
        end

        revision = RequirementRevisionService.new(requirement, requirement_params).call
        AuditLog.record!(
          project: project_for(requirement.minute),
          action: "requirement.updated",
          target: requirement,
          actor_id: current_actor_id,
          metadata: {
            changed_fields: revision.changed_fields,
            approval_reset: revision.approval_reset
          }
        )
        render json: { data: requirement.api_json }
      end

      def approve
        return unless require_actor!(action: "requirement_approve")
        return unless authorize_project_role!(project_for(requirement.minute), action: "requirement_approve", allowed_roles: project_review_roles)

        approval_gate = RequirementApprovalGate.new(requirement).call
        return render_requirement_approval_blocked(approval_gate) unless approval_gate.allowed

        approval_note = params[:approval_note].to_s.strip
        if approval_note.blank?
          return render_error(
            "approval_note_required",
            "要件定義の承認コメントを入力してください。",
            :unprocessable_entity,
            { requirement_id: requirement.id }
          )
        end

        approved_at = Time.current
        requirement.update!(
          status: "approved",
          approved_at: approved_at,
          approved_by: current_actor_id,
          approval_note: approval_note
        )
        AuditLog.record!(
          project: project_for(requirement.minute),
          action: "requirement.approved",
          target: requirement,
          actor_id: current_actor_id,
          metadata: {
            approved_at: approved_at.iso8601,
            approval_note_present: true
          }
        )
        render json: { data: requirement.api_json }
      end

      private

      def requirement
        @requirement ||= Requirement.find(params[:id])
      end

      def render_review_required(minutes)
        render_error(
          "review_required",
          "Minutes must be approved before generating requirements.",
          :conflict,
          { minutes_id: minutes.id, status: minutes.status }
        )
      end

      def render_requirement_approval_blocked(gate)
        render_error(
          gate.code,
          gate.message,
          :conflict,
          gate.details
        )
      end

      def project_for(minutes)
        minutes.meeting.project
      end

      def requirement_params
        params.permit(
          :background,
          :goal,
          user_stories: [],
          functional_requirements: [],
          non_functional_requirements: [],
          acceptance_criteria: [],
          out_of_scope: [],
          open_questions: [],
          risks: []
        )
      end
    end
  end
end
