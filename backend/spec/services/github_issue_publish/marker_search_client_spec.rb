require "rails_helper"
require "digest"

RSpec.describe GithubIssuePublish::MarkerSearchClient do
  class FakeMarkerSearchHttpClient
    attr_reader :requests

    def initialize(responses)
      @responses = responses
      @requests = []
    end

    def post_json(path:, headers:, body: nil)
      requests << { method: "POST", path: path, headers: headers, body: body }
      responses.shift
    end

    def get_json(path:, headers:)
      requests << { method: "GET", path: path, headers: headers }
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

  it "searches GitHub Issues by the AI PM marker" do
    issue_draft = create(:issue_draft, status: "publish_failed")
    project = issue_draft.requirement.minute.meeting.project
    create(:integration_account, project: project)
    digest = Digest::SHA256.hexdigest("publish-key-1")
    http_client = FakeMarkerSearchHttpClient.new(
      [
        github_response(status: 201, body: { token: "github-installation-token" }),
        github_response(
          status: 200,
          body: {
            total_count: 1,
            items: [
              {
                number: 42,
                title: "Reconcile generated Issue",
                state: "open",
                html_url: "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/42",
                updated_at: "2026-07-02T01:23:45Z",
                score: 17.5,
                id: 420,
                node_id: "I_kwSEARCH"
              }
            ]
          }
        )
      ]
    )

    matches = described_class.new(app_id: "999", private_key_pem: private_key_pem, http_client: http_client)
                             .search(issue_draft: issue_draft, project: project, idempotency_digest: digest)

    expect(matches).to contain_exactly(
      include(
        github_issue_number: 42,
        github_issue_url: "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/42",
        github_repository: "Kazuya-Sakashita/ai-pm-platform",
        github_issue_title: "Reconcile generated Issue",
        github_issue_state: "open",
        github_issue_updated_at: "2026-07-02T01:23:45Z",
        github_issue_score: 17.5,
        github_issue_api_id: 420,
        github_issue_node_id: "I_kwSEARCH"
      )
    )
    expect(http_client.requests.first[:path]).to eq("/app/installations/123456/access_tokens")
    expect(http_client.requests.second[:method]).to eq("GET")
    search_uri = URI.parse("https://api.github.test#{http_client.requests.second[:path]}")
    query = URI.decode_www_form(search_uri.query).to_h.fetch("q")
    expect(query).to include("repo:Kazuya-Sakashita/ai-pm-platform")
    expect(query).to include("is:issue")
    expect(query).to include("ai_pm_platform:issue_draft_id=#{issue_draft.id}")
    expect(query).to include("idempotency_digest=#{digest[0, 16]}")
    expect(http_client.requests.second[:headers]["Authorization"]).to eq("Bearer github-installation-token")
  end

  it "stops safely when the project has no connected GitHub installation" do
    issue_draft = create(:issue_draft, status: "publish_failed")
    project = issue_draft.requirement.minute.meeting.project
    http_client = FakeMarkerSearchHttpClient.new([])

    expect {
      described_class.new(app_id: "999", private_key_pem: private_key_pem, http_client: http_client)
                     .search(issue_draft: issue_draft, project: project, idempotency_digest: "digest")
    }.to raise_error(GithubIssuePublish::ProviderError) { |error|
      expect(error.code).to eq("github_integration_not_connected")
      expect(error.safe_detail).to eq("GitHub integration is not connected.")
    }
    expect(http_client.requests).to be_empty
  end
end
