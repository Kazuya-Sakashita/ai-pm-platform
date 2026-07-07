module Api
  module V1
    class WebhooksController < ApplicationController
      def github
        request_guard = GithubIntegration::WebhookRequestGuard.new
        request_guard.check_content_length!(request.headers["Content-Length"])
        request_guard.check_rate_limit!(remote_ip: request.remote_ip)

        payload = request.raw_post
        request_guard.check_payload_size!(payload)

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
        e.headers.each { |key, value| response.set_header(key, value) }
        render_error(e.code, e.safe_detail, e.http_status)
      end
    end
  end
end
