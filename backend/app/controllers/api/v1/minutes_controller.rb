module Api
  module V1
    class MinutesController < ApplicationController
      def generate
        meeting = Meeting.find(params[:id])
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
        render json: { data: minute.api_json }
      end

      def update
        minute.update!(minute_params)
        AuditLog.record!(
          project: minute.meeting.project,
          action: "minutes.updated",
          target: minute
        )
        render json: { data: minute.api_json }
      end

      def approve
        minute.update!(status: "approved")
        AuditLog.record!(
          project: minute.meeting.project,
          action: "minutes.approved",
          target: minute
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
