module Api
  module V1
    class MinutesController < ApplicationController
      def generate
        return unless require_actor!(action: "minutes_generate")

        meeting = Meeting.find(params[:id])
        return unless authorize_project_role!(meeting.project, action: "minutes_generate", allowed_roles: project_write_roles)

        job = meeting.project.jobs.create!(
          job_type: "ai_generation",
          status: "running",
          target_type: "minutes",
          progress: 10
        )

        minute = MinutesGenerationService.new(meeting).call
        job.update!(
          status: "succeeded",
          target_id: minute.id,
          progress: 100
        )

        AuditLog.record!(
          project: meeting.project,
          action: "minutes.generated",
          target: minute,
          actor_id: current_actor_id,
          metadata: { meeting_id: meeting.id, job_id: job.id }
        )

        render json: { data: { job_id: job.id, status: job.status } }, status: :accepted
      rescue MinutesGeneration::ProviderError => e
        job&.update!(
          status: "failed",
          progress: 100,
          error_code: e.code,
          error_message: e.message,
          safe_error_detail: e.safe_detail
        )
        AuditLog.record!(
          project: meeting.project,
          action: "minutes.generation_failed",
          target: job,
          actor_id: current_actor_id,
          metadata: { meeting_id: meeting.id, provider_error_code: e.code, request_id: e.request_id }.compact
        ) if job

        render_error(
          e.code,
          e.safe_detail,
          e.http_status,
          { job_id: job&.id, request_id: e.request_id }.compact
        )
      end

      def show
        return unless require_actor!(action: "minutes_read")
        return unless authorize_project_role!(minute.meeting.project, action: "minutes_read", allowed_roles: project_read_roles)

        render json: { data: minute.api_json }
      end

      def update
        return unless require_actor!(action: "minutes_update")
        return unless authorize_project_role!(minute.meeting.project, action: "minutes_update", allowed_roles: project_write_roles)

        minute.update!(minute_params)
        AuditLog.record!(
          project: minute.meeting.project,
          action: "minutes.updated",
          target: minute,
          actor_id: current_actor_id
        )
        render json: { data: minute.api_json }
      end

      def approve
        return unless require_actor!(action: "minutes_approve")
        return unless authorize_project_role!(minute.meeting.project, action: "minutes_approve", allowed_roles: project_review_roles)

        minute.update!(status: "approved")
        AuditLog.record!(
          project: minute.meeting.project,
          action: "minutes.approved",
          target: minute,
          actor_id: current_actor_id
        )
        render json: { data: minute.api_json }
      end

      private

      def minute
        @minute ||= Minute.find(params[:id])
      end

      def minute_params
        params.permit(
          :summary,
          :status,
          decisions: [:text, :owner],
          open_questions: [],
          action_items: [:text, :owner, :due_date, :status]
        )
      end
    end
  end
end
