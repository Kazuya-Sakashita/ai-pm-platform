module Api
  module V1
    class ProjectsController < ApplicationController
      def index
        return unless require_actor!(action: "project_read")

        projects = Project
          .joins(:project_memberships)
          .where(project_memberships: { actor_id: current_actor_id, status: "active" })
          .distinct
          .order(created_at: :desc)
        render json: { data: projects.map(&:api_json), meta: pagination_meta(projects) }
      end

      def show
        return unless authorize_project!(project, :read)

        render json: { data: project.api_json }
      end

      def create
        return unless require_actor!(action: "project_create")

        project = Project.create!(project_params)
        project.project_memberships.create!(actor_id: current_actor_id, role: "owner")
        AuditLog.record!(project: project, action: "project.created", target: project, actor_id: current_actor_id)
        render json: { data: project.api_json }, status: :created
      end

      def update
        return unless authorize_project!(project, :update)

        project.update!(project_params)
        AuditLog.record!(project: project, action: "project.updated", target: project, actor_id: current_actor_id)
        render json: { data: project.api_json }
      end

      def destroy
        return unless authorize_project!(project, :archive)

        project.update!(status: "archived")
        AuditLog.record!(project: project, action: "project.archived", target: project, actor_id: current_actor_id)
        head :no_content
      end

      private

      def project
        @project ||= Project.find(params[:id] || params[:project_id])
      end

      def project_params
        params.permit(:name, :description, :github_repo, :status)
      end
    end
  end
end
