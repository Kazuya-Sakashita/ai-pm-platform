require "rails_helper"

RSpec.describe GithubIssuePublish::GithubAppProvider do
  class FakeGithubHttpClient
    attr_reader :requests

    def initialize(responses)
      @responses = responses
      @requests = []
    end

    def post_json(path:, headers:, body: nil)
      requests << { path: path, headers: headers, body: body }
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

  it "publishes through a connected GitHub App installation" do
    issue_draft = create(:issue_draft, status: "approved")
    project = issue_draft.requirement.minute.meeting.project
    create(:integration_account, project: project)
    http_client = FakeGithubHttpClient.new(
      [
        github_response(status: 201, body: { token: "github-installation-token" }),
        github_response(
          status: 201,
          body: {
            number: 88,
            html_url: "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/88",
            id: 8800,
            node_id: "I_kwREAL"
          }
        )
      ]
    )

    result = described_class.new(
      app_id: "999",
      private_key_pem: private_key_pem,
      http_client: http_client
    ).publish(issue_draft: issue_draft, project: project, idempotency_key: "publish-key-4")

    expect(result).to include(
      github_issue_number: 88,
      github_issue_url: "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/88",
      github_repository: "Kazuya-Sakashita/ai-pm-platform",
      github_issue_api_id: 8800,
      github_issue_node_id: "I_kwREAL"
    )
    expect(http_client.requests.first[:path]).to eq("/app/installations/123456/access_tokens")
    expect(http_client.requests.first[:headers]["Authorization"]).to match(/\ABearer [^.]+\.[^.]+\.[^.]+\z/)
    expect(http_client.requests.first[:body]).to eq({ permissions: { issues: "write" } })
    expect(http_client.requests.second[:path]).to eq("/repos/Kazuya-Sakashita/ai-pm-platform/issues")
    expect(http_client.requests.second[:headers]["Authorization"]).to eq("Bearer github-installation-token")
    expect(http_client.requests.second[:body][:title]).to eq(issue_draft.title)
    expect(http_client.requests.second[:body][:body]).to include("ai_pm_platform:issue_draft_id=#{issue_draft.id}")
    expect(http_client.requests.second[:body][:body]).to include("idempotency_digest=#{Digest::SHA256.hexdigest("publish-key-4")[0, 16]}")
    expect(http_client.requests.second[:body][:body]).not_to include("publish-key-4")
    expect(http_client.requests.second[:body][:labels]).to eq(issue_draft.labels)
  end

  it "stops safely when the project has no connected installation" do
    issue_draft = create(:issue_draft, status: "approved")
    project = issue_draft.requirement.minute.meeting.project
    http_client = FakeGithubHttpClient.new([])

    expect {
      described_class.new(app_id: "999", private_key_pem: private_key_pem, http_client: http_client)
                     .publish(issue_draft: issue_draft, project: project, idempotency_key: "publish-key-5")
    }.to raise_error(GithubIssuePublish::ProviderError) { |error|
      expect(error.code).to eq("github_integration_not_connected")
      expect(error.safe_detail).to eq("GitHub integration is not connected.")
    }
    expect(http_client.requests).to be_empty
  end

  it "stops when Issues write permission is missing" do
    issue_draft = create(:issue_draft, status: "approved")
    project = issue_draft.requirement.minute.meeting.project
    account = create(
      :integration_account,
      project: project,
      granted_permissions: { "metadata" => "read", "issues" => "read" }
    )
    http_client = FakeGithubHttpClient.new([])

    expect {
      described_class.new(app_id: "999", private_key_pem: private_key_pem, http_client: http_client)
                     .publish(issue_draft: issue_draft, project: project, idempotency_key: "publish-key-6")
    }.to raise_error(GithubIssuePublish::ProviderError) { |error|
      expect(error.code).to eq("github_permission_missing")
      expect(error.safe_detail).to eq("GitHub App requires Issues write permission.")
    }
    expect(account.reload.status).to eq("error")
    expect(account.last_error_safe).to eq("GitHub App requires Issues write permission.")
    expect(http_client.requests).to be_empty
  end

  it "records a safe error when installation token creation fails" do
    issue_draft = create(:issue_draft, status: "approved")
    project = issue_draft.requirement.minute.meeting.project
    account = create(:integration_account, project: project)
    http_client = FakeGithubHttpClient.new(
      [github_response(status: 403, body: { message: "Resource not accessible by integration" })]
    )

    expect {
      described_class.new(app_id: "999", private_key_pem: private_key_pem, http_client: http_client)
                     .publish(issue_draft: issue_draft, project: project, idempotency_key: "publish-key-7")
    }.to raise_error(GithubIssuePublish::ProviderError) { |error|
      expect(error.code).to eq("github_installation_token_failed")
      expect(error.safe_detail).to eq("Resource not accessible by integration")
    }
    expect(account.reload.status).to eq("error")
    expect(account.last_error_safe).to eq("Resource not accessible by integration")
  end

  it "requires GitHub App credentials" do
    issue_draft = create(:issue_draft, status: "approved")
    project = issue_draft.requirement.minute.meeting.project
    create(:integration_account, project: project)

    expect {
      described_class.new(app_id: nil, private_key_pem: nil, http_client: FakeGithubHttpClient.new([]))
                     .publish(issue_draft: issue_draft, project: project, idempotency_key: "publish-key-8")
    }.to raise_error(GithubIssuePublish::ProviderError) { |error|
      expect(error.code).to eq("github_app_not_configured")
      expect(error.safe_detail).to eq("GitHub App is not configured.")
    }
  end
end
