module Api
  module V1
    class WebhooksController < ApplicationController
      def github
        payload = request.raw_post
        GithubIntegration::WebhookSignatureVerifier.new.verify!(
          payload: payload,
          signature: request.headers["X-Hub-Signature-256"]
        )

        result = GithubIntegration::WebhookProcessor.new.call(
          event: request.headers["X-GitHub-Event"],
          delivery_id: request.headers["X-GitHub-Delivery"],
          payload: payload
        )

        render json: {
          data: {
            delivery_digest: result.delivery_digest,
            event: result.event,
            status: result.status
          }
        }, status: :accepted
      rescue GithubIntegration::WebhookError => e
        render_error(e.code, e.safe_detail, e.http_status)
      end
    end
  end
end
