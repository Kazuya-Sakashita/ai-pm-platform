module Api
  module V1
    class AuditLogsController < ApplicationController
      def index
        logs = project.audit_logs.order(created_at: :desc)
        render json: { data: logs.map(&:api_json), meta: pagination_meta(logs) }
      end

      private

      def project
        @project ||= Project.find(params[:project_id])
      end
    end
  end
end
