require "base64"
require "json"
require "openssl"

module GithubIntegration
  class VerifierError < StandardError
    attr_reader :code, :safe_detail, :http_status

    def initialize(code:, message:, safe_detail:, http_status: :failed_dependency)
      super(message)
      @code = code
      @safe_detail = safe_detail
      @http_status = http_status
    end
  end

  class InstallationVerifier
    API_VERSION = "2022-11-28".freeze
    Result = Struct.new(
      :installation_id,
      :account_login,
      :account_type,
      :granted_permissions,
      keyword_init: true
    )

    def self.verify(**kwargs)
      new.verify(**kwargs)
    end

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
      @http_client = http_client || GithubIssuePublish::HttpClient.new(api_base_url: api_base_url)
    end

    def verify(installation_id:, repository:)
      ensure_configured!

      installation = fetch_installation(installation_id)
      permissions = installation.fetch("permissions", {})
      ensure_issue_permission!(permissions)

      token = create_installation_token(installation_id)
      ensure_repository_access!(token, repository)

      account = installation.fetch("account", {})
      Result.new(
        installation_id: installation_id.to_s,
        account_login: account["login"],
        account_type: account["type"] || installation["target_type"],
        granted_permissions: permissions
      )
    rescue GithubIssuePublish::ProviderError => e
      raise verifier_error(
        code: e.code,
        message: e.message,
        safe_detail: e.safe_detail,
        http_status: e.http_status
      )
    end

    private

    attr_reader :app_id, :private_key_pem, :http_client

    def ensure_configured!
      return if app_id.present? && private_key_pem.present?

      raise verifier_error(
        code: "github_app_not_configured",
        message: "GitHub App id or private key is missing.",
        safe_detail: "GitHub App is not configured."
      )
    end

    def fetch_installation(installation_id)
      response = http_client.get_json(
        path: "/app/installations/#{installation_id}",
        headers: github_headers(app_jwt)
      )
      return parse_response_json(response) if response.success?

      raise verifier_error(
        code: "github_installation_verification_failed",
        message: "GitHub installation verification failed with status #{response.status}.",
        safe_detail: safe_github_error(response, "GitHub installation could not be verified.")
      )
    end

    def ensure_issue_permission!(permissions)
      return if permissions["issues"] == "write"

      raise verifier_error(
        code: "github_permission_missing",
        message: "GitHub App installation does not grant Issues write permission.",
        safe_detail: "GitHub App requires Issues write permission."
      )
    end

    def create_installation_token(installation_id)
      response = http_client.post_json(
        path: "/app/installations/#{installation_id}/access_tokens",
        headers: github_headers(app_jwt)
      )
      unless response.success?
        raise verifier_error(
          code: "github_installation_token_failed",
          message: "GitHub installation token request failed with status #{response.status}.",
          safe_detail: safe_github_error(response, "GitHub installation token could not be created.")
        )
      end

      token = parse_response_json(response)["token"]
      return token if token.present?

      raise verifier_error(
        code: "github_installation_token_invalid",
        message: "GitHub installation token response did not include a token.",
        safe_detail: "GitHub installation token response was invalid.",
        http_status: :bad_gateway
      )
    end

    def ensure_repository_access!(token, repository)
      response = http_client.get_json(
        path: "/installation/repositories",
        headers: github_headers(token)
      )
      unless response.success?
        raise verifier_error(
          code: "github_repository_verification_failed",
          message: "GitHub repository verification failed with status #{response.status}.",
          safe_detail: safe_github_error(response, "GitHub repository access could not be verified."),
          http_status: :bad_gateway
        )
      end

      repositories = Array(parse_response_json(response)["repositories"])
      return if repositories.any? { |item| item["full_name"].to_s.casecmp?(repository) }

      raise verifier_error(
        code: "github_repository_access_missing",
        message: "GitHub App installation does not include repository #{repository}.",
        safe_detail: "GitHub App is not installed for the selected repository."
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
      raise verifier_error(
        code: "github_app_private_key_invalid",
        message: "GitHub App private key is invalid: #{e.class}",
        safe_detail: "GitHub App private key is invalid."
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
    rescue VerifierError
      fallback
    end

    def parse_response_json(response)
      response.json
    rescue JSON::ParserError
      raise verifier_error(
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

    def verifier_error(code:, message:, safe_detail:, http_status: :failed_dependency)
      VerifierError.new(code: code, message: message, safe_detail: safe_detail, http_status: http_status)
    end
  end
end
