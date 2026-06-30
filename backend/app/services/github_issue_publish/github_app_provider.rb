require "base64"
require "digest"
require "json"
require "openssl"

module GithubIssuePublish
  class GithubAppProvider
    API_VERSION = "2022-11-28".freeze
    TOKEN_PERMISSION_REQUEST = { permissions: { issues: "write" } }.freeze

    def self.private_key_from_env
      if ENV["GITHUB_APP_PRIVATE_KEY_BASE64"].present?
        Base64.decode64(ENV.fetch("GITHUB_APP_PRIVATE_KEY_BASE64"))
      else
        ENV["GITHUB_APP_PRIVATE_KEY"]&.gsub("\\n", "\n")
      end
    end

    def initialize(
      app_id: ENV["GITHUB_APP_ID"],
      private_key_pem: self.class.private_key_from_env,
      api_base_url: ENV.fetch("GITHUB_API_BASE_URL", "https://api.github.com"),
      http_client: nil
    )
      @app_id = app_id
      @private_key_pem = private_key_pem
      @http_client = http_client || HttpClient.new(api_base_url: api_base_url)
    end

    def publish(issue_draft:, project:, idempotency_key:)
      ensure_configured!

      repository = parse_repository(project.github_repo)
      account = connected_account_for(project, repository)
      ensure_issue_permission!(account)

      token = create_installation_token(account)
      response = http_client.post_json(
        path: "/repos/#{repository.fetch(:owner)}/#{repository.fetch(:name)}/issues",
        headers: github_headers(token),
        body: issue_body(issue_draft, idempotency_key)
      )

      unless response.success?
        mark_account_error(account, safe_github_error(response, "GitHub Issue creation failed."))
        raise provider_error(
          code: "github_issue_create_failed",
          message: "GitHub Issue creation failed with status #{response.status}.",
          safe_detail: safe_github_error(response, "GitHub Issue creation failed."),
          http_status: response.status == 403 ? :failed_dependency : :bad_gateway
        )
      end

      payload = parse_response_json(response)
      account.update!(status: "connected", last_error_safe: nil, last_sync_at: Time.current)

      {
        github_issue_number: payload.fetch("number"),
        github_issue_url: payload.fetch("html_url"),
        github_repository: account.github_repository,
        github_issue_api_id: payload["id"],
        github_issue_node_id: payload["node_id"]
      }
    end

    private

    attr_reader :app_id, :private_key_pem, :http_client

    def ensure_configured!
      return if app_id.present? && private_key_pem.present?

      raise provider_error(
        code: "github_app_not_configured",
        message: "GitHub App id or private key is missing.",
        safe_detail: "GitHub App is not configured.",
        http_status: :failed_dependency
      )
    end

    def parse_repository(repository)
      owner, name = repository.to_s.strip.split("/", 2)
      return { owner: owner, name: name } if owner.present? && name.present?

      raise provider_error(
        code: "github_repository_not_configured",
        message: "Project GitHub repository is missing or invalid.",
        safe_detail: "GitHub repository is not configured for this project.",
        http_status: :failed_dependency
      )
    end

    def connected_account_for(project, repository)
      account = project.integration_accounts
                       .where(provider: "github")
                       .where("LOWER(repository_owner) = ? AND LOWER(repository_name) = ?",
                              repository.fetch(:owner).downcase,
                              repository.fetch(:name).downcase)
                       .first

      unless account&.connected?
        raise provider_error(
          code: "github_integration_not_connected",
          message: "GitHub App installation is not connected for project #{project.id}.",
          safe_detail: "GitHub integration is not connected.",
          http_status: :failed_dependency
        )
      end

      account
    end

    def ensure_issue_permission!(account)
      return if account.issues_write_granted?

      mark_account_error(account, "GitHub App requires Issues write permission.")
      raise provider_error(
        code: "github_permission_missing",
        message: "GitHub App installation does not grant Issues write permission.",
        safe_detail: "GitHub App requires Issues write permission.",
        http_status: :failed_dependency
      )
    end

    def create_installation_token(account)
      response = http_client.post_json(
        path: "/app/installations/#{account.github_installation_id}/access_tokens",
        headers: github_headers(app_jwt),
        body: TOKEN_PERMISSION_REQUEST
      )

      unless response.success?
        mark_account_error(account, safe_github_error(response, "GitHub installation token could not be created."))
        raise provider_error(
          code: "github_installation_token_failed",
          message: "GitHub installation token request failed with status #{response.status}.",
          safe_detail: safe_github_error(response, "GitHub installation token could not be created."),
          http_status: :failed_dependency
        )
      end

      token = parse_response_json(response)["token"]
      return token if token.present?

      mark_account_error(account, "GitHub installation token response was invalid.")
      raise provider_error(
        code: "github_installation_token_invalid",
        message: "GitHub installation token response did not include a token.",
        safe_detail: "GitHub installation token response was invalid.",
        http_status: :bad_gateway
      )
    end

    def app_jwt
      issued_at = Time.now.to_i - 60
      expires_at = issued_at + 540
      signing_input = [
        base64_json({ alg: "RS256", typ: "JWT" }),
        base64_json({ iat: issued_at, exp: expires_at, iss: app_id.to_s })
      ].join(".")

      signature = OpenSSL::PKey::RSA.new(private_key_pem)
                                    .sign(OpenSSL::Digest::SHA256.new, signing_input)
      "#{signing_input}.#{base64_url(signature)}"
    rescue OpenSSL::PKey::RSAError => e
      raise provider_error(
        code: "github_app_private_key_invalid",
        message: "GitHub App private key is invalid: #{e.class}",
        safe_detail: "GitHub App private key is invalid.",
        http_status: :failed_dependency
      )
    end

    def github_headers(token)
      {
        "Accept" => "application/vnd.github+json",
        "Authorization" => "Bearer #{token}",
        "X-GitHub-Api-Version" => API_VERSION
      }
    end

    def issue_body(issue_draft, idempotency_key)
      {
        title: issue_draft.title,
        body: [
          issue_draft.body,
          acceptance_criteria_block(issue_draft),
          "<!-- ai_pm_platform:issue_draft_id=#{issue_draft.id};idempotency_digest=#{idempotency_digest(idempotency_key)} -->"
        ].compact.join("\n\n"),
        labels: issue_draft.labels
      }
    end

    def acceptance_criteria_block(issue_draft)
      criteria = Array(issue_draft.acceptance_criteria).reject(&:blank?)
      return if criteria.empty? || issue_draft.body.include?("## Acceptance Criteria")

      "## Acceptance Criteria\n#{criteria.map { |item| "- #{item}" }.join("\n")}"
    end

    def mark_account_error(account, safe_detail)
      account.update!(status: "error", last_error_safe: safe_detail, last_sync_at: Time.current)
    end

    def safe_github_error(response, fallback)
      payload = parse_response_json(response)
      message = payload["message"].presence || fallback
      message.truncate(240)
    rescue ProviderError
      fallback
    end

    def parse_response_json(response)
      response.json
    rescue JSON::ParserError
      raise provider_error(
        code: "github_api_invalid_json",
        message: "GitHub API response JSON could not be parsed.",
        safe_detail: "GitHub API returned an invalid response.",
        http_status: :bad_gateway
      )
    end

    def base64_json(value)
      base64_url(JSON.generate(value))
    end

    def base64_url(value)
      Base64.urlsafe_encode64(value, padding: false)
    end

    def idempotency_digest(idempotency_key)
      Digest::SHA256.hexdigest(idempotency_key.to_s)[0, 16]
    end

    def provider_error(code:, message:, safe_detail:, http_status:)
      ProviderError.new(code: code, message: message, safe_detail: safe_detail, http_status: http_status)
    end
  end
end
