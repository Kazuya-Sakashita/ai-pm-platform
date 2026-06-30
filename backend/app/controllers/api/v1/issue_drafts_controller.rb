module Api
  module V1
    class IssueDraftsController < ApplicationController
      def generate
        requirement = Requirement.find(params[:id])
        return render_review_required(requirement) unless requirement.status == "approved"

        job = project_for(requirement).jobs.create!(
          job_type: "ai_generation",
          status: "running",
          target_type: "issue_draft",
          progress: 10
        )

        issue_draft = IssueDraftGenerationService.new(requirement).call
        job.update!(
          status: "succeeded",
          target_id: issue_draft.id,
          progress: 100
        )

        AuditLog.record!(
          project: project_for(requirement),
          action: "issue_draft.generated",
          target: issue_draft,
          metadata: { requirement_id: requirement.id, job_id: job.id }
        )

        render json: { data: { job_id: job.id, status: job.status } }, status: :accepted
      rescue IssueDraftGeneration::ProviderError => e
        job&.update!(
          status: "failed",
          progress: 100,
          error_code: e.code,
          error_message: e.message,
          safe_error_detail: e.safe_detail
        )
        AuditLog.record!(
          project: project_for(requirement),
          action: "issue_draft.generation_failed",
          target: job,
          metadata: { requirement_id: requirement.id, provider_error_code: e.code }
        ) if job && requirement

        render_error(e.code, e.safe_detail, e.http_status, { job_id: job&.id }.compact)
      end

      def show
        render json: { data: issue_draft.api_json }
      end

      def update
        issue_draft.update!(issue_draft_params)
        AuditLog.record!(
          project: project_for(issue_draft.requirement),
          action: "issue_draft.updated",
          target: issue_draft
        )
        render json: { data: issue_draft.api_json }
      end

      private

      def issue_draft
        @issue_draft ||= IssueDraft.find(params[:id])
      end

      def render_review_required(requirement)
        render_error(
          "review_required",
          "Requirement must be approved before generating issue drafts.",
          :conflict,
          { requirement_id: requirement.id, status: requirement.status }
        )
      end

      def project_for(requirement)
        requirement.minute.meeting.project
      end

      def issue_draft_params
        params.permit(
          :title,
          :body,
          :status,
          acceptance_criteria: [],
          labels: []
        )
      end
    end
  end
end
