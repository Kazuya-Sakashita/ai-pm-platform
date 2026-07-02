require "base64"
require "json"
require "openssl"
require "uri"

module GithubIssuePublish
  class MarkerSearchClient
    API_VERSION = GithubAppProvider::API_VERSION
    SEARCH_RESULT_LIMIT = 10
    TOKEN_PERMISSION_REQUEST = GithubAppProvider::TOKEN_PERMISSION_REQUEST
    SearchResult = Struct.new(:matches, :total_count, :incomplete_results, :result_limit, keyword_init: true) do
      def search_has_more_results
        total_count.to_i > matches.count
      end
    end

    def initialize(
      app_id: ENV["GITHUB_APP_ID"],
      private_key_pem: GithubAppProvider.private_key_from_env,
      api_base_url: ENV.fetch("GITHUB_API_BASE_URL", "https://api.github.com"),
      http_client: nil
    )
      @app_id = app_id
      @private_key_pem = private_key_pem
      @http_client = http_client || HttpClient.new(api_base_url: api_base_url)
    end

    def search(issue_draft:, project:, idempotency_digest:)
      ensure_configured!

      repository = parse_repository(project.github_repo)
      account = connected_account_for(project, repository)
      ensure_issue_permission!(account)

      token = create_installation_token(account)
      response = http_client.get_json(
        path: search_path(repository, issue_draft, idempotency_digest),
        headers: github_headers(token)
      )
      unless response.success?
        raise provider_error(
          code: "github_issue_marker_search_failed",
          message: "GitHub Issue marker search failed with status #{response.status}.",
          safe_detail: safe_github_error(response, "GitHub Issue marker search failed."),
          http_status: :bad_gateway
        )
      end

      payload = parse_response_json(response)
      matches = payload.fetch("items", []).map do |item|
        {
          github_issue_number: item.fetch("number"),
          github_issue_url: item.fetch("html_url"),
          github_repository: account.github_repository,
          github_issue_title: item["title"],
          github_issue_state: item["state"],
          github_issue_updated_at: item["updated_at"],
          github_issue_score: item["score"],
          github_issue_api_id: item["id"],
          github_issue_node_id: item["node_id"]
        }.compact
      end
      SearchResult.new(
        matches: matches,
        total_count: payload["total_count"].to_i,
        incomplete_results: payload["incomplete_results"] == true,
        result_limit: SEARCH_RESULT_LIMIT
      )
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
      return account if account&.connected?

      raise provider_error(
        code: "github_integration_not_connected",
        message: "GitHub App installation is not connected for project #{project.id}.",
        safe_detail: "GitHub integration is not connected.",
        http_status: :failed_dependency
      )
    end

    def ensure_issue_permission!(account)
      return if account.issues_write_granted?

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
        raise provider_error(
          code: "github_installation_token_failed",
          message: "GitHub installation token request failed with status #{response.status}.",
          safe_detail: safe_github_error(response, "GitHub installation token could not be created."),
          http_status: :failed_dependency
        )
      end

      token = parse_response_json(response)["token"]
      return token if token.present?

      raise provider_error(
        code: "github_installation_token_invalid",
        message: "GitHub installation token response did not include a token.",
        safe_detail: "GitHub installation token response was invalid.",
        http_status: :bad_gateway
      )
    end

    def search_path(repository, issue_draft, idempotency_digest)
      marker = "ai_pm_platform:issue_draft_id=#{issue_draft.id};idempotency_digest=#{idempotency_digest.to_s[0, 16]}"
      query = %(repo:#{repository.fetch(:owner)}/#{repository.fetch(:name)} is:issue "#{marker}")
      "/search/issues?#{URI.encode_www_form(q: query, per_page: SEARCH_RESULT_LIMIT)}"
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

    def provider_error(code:, message:, safe_detail:, http_status:)
      ProviderError.new(code: code, message: message, safe_detail: safe_detail, http_status: http_status)
    end
  end
end
