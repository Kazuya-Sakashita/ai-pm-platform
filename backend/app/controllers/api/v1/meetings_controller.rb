module Api
  module V1
    class MeetingsController < ApplicationController
      def index
        return unless require_actor!(action: "meeting_read")
        return unless authorize_project_role!(project, action: "meeting_read", allowed_roles: project_read_roles)

        meetings = project.meetings.order(created_at: :desc)
        render json: { data: meetings.map(&:api_json), meta: pagination_meta(meetings) }
      end

      def show
        return unless require_actor!(action: "meeting_read")
        return unless authorize_project_role!(meeting.project, action: "meeting_read", allowed_roles: project_read_roles)

        render json: { data: meeting.api_json }
      end

      def create
        return unless require_actor!(action: "meeting_create")
        return unless authorize_project_role!(project, action: "meeting_create", allowed_roles: project_write_roles)

        meeting = project.meetings.create!(meeting_params)
        AuditLog.record!(project: project, action: "meeting.created", target: meeting, actor_id: current_actor_id)
        render json: { data: meeting.api_json }, status: :created
      end

      private

      def meeting
        @meeting ||= Meeting.find(params[:id])
      end

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
