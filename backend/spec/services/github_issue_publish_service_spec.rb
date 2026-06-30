require "rails_helper"

RSpec.describe GithubIssuePublishService do
  it "publishes an issue draft through an injected provider" do
    issue_draft = create(:issue_draft, status: "approved")
    provider = instance_double(
      GithubIssuePublish::DryRunProvider,
      publish: {
        github_issue_number: 42,
        github_issue_url: "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/42",
        github_repository: "Kazuya-Sakashita/ai-pm-platform",
        github_issue_api_id: 420,
        github_issue_node_id: "I_kwDUMMY"
      }
    )

    result = described_class.new(issue_draft, idempotency_key: "publish-key-1", provider: provider).call

    expect(result).to include(status: "published", github_issue_number: 42)
    expect(issue_draft.reload.status).to eq("published")
    expect(issue_draft.github_issue_url).to eq("https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/42")
    expect(issue_draft.github_issue_api_id).to eq(420)
    expect(issue_draft.github_issue_node_id).to eq("I_kwDUMMY")
    expect(issue_draft.publish_idempotency_key).to eq("publish-key-1")
  end

  it "returns an already published issue without calling the provider" do
    issue_draft = create(
      :issue_draft,
      status: "published",
      github_issue_number: 42,
      github_issue_url: "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/42"
    )
    provider = spy("GitHubProvider")

    result = described_class.new(issue_draft, idempotency_key: "publish-key-2", provider: provider).call

    expect(result).to include(status: "published", github_issue_number: 42)
    expect(provider).not_to have_received(:publish)
  end

  it "marks the draft as publish_failed when the provider is not connected" do
    issue_draft = create(:issue_draft, status: "approved")

    expect {
      described_class.new(issue_draft, idempotency_key: "publish-key-3", provider: GithubIssuePublish::DisabledProvider.new).call
    }.to raise_error(GithubIssuePublish::ProviderError)

    expect(issue_draft.reload.status).to eq("publish_failed")
    expect(issue_draft.publish_error).to eq("GitHub integration is not connected.")
  end
end
