module Api
  module V1
    class ReviewsController < ApplicationController
      def index
        return unless require_actor!(action: "review_read")

        reviews = scoped_reviews_for_read
        return unless reviews

        render json: { data: reviews.map(&:api_json), meta: pagination_meta(reviews) }
      end

      def create
        return unless require_actor!(action: "review_create")
        target_project = project_for_review_target(params[:target_type], params[:target_id])
        return unless target_project
        return unless authorize_project_role!(target_project, action: "review_create", allowed_roles: project_review_roles)

        review = transition_service(target_project).create!(review_params)
        render json: { data: review.api_json }, status: :created
      end

      def events
        return unless authorize_review!("review_events_read", project_read_roles)

        events = review.review_state_events.order(occurred_at: :desc, created_at: :desc)
        render json: { data: events.map(&:api_json), meta: pagination_meta(events) }
      end

      def resolve_action
        target_project = authorize_review!("review_resolve", project_review_roles)
        return unless target_project

        target_review = review
        updated_review = transition_service(target_project).resolve!(
          review: target_review,
          resolution_note: params.require(:resolution_note)
        )
        render json: { data: updated_review.api_json }
      end

      def accept_risk
        target_project = authorize_review!("review_accept_risk", project_review_roles)
        return unless target_project

        target_review = review
        updated_review = transition_service(target_project).accept_risk!(
          review: target_review,
          reason: params.require(:reason),
          residual_risk: params.require(:residual_risk),
          expires_at: params.require(:expires_at),
          linked_issue_number: params.require(:linked_issue_number)
        )
        render json: { data: updated_review.api_json }
      end

      def reopen
        target_project = authorize_review!("review_reopen", project_review_roles)
        return unless target_project

        target_review = review
        updated_review = transition_service(target_project).reopen!(
          review: target_review,
          reason_summary: params.require(:reason_summary),
          issue_numbers: params[:issue_numbers]
        )
        render json: { data: updated_review.api_json }
      end

      private

      def review
        @review ||= Review.find(params[:id])
      end

      def authorize_review!(action, allowed_roles)
        return false unless require_actor!(action: action)

        target_project = project_for_review_target(review.target_type, review.target_id)
        return false unless target_project

        return false unless authorize_project_role!(target_project, action: action, allowed_roles: allowed_roles)

        target_project
      end

      def transition_service(project)
        ReviewTransitionService.new(project: project, actor_id: current_actor_id, sensitive_handling: :reject)
      end

      def scoped_reviews_for_read
        if params[:target_type].present? || params[:target_id].present?
          target_project = project_for_review_target(params[:target_type], params[:target_id])
          return nil unless target_project
          return nil unless authorize_project_role!(target_project, action: "review_read", allowed_roles: project_read_roles)

          return Review.where(target_type: params[:target_type], target_id: params[:target_id]).order(created_at: :desc)
        end

        return nil if params[:project_id].blank? && render_project_required

        project = Project.find(params[:project_id])
        return nil unless authorize_project_role!(project, action: "review_read", allowed_roles: project_read_roles)

        Review.order(created_at: :desc).select { |candidate| review_belongs_to_project?(candidate, project) }
      end

      def review_belongs_to_project?(candidate, project)
        project_for_review_target(candidate.target_type, candidate.target_id, render_errors: false)&.id == project.id
      rescue ActiveRecord::RecordNotFound
        false
      end

      def project_for_review_target(target_type, target_id, render_errors: true)
        if target_type.blank? || target_id.blank?
          render_review_target_required if render_errors
          return nil
        end

        case target_type
        when "meeting"
          Meeting.find(target_id).project
        when "conversation_import"
          ConversationImport.find(target_id).project
        when "conversation_summary_draft"
          ConversationSummaryDraft.find(target_id).conversation_import.project
        when "minutes"
          Minute.find(target_id).meeting.project
        when "requirement"
          Requirement.find(target_id).minute.meeting.project
        when "issue_draft"
          IssueDraft.find(target_id).requirement.minute.meeting.project
        when "openapi_draft"
          OpenApiDraft.find(target_id).requirement.minute.meeting.project
        else
          render_review_target_required if render_errors
          nil
        end
      end

      def render_project_required
        render_error(
          "validation_error",
          "project_id is required when no review target is specified.",
          :unprocessable_entity,
          { parameter: "project_id" }
        )
        true
      end

      def render_review_target_required
        render_error(
          "validation_error",
          "Review target must belong to a project-scoped workflow resource.",
          :unprocessable_entity,
          { supported_target_types: %w[meeting conversation_import conversation_summary_draft minutes requirement issue_draft openapi_draft] }
        )
      end

      def review_params
        params.permit(
          :target_type,
          :target_id,
          :reviewer_role,
          framework: [],
          positives: [],
          improvements: [],
          priority: [],
          next_actions: [],
          issue_numbers: []
        )
      end

      rescue_from ReviewTransitionService::SensitiveContentError do |error|
        render_error(
          "sensitive_content_detected",
          "レビュー本文に機密情報または個人情報の可能性がある内容が含まれています。伏字化してから保存してください。",
          :unprocessable_entity,
          error.details
        )
      end

      rescue_from ReviewTransitionService::InvalidTransitionError do |error|
        render_error(error.code, "レビュー状態の変更条件を満たしていません。", :conflict, error.details)
      end
    end
  end
end
