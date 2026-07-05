module Api
  module V1
    class ProjectMembershipsController < ApplicationController
      def index
        return unless authorize_project_membership_management!(:read)

        memberships = memberships_scope.order(:created_at)
        render json: { data: memberships.map(&:api_json), meta: pagination_meta(memberships) }
      end

      def create
        return unless authorize_project_membership_management!(:create)

        result = ProjectMemberships::ManagementService.new(
          project: project,
          actor_id: current_actor_id
        ).create!(actor_id: membership_params[:actor_id], role: membership_params[:role])

        render json: { data: result.api_json }, status: :created
      rescue ProjectMemberships::ManagementService::Error => e
        render_error(e.code, e.message, e.http_status, e.details)
      end

      def update
        return unless authorize_project_membership_management!(:update, membership: membership)

        result = ProjectMemberships::ManagementService.new(
          project: project,
          actor_id: current_actor_id
        ).update_role!(membership: membership, role: membership_params[:role])

        render json: { data: result.api_json }
      rescue ProjectMemberships::ManagementService::Error => e
        render_error(e.code, e.message, e.http_status, e.details)
      end

      def destroy
        return unless authorize_project_membership_management!(:revoke, membership: membership)

        ProjectMemberships::ManagementService.new(
          project: project,
          actor_id: current_actor_id
        ).revoke!(membership: membership)

        head :no_content
      rescue ProjectMemberships::ManagementService::Error => e
        render_error(e.code, e.message, e.http_status, e.details)
      end

      private

      def project
        @project ||= Project.find(params[:project_id])
      end

      def membership
        @membership ||= project.project_memberships.find(params[:membership_id])
      end

      def memberships_scope
        case params.fetch(:status, "active")
        when "active"
          project.project_memberships.active
        when "revoked"
          project.project_memberships.where(status: "revoked")
        when "all"
          project.project_memberships
        else
          project.project_memberships.none
        end
      end

      def membership_params
        params.permit(:actor_id, :role)
      end
    end
  end
end
