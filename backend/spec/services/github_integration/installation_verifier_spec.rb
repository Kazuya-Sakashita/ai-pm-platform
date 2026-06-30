require "rails_helper"

RSpec.describe GithubIntegration::InstallationVerifier do
  class FakeInstallationHttpClient
    attr_reader :requests

    def initialize(responses)
      @responses = responses
      @requests = []
    end

    def get_json(path:, headers:)
      requests << { method: :get, path: path, headers: headers }
      responses.shift
    end

    def post_json(path:, headers:, body: nil)
      requests << { method: :post, path: path, headers: headers, body: body }
      responses.shift
    end

    private

    attr_reader :responses
  end

  def github_response(status:, body:)
    GithubIssuePublish::HttpClient::Response.new(
      status: status,
      body: JSON.generate(body),
      headers: {}
    )
  end

  let(:private_key_pem) { OpenSSL::PKey::RSA.generate(2048).to_pem }

  it "verifies installation, permissions, and repository access through GitHub API" do
    http_client = FakeInstallationHttpClient.new(
      [
        github_response(
          status: 200,
          body: {
            id: 987_654,
            account: { login: "Kazuya-Sakashita", type: "User" },
            target_type: "User",
            permissions: { metadata: "read", issues: "write" }
          }
        ),
        github_response(status: 201, body: { token: "github-installation-token" }),
        github_response(
          status: 200,
          body: {
            repositories: [
              { full_name: "Kazuya-Sakashita/ai-pm-platform" }
            ]
          }
        )
      ]
    )

    result = described_class.new(
      app_id: "999",
      private_key_pem: private_key_pem,
      http_client: http_client
    ).verify(installation_id: "987654", repository: "Kazuya-Sakashita/ai-pm-platform")

    expect(result.installation_id).to eq("987654")
    expect(result.account_login).to eq("Kazuya-Sakashita")
    expect(result.account_type).to eq("User")
    expect(result.granted_permissions).to include("issues" => "write")
    expect(http_client.requests.map { |request| [request[:method], request[:path]] }).to eq(
      [
        [:get, "/app/installations/987654"],
        [:post, "/app/installations/987654/access_tokens"],
        [:get, "/installation/repositories"]
      ]
    )
    expect(http_client.requests.first[:headers]["Authorization"]).to match(/\ABearer [^.]+\.[^.]+\.[^.]+\z/)
    expect(http_client.requests.third[:headers]["Authorization"]).to eq("Bearer github-installation-token")
  end

  it "stops when the installation does not grant Issues write permission" do
    http_client = FakeInstallationHttpClient.new(
      [
        github_response(
          status: 200,
          body: {
            account: { login: "Kazuya-Sakashita", type: "User" },
            permissions: { metadata: "read", issues: "read" }
          }
        )
      ]
    )

    expect {
      described_class.new(app_id: "999", private_key_pem: private_key_pem, http_client: http_client)
                     .verify(installation_id: "987654", repository: "Kazuya-Sakashita/ai-pm-platform")
    }.to raise_error(GithubIntegration::VerifierError) { |error|
      expect(error.code).to eq("github_permission_missing")
      expect(error.safe_detail).to eq("GitHub App requires Issues write permission.")
    }
    expect(http_client.requests.size).to eq(1)
  end

  it "stops when the selected repository is not part of the installation" do
    http_client = FakeInstallationHttpClient.new(
      [
        github_response(
          status: 200,
          body: {
            account: { login: "Kazuya-Sakashita", type: "User" },
            permissions: { metadata: "read", issues: "write" }
          }
        ),
        github_response(status: 201, body: { token: "github-installation-token" }),
        github_response(
          status: 200,
          body: {
            repositories: [
              { full_name: "Kazuya-Sakashita/another-repository" }
            ]
          }
        )
      ]
    )

    expect {
      described_class.new(app_id: "999", private_key_pem: private_key_pem, http_client: http_client)
                     .verify(installation_id: "987654", repository: "Kazuya-Sakashita/ai-pm-platform")
    }.to raise_error(GithubIntegration::VerifierError) { |error|
      expect(error.code).to eq("github_repository_access_missing")
      expect(error.safe_detail).to eq("GitHub App is not installed for the selected repository.")
    }
  end

  it "requires GitHub App credentials" do
    expect {
      described_class.new(app_id: nil, private_key_pem: nil, http_client: FakeInstallationHttpClient.new([]))
                     .verify(installation_id: "987654", repository: "Kazuya-Sakashita/ai-pm-platform")
    }.to raise_error(GithubIntegration::VerifierError) { |error|
      expect(error.code).to eq("github_app_not_configured")
      expect(error.safe_detail).to eq("GitHub App is not configured.")
    }
  end

  it "translates shared GitHub HTTP client failures into verifier errors" do
    http_client = instance_double(GithubIssuePublish::HttpClient)
    allow(http_client).to receive(:get_json).and_raise(
      GithubIssuePublish::ProviderError.new(
        code: "github_api_unreachable",
        message: "GitHub API request failed: SocketError",
        safe_detail: "GitHub API is temporarily unreachable.",
        http_status: :bad_gateway
      )
    )

    expect {
      described_class.new(app_id: "999", private_key_pem: private_key_pem, http_client: http_client)
                     .verify(installation_id: "987654", repository: "Kazuya-Sakashita/ai-pm-platform")
    }.to raise_error(GithubIntegration::VerifierError) { |error|
      expect(error.code).to eq("github_api_unreachable")
      expect(error.safe_detail).to eq("GitHub API is temporarily unreachable.")
      expect(error.http_status).to eq(:bad_gateway)
    }
  end
end
