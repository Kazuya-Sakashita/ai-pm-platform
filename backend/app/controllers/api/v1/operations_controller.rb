module Api
  module V1
    class OperationsController < ApplicationController
      def queue_health
        return unless require_actor!(action: "operations_queue_health")
        return render_project_required if params[:project_id].blank?
        return unless authorize_project_role!(project, action: "operations_queue_health", allowed_roles: project_admin_roles)

        render json: { data: Operations::QueueHealthQuery.new.call }
      end

      private

      def project
        @project ||= Project.find(params[:project_id])
      end

      def render_project_required
        render_error(
          "validation_error",
          "project_id is required.",
          :unprocessable_entity,
          { parameter: "project_id" }
        )
      end
    end
  end
end
