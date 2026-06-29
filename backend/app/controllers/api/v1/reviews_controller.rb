module Api
  module V1
    class ReviewsController < ApplicationController
      def index
        reviews = Review.order(created_at: :desc)
        reviews = reviews.where(target_type: params[:target_type]) if params[:target_type].present?
        reviews = reviews.where(target_id: params[:target_id]) if params[:target_id].present?

        render json: { data: reviews.map(&:api_json), meta: pagination_meta(reviews) }
      end

      def create
        review = Review.create!(review_params.merge(status: "open"))
        render json: { data: review.api_json }, status: :created
      end

      def resolve_action
        review.update!(status: "resolved", resolution_note: params.require(:resolution_note))
        render json: { data: review.api_json }
      end

      def accept_risk
        review.update!(
          status: "accepted_risk",
          accepted_risk: {
            reason: params.require(:reason),
            residual_risk: params.require(:residual_risk),
            approved_by: params[:approved_by],
            expires_at: params.require(:expires_at),
            linked_issue_number: params.require(:linked_issue_number),
            accepted_at: Time.current.iso8601
          }
        )
        render json: { data: review.api_json }
      end

      private

      def review
        @review ||= Review.find(params[:id])
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
    end
  end
end
