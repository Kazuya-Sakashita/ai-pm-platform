module Api
  module V1
    class ProjectsController < ApplicationController
      def index
        projects = Project.order(created_at: :desc)
        render json: { data: projects.map(&:api_json), meta: pagination_meta(projects) }
      end

      def show
        render json: { data: project.api_json }
      end

      def create
        project = Project.create!(project_params)
        project.project_memberships.create!(actor_id: current_actor_id, role: "owner") if current_actor_id
        AuditLog.record!(project: project, action: "project.created", target: project, actor_id: current_actor_id || "system")
        render json: { data: project.api_json }, status: :created
      end

      def update
        project.update!(project_params)
        AuditLog.record!(project: project, action: "project.updated", target: project, actor_id: current_actor_id || "system")
        render json: { data: project.api_json }
      end

      def destroy
        project.update!(status: "archived")
        AuditLog.record!(project: project, action: "project.archived", target: project, actor_id: current_actor_id || "system")
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
