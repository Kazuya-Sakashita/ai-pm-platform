module GithubIntegration
  class ConnectionStateCleanupJob < ApplicationJob
    queue_as :default

    def perform(retention_seconds = GithubConnectionState::CLEANUP_RETENTION.to_i)
      deleted_count = GithubConnectionState.cleanup_expired!(retention: retention_seconds.to_i.seconds)

      Rails.logger.info(
        event: "github_connection_state_cleanup",
        deleted_count: deleted_count,
        retention_seconds: retention_seconds.to_i
      )
    end
  end
end
