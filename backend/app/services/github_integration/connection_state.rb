require "time"

module GithubIntegration
  class StateError < StandardError; end

  class ConnectionState
    TTL = 15.minutes

    def self.generate(project:, repository:, redirect_uri: nil)
      expires_at = TTL.from_now
      state = verifier.generate(
        {
          project_id: project.id,
          repository: repository,
          redirect_uri: redirect_uri,
          expires_at: expires_at.iso8601
        }.compact
      )

      { state: state, expires_at: expires_at }
    end

    def self.verify!(state)
      payload = verifier.verify(state)
      expires_at = Time.iso8601(payload.fetch("expires_at"))
      raise StateError, "GitHub connection state expired." if expires_at.past?

      payload
    rescue ActiveSupport::MessageVerifier::InvalidSignature, KeyError, ArgumentError
      raise StateError, "GitHub connection state is invalid."
    end

    def self.verifier
      ActiveSupport::MessageVerifier.new(
        Rails.application.secret_key_base,
        serializer: JSON
      )
    end
  end
end
