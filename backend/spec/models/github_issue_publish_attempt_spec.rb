require "rails_helper"

RSpec.describe GithubIssuePublishAttempt, type: :model do
  it "records GitHub creation and local save lifecycle" do
    attempt = create(:github_issue_publish_attempt)

    attempt.mark_github_created!(
      github_issue_number: 42,
      github_issue_url: "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/42",
      github_issue_api_id: 420,
      github_issue_node_id: "I_kwDUMMY"
    )
    expect(attempt.reload.status).to eq("github_created")
    expect(attempt.github_issue_number).to eq(42)
    expect(attempt.github_created_at).to be_present

    attempt.mark_local_saved!
    expect(attempt.reload.status).to eq("local_saved")
    expect(attempt.completed_at).to be_present
  end

  it "records safe failure details" do
    attempt = create(:github_issue_publish_attempt)

    attempt.mark_failed!(code: "github_integration_not_connected", detail: "GitHub integration is not connected.")

    expect(attempt.reload.status).to eq("failed")
    expect(attempt.safe_error_code).to eq("github_integration_not_connected")
    expect(attempt.safe_error_detail).to eq("GitHub integration is not connected.")
    expect(attempt.completed_at).to be_present
  end

  it "records reconciliation required state" do
    attempt = create(:github_issue_publish_attempt)

    attempt.mark_reconciliation_required!(
      code: "github_publish_reconciliation_required",
      detail: "GitHub issue may have been created. Reconciliation is required."
    )

    expect(attempt.reload.status).to eq("reconciliation_required")
    expect(attempt.safe_error_code).to eq("github_publish_reconciliation_required")
  end

  it "tracks reconciliation retry cooldown and clears it on resolution" do
    attempt = create(:github_issue_publish_attempt, status: "reconciliation_required")
    available_at = 1.minute.from_now

    attempt.schedule_reconciliation_retry!(available_at: available_at)

    expect(attempt.reload.reconciliation_retry_count).to eq(1)
    expect(attempt.next_reconciliation_retry_at).to be_within(1.second).of(available_at)
    expect(attempt.reconciliation_cooldown_active?).to be(true)

    attempt.mark_retry_approved!(detail: "Controlled retry approved.")

    expect(attempt.reload.status).to eq("retry_approved")
    expect(attempt.next_reconciliation_retry_at).to be_nil
  end
end
