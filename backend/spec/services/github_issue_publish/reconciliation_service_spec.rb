require "rails_helper"
require "digest"

RSpec.describe GithubIssuePublish::ReconciliationService do
  let(:digest) { Digest::SHA256.hexdigest("publish-key-1") }
  let(:issue_draft) { create(:issue_draft, status: "publish_failed", publish_error: "Reconciliation required.") }
  let(:project) { issue_draft.requirement.minute.meeting.project }
  let(:attempt) do
    create(
      :github_issue_publish_attempt,
      issue_draft: issue_draft,
      project: project,
      idempotency_digest: digest,
      status: "reconciliation_required",
      safe_error_code: "github_publish_reconciliation_required",
      safe_error_detail: "GitHub issue may have been created. Reconciliation is required."
    )
  end
  let(:match) do
    {
      github_issue_number: 42,
      github_issue_url: "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/42",
      github_repository: "Kazuya-Sakashita/ai-pm-platform",
      github_issue_api_id: 420,
      github_issue_node_id: "I_kwMATCH"
    }
  end

  it "links the local issue draft when exactly one marker match exists" do
    review = create(
      :review,
      target_type: "issue_draft",
      target_id: issue_draft.id,
      reviewer_role: described_class::REVIEWER_ROLE,
      status: "action_required"
    )
    search_client = instance_double(GithubIssuePublish::MarkerSearchClient, search: [match])

    result = described_class.new(attempt, search_client: search_client).call

    expect(result.status).to eq("reconciled")
    expect(issue_draft.reload.status).to eq("published")
    expect(issue_draft.github_issue_number).to eq(42)
    expect(issue_draft.github_issue_url).to eq("https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/42")
    expect(issue_draft.publish_error).to be_nil
    expect(attempt.reload.status).to eq("reconciled")
    expect(attempt.github_issue_node_id).to eq("I_kwMATCH")
    expect(attempt.reconciled_at).to be_present
    expect(review.reload.status).to eq("resolved")
    audit_log = project.audit_logs.find_by!(action: "issue_draft.github_publish_reconciled")
    expect(audit_log.metadata).to include("attempt_id" => attempt.id, "github_issue_number" => 42, "match_count" => 1)
  end

  it "creates a review blocker when no marker match exists" do
    search_client = instance_double(GithubIssuePublish::MarkerSearchClient, search: [])

    result = described_class.new(attempt, search_client: search_client).call

    expect(result.status).to eq("review_required")
    expect(attempt.reload.status).to eq("reconciliation_required")
    expect(attempt.safe_error_code).to eq("github_publish_reconciliation_no_match")
    expect(issue_draft.reload.github_issue_url).to be_nil
    review = Review.find_by!(
      target_type: "issue_draft",
      target_id: issue_draft.id,
      reviewer_role: described_class::REVIEWER_ROLE
    )
    expect(review.status).to eq("action_required")
    expect(review.improvements.join(" ")).to include("No GitHub Issue marker match")
    audit_log = project.audit_logs.find_by!(action: "issue_draft.github_publish_reconciliation_blocked")
    expect(audit_log.metadata).to include("attempt_id" => attempt.id, "match_count" => 0, "review_id" => review.id)
  end

  it "creates a review blocker when multiple marker matches exist" do
    other_match = match.merge(github_issue_number: 43, github_issue_url: "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/43")
    search_client = instance_double(GithubIssuePublish::MarkerSearchClient, search: [match, other_match])

    result = described_class.new(attempt, search_client: search_client).call

    expect(result.status).to eq("review_required")
    expect(attempt.reload.safe_error_code).to eq("github_publish_reconciliation_multiple_matches")
    review = Review.find_by!(
      target_type: "issue_draft",
      target_id: issue_draft.id,
      reviewer_role: described_class::REVIEWER_ROLE
    )
    expect(review.next_actions.join(" ")).to include("#42")
    expect(review.next_actions.join(" ")).to include("#43")
    expect(issue_draft.reload.github_issue_url).to be_nil
  end

  it "stores safe provider errors on the attempt" do
    search_client = instance_double(GithubIssuePublish::MarkerSearchClient)
    allow(search_client).to receive(:search).and_raise(
      GithubIssuePublish::ProviderError.new(
        code: "github_issue_marker_search_failed",
        message: "GitHub search failed.",
        safe_detail: "GitHub Issue marker search failed.",
        http_status: :bad_gateway
      )
    )

    expect {
      described_class.new(attempt, search_client: search_client).call
    }.to raise_error(GithubIssuePublish::ProviderError)

    expect(attempt.reload.safe_error_code).to eq("github_issue_marker_search_failed")
    expect(attempt.safe_error_detail).to eq("GitHub Issue marker search failed.")
  end
end
