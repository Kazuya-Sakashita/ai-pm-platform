module Api
  module V1
    class JobsController < ApplicationController
      def show
        return unless require_actor!(action: "job_read")
        return unless authorize_project_role!(job.project, action: "job_read", allowed_roles: project_read_roles)

        render json: { data: job.api_json }
      end

      private

      def job
        @job ||= Job.find(params[:id])
      end
    end
  end
end
