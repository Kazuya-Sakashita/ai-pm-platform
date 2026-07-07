module Api
  module V1
    class OperationsController < ApplicationController
      def queue_health
        return unless require_actor!(action: "operations_queue_health")
        return render_project_required if params[:project_id].blank?
        return unless authorize_project_role!(project, action: "operations_queue_health", allowed_roles: project_admin_roles)

        render json: { data: Operations::QueueHealthQuery.new(project: project).call }
      end

      def retry_failed_job
        operate_failed_job!("retry")
      end

      def discard_failed_job
        operate_failed_job!("discard")
      end

      def request_failed_job_discard_approval
        return unless require_actor!(action: "operations_failed_job_discard_approval_request")
        return render_project_required if params[:project_id].blank?
        return unless authorize_project_role!(project, action: "operations_failed_job_discard_approval_request", allowed_roles: project_admin_roles)

        result = Operations::FailedJobDiscardApprovalService.new(
          project: project,
          actor_id: current_actor_id,
          failed_job_id: params[:failed_job_id],
          reason_template: failed_job_discard_approval_request_params[:reason_template],
          discard_safety_confirmed: failed_job_discard_approval_request_params[:discard_safety_confirmed]
        ).request

        render_service_result(result)
      end

      def approve_failed_job_discard_approval
        resolve_failed_job_discard_approval!("approve")
      end

      def reject_failed_job_discard_approval
        resolve_failed_job_discard_approval!("reject")
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
          reason_template: failed_job_operation_params[:reason_template],
          discard_safety_confirmed: failed_job_operation_params[:discard_safety_confirmed],
          discard_approval_id: failed_job_operation_params[:discard_approval_id]
        ).call

        render_service_result(result)
      end

      def failed_job_operation_params
        params.permit(:reason_template, :discard_safety_confirmed, :discard_approval_id)
      end

      def failed_job_discard_approval_request_params
        params.permit(:reason_template, :discard_safety_confirmed)
      end

      def failed_job_discard_approval_resolution_params
        params.permit(:approval_note, :rejection_reason)
      end

      def resolve_failed_job_discard_approval!(resolution)
        action_name = "operations_failed_job_discard_approval_#{resolution}"
        return unless require_actor!(action: action_name)
        return render_project_required if params[:project_id].blank?
        return unless authorize_project_role!(project, action: action_name, allowed_roles: failed_job_discard_approval_roles)

        service = Operations::FailedJobDiscardApprovalService.new(
          project: project,
          actor_id: current_actor_id,
          approval_id: params[:approval_id],
          approval_note: failed_job_discard_approval_resolution_params[:approval_note],
          rejection_reason: failed_job_discard_approval_resolution_params[:rejection_reason]
        )
        result = resolution == "approve" ? service.approve : service.reject

        render_service_result(result)
      end

      def render_service_result(result)
        if result.success?
          render json: { data: result.data }
        else
          render_error(result.code, result.message, result.http_status, result.details)
        end
      end

      def failed_job_discard_approval_roles
        %w[owner]
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
