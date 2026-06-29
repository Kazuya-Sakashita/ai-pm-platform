module Api
  module V1
    class MeetingsController < ApplicationController
      def index
        meetings = project.meetings.order(created_at: :desc)
        render json: { data: meetings.map(&:api_json), meta: pagination_meta(meetings) }
      end

      def show
        render json: { data: Meeting.find(params[:id]).api_json }
      end

      def create
        meeting = project.meetings.create!(meeting_params)
        AuditLog.record!(project: project, action: "meeting.created", target: meeting)
        render json: { data: meeting.api_json }, status: :created
      end

      private

      def project
        @project ||= Project.find(params[:project_id])
      end

      def meeting_params
        params.permit(
          :title,
          :source_type,
          :meeting_date,
          :raw_text,
          participants: [],
          tags: []
        )
      end
    end
  end
end
