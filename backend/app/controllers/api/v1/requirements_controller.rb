module Api
  module V1
    class RequirementsController < ApplicationController
      def generate
        minutes = Minute.find(params[:id])
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
          metadata: { minutes_id: minutes.id, provider_error_code: e.code }
        ) if job && minutes

        render_error(e.code, e.safe_detail, e.http_status, { job_id: job&.id }.compact)
      end

      def show
        render json: { data: requirement.api_json }
      end

      def update
        requirement.update!(requirement_params)
        AuditLog.record!(
          project: project_for(requirement.minute),
          action: "requirement.updated",
          target: requirement
        )
        render json: { data: requirement.api_json }
      end

      def approve
        return render_requirement_review_required(requirement) if requirement.open_questions.any?

        requirement.update!(status: "approved")
        AuditLog.record!(
          project: project_for(requirement.minute),
          action: "requirement.approved",
          target: requirement
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

      def render_requirement_review_required(requirement)
        render_error(
          "review_required",
          "Requirement open questions must be resolved before approval.",
          :conflict,
          { requirement_id: requirement.id, open_questions: requirement.open_questions }
        )
      end

      def project_for(minutes)
        minutes.meeting.project
      end

      def requirement_params
        params.permit(
          :background,
          :goal,
          :status,
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
