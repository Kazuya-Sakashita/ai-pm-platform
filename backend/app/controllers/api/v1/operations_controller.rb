module Api
  module V1
    class OperationsController < ApplicationController
      def queue_health
        return unless require_actor!(action: "operations_queue_health")
        return render_project_required if params[:project_id].blank?
        return unless authorize_project_role!(project, action: "operations_queue_health", allowed_roles: project_admin_roles)

        render json: { data: Operations::QueueHealthQuery.new.call }
      end

      def retry_failed_job
        operate_failed_job!("retry")
      end

      def discard_failed_job
        operate_failed_job!("discard")
      end

      private

      def project
        @project ||= Project.find(params[:project_id])
      end

      def operate_failed_job!(action)
        return unless require_actor!(action: "operations_failed_job_#{action}")
        return render_project_required if params[:project_id].blank?
        return unless authorize_project_role!(project, action: "operations_failed_job_#{action}", allowed_roles: project_admin_roles)

        result = Operations::FailedJobOperationService.new(
          project: project,
          actor_id: current_actor_id,
          failed_job_id: params[:failed_job_id],
          action: action,
          reason_template: failed_job_operation_params[:reason_template]
        ).call

        if result.success?
          render json: { data: result.data }
        else
          render_error(result.code, result.message, result.http_status, result.details)
        end
      end

      def failed_job_operation_params
        params.permit(:reason_template)
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
