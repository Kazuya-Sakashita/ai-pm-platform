require "digest"
require "securerandom"
require "time"

module GithubIntegration
  class ConnectionState
    TTL = 15.minutes

    def self.generate(project:, repository:, redirect_uri: nil)
      owner, name = parse_repository(repository)
      nonce = SecureRandom.hex(32)
      expires_at = TTL.from_now
      state = verifier.generate(
        {
          project_id: project.id,
          repository: repository,
          nonce: nonce,
          redirect_uri: redirect_uri,
          expires_at: expires_at.iso8601
        }.compact
      )
      project.github_connection_states.create!(
        repository_owner: owner,
        repository_name: name,
        nonce_digest: digest(nonce),
        state_digest: digest(state),
        redirect_uri: redirect_uri,
        expires_at: expires_at
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

    def self.consume!(state)
      payload = verify!(state)
      record = GithubConnectionState.find_by!(nonce_digest: digest(payload.fetch("nonce")))
      raise StateError, "GitHub connection state does not match the requested project." if record.project_id.to_s != payload.fetch("project_id").to_s
      raise StateError, "GitHub connection state does not match the requested repository." unless record.github_repository.casecmp?(payload.fetch("repository"))

      record.consume!
      payload
    rescue ActiveRecord::RecordNotFound, KeyError
      raise StateError, "GitHub connection state is invalid."
    end

    def self.verifier
      ActiveSupport::MessageVerifier.new(
        Rails.application.secret_key_base,
        serializer: JSON
      )
    end

    def self.digest(value)
      Digest::SHA256.hexdigest(value.to_s)
    end

    def self.parse_repository(repository)
      owner, name = repository.to_s.strip.split("/", 2)
      raise StateError, "GitHub repository is invalid." if owner.blank? || name.blank?

      [owner, name]
    end
  end
end
