require "rails_helper"
require "digest"

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
    digest = Digest::SHA256.hexdigest("publish-key-1")

    expect(result).to include(status: "published", github_issue_number: 42)
    expect(issue_draft.reload.status).to eq("published")
    expect(issue_draft.github_issue_url).to eq("https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/42")
    expect(issue_draft.github_issue_api_id).to eq(420)
    expect(issue_draft.github_issue_node_id).to eq("I_kwDUMMY")
    expect(issue_draft.publish_idempotency_key).to eq(digest)
    expect(issue_draft.publish_idempotency_key).not_to include("publish-key-1")
    attempt = issue_draft.github_issue_publish_attempts.last
    expect(result[:attempt_id]).to eq(attempt.id)
    expect(attempt.status).to eq("local_saved")
    expect(attempt.idempotency_digest).to eq(digest)
    expect(attempt.github_issue_number).to eq(42)
    expect(attempt.github_issue_node_id).to eq("I_kwDUMMY")
    expect(attempt.completed_at).to be_present
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
    attempt = issue_draft.github_issue_publish_attempts.last
    expect(attempt.status).to eq("failed")
    expect(attempt.safe_error_code).to eq("github_integration_not_connected")
    expect(attempt.safe_error_detail).to eq("GitHub integration is not connected.")
  end

  it "records repeated failed attempts for the same idempotency digest" do
    issue_draft = create(:issue_draft, status: "approved")
    digest = Digest::SHA256.hexdigest("publish-key-repeat")

    2.times do
      expect {
        described_class.new(
          issue_draft,
          idempotency_key: "publish-key-repeat",
          provider: GithubIssuePublish::DisabledProvider.new
        ).call
      }.to raise_error(GithubIssuePublish::ProviderError)
    end

    attempts = issue_draft.github_issue_publish_attempts.where(idempotency_digest: digest).order(:created_at)
    expect(attempts.count).to eq(2)
    expect(attempts.map(&:status)).to eq(%w[failed failed])
  end

  it "marks reconciliation required when local save fails after GitHub creates the issue" do
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
    allow(issue_draft).to receive(:update!).and_wrap_original do |original, *args|
      attributes = args.first
      raise ActiveRecord::ActiveRecordError, "local save failed" if attributes[:status] == "published"

      original.call(*args)
    end

    expect {
      described_class.new(issue_draft, idempotency_key: "publish-key-4", provider: provider).call
    }.to raise_error(GithubIssuePublish::ProviderError) { |error|
      expect(error.code).to eq("github_publish_reconciliation_required")
      expect(error.safe_detail).to eq("GitHub issue may have been created. Reconciliation is required.")
    }

    expect(issue_draft.reload.status).to eq("publish_failed")
    expect(issue_draft.publish_error).to eq("GitHub issue may have been created. Reconciliation is required.")
    attempt = issue_draft.github_issue_publish_attempts.last
    expect(attempt.status).to eq("reconciliation_required")
    expect(attempt.github_issue_number).to eq(42)
    expect(attempt.github_issue_url).to eq("https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/42")
    expect(attempt.safe_error_code).to eq("github_publish_reconciliation_required")
  end

  it "marks reconciliation required when attempt update fails after GitHub creates the issue" do
    issue_draft = create(:issue_draft, status: "approved")
    provider = instance_double(
      GithubIssuePublish::DryRunProvider,
      publish: {
        github_issue_number: 43,
        github_issue_url: "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/43",
        github_repository: "Kazuya-Sakashita/ai-pm-platform",
        github_issue_api_id: 430,
        github_issue_node_id: "I_kwDUMMY43"
      }
    )
    allow_any_instance_of(GithubIssuePublishAttempt).to receive(:mark_github_created!)
      .and_raise(ActiveRecord::ActiveRecordError, "attempt save failed")

    expect {
      described_class.new(issue_draft, idempotency_key: "publish-key-5", provider: provider).call
    }.to raise_error(GithubIssuePublish::ProviderError) { |error|
      expect(error.code).to eq("github_publish_reconciliation_required")
    }

    expect(issue_draft.reload.status).to eq("publish_failed")
    attempt = issue_draft.github_issue_publish_attempts.last
    expect(attempt.status).to eq("reconciliation_required")
    expect(attempt.github_issue_number).to eq(43)
    expect(attempt.github_issue_node_id).to eq("I_kwDUMMY43")
  end
end
