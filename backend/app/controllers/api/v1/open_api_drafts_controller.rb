require "digest"

module Api
  module V1
    class OpenApiDraftsController < ApplicationController
      def generate
        requirement = Requirement.find(params[:id])
        return render_review_required(requirement) unless requirement.status == "approved"

        job = project_for(requirement).jobs.create!(
          job_type: "ai_generation",
          status: "running",
          target_type: "openapi_draft",
          progress: 10
        )

        open_api_draft = OpenApiDraftGenerationService.new(requirement).call
        job.update!(
          status: "succeeded",
          target_id: open_api_draft.id,
          progress: 100
        )

        AuditLog.record!(
          project: project_for(requirement),
          action: "openapi_draft.generated",
          target: open_api_draft,
          metadata: { requirement_id: requirement.id, job_id: job.id }
        )

        render json: { data: { job_id: job.id, status: job.status } }, status: :accepted
      rescue OpenApiDraftGeneration::ProviderError => e
        job&.update!(
          status: "failed",
          progress: 100,
          error_code: e.code,
          error_message: e.message,
          safe_error_detail: e.safe_detail
        )
        AuditLog.record!(
          project: project_for(requirement),
          action: "openapi_draft.generation_failed",
          target: job,
          metadata: { requirement_id: requirement.id, provider_error_code: e.code }
        ) if job && requirement

        render_error(e.code, e.safe_detail, e.http_status, { job_id: job&.id }.compact)
      end

      def show
        render json: { data: open_api_draft.api_json }
      end

      def update
        open_api_draft.update!(open_api_draft_params)
        AuditLog.record!(
          project: project_for(open_api_draft.requirement),
          action: "openapi_draft.updated",
          target: open_api_draft
        )
        render json: { data: open_api_draft.api_json }
      end

      def validate
        draft = open_api_draft
        project = project_for(draft.requirement)
        previous_status = draft.status
        content_hash = Digest::SHA256.hexdigest(draft.content.to_s)
        job = project.jobs.create!(
          job_type: "validation",
          status: "running",
          target_type: "openapi_draft",
          target_id: draft.id,
          progress: 10
        )

        AuditLog.record!(
          project: project,
          action: "openapi_draft.validation_started",
          target: draft,
          metadata: {
            job_id: job.id,
            validator: "OpenApiDraftValidationService",
            content_hash: content_hash
          }
        )

        result = OpenApiDraftValidationService.new(draft).call
        draft.reload
        job.update!(status: "succeeded", progress: 100)

        AuditLog.record!(
          project: project,
          action: "openapi_draft.validation_succeeded",
          target: draft,
          metadata: {
            job_id: job.id,
            validator: "OpenApiDraftValidationService",
            content_hash: content_hash,
            valid: result.fetch(:valid),
            error_count: result.fetch(:errors).size,
            warning_count: result.fetch(:warnings).size,
            status_from: previous_status,
            status_to: draft.status
          }
        )

        render json: { data: result }
      rescue StandardError => e
        job&.update!(
          status: "failed",
          progress: 100,
          error_code: "openapi_validation_failed",
          error_message: e.message,
          safe_error_detail: "OpenAPI validation could not be completed."
        )
        AuditLog.record!(
          project: project,
          action: "openapi_draft.validation_failed",
          target: draft || job,
          metadata: {
            job_id: job&.id,
            validator: "OpenApiDraftValidationService",
            content_hash: content_hash,
            error_class: e.class.name
          }.compact
        ) if project && (draft || job)

        raise
      end

      private

      def open_api_draft
        @open_api_draft ||= OpenApiDraft.find(params[:openapi_draft_id] || params[:id])
      end

      def render_review_required(requirement)
        render_error(
          "review_required",
          "Requirement must be approved before generating an OpenAPI draft.",
          :conflict,
          { requirement_id: requirement.id, status: requirement.status }
        )
      end

      def project_for(requirement)
        requirement.minute.meeting.project
      end

      def open_api_draft_params
        params.permit(:title, :content, :status)
      end
    end
  end
end
