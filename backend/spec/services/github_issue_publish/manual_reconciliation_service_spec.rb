require "rails_helper"
require "digest"

RSpec.describe GithubIssuePublish::ManualReconciliationService do
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
      safe_error_code: "github_publish_reconciliation_multiple_matches",
      safe_error_detail: "Multiple GitHub Issue marker matches were found."
    )
  end

  it "manually links an existing GitHub issue and resolves the blocker" do
    review = create(
      :review,
      target_type: "issue_draft",
      target_id: issue_draft.id,
      reviewer_role: described_class::REVIEWER_ROLE,
      status: "action_required"
    )
    job = create(:job, project: project, job_type: "github_reconciliation", target_type: "issue_draft", target_id: issue_draft.id)

    result = described_class.new(
      attempt,
      {
        resolution_action: "link_existing_issue",
        resolution_note: "Reviewed duplicate candidates and selected #42.",
        github_issue_number: 42,
        github_issue_url: "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/42",
        github_issue_api_id: 420,
        github_issue_node_id: "I_kwMANUAL"
      },
      job: job
    ).call

    expect(result.status).to eq("manually_reconciled")
    expect(issue_draft.reload.status).to eq("published")
    expect(issue_draft.github_issue_number).to eq(42)
    expect(issue_draft.github_issue_url).to eq("https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/42")
    expect(issue_draft.publish_error).to be_nil
    expect(attempt.reload.status).to eq("reconciled")
    expect(attempt.github_issue_node_id).to eq("I_kwMANUAL")
    expect(review.reload.status).to eq("resolved")
    expect(review.resolution_note).to include("Reviewed duplicate candidates")
    audit_log = project.audit_logs.find_by!(action: "issue_draft.github_publish_manually_reconciled")
    expect(audit_log.metadata).to include("attempt_id" => attempt.id, "job_id" => job.id, "github_issue_number" => 42)
  end

  it "approves a controlled retry and clears the blocker" do
    review = create(
      :review,
      target_type: "issue_draft",
      target_id: issue_draft.id,
      reviewer_role: described_class::REVIEWER_ROLE,
      status: "action_required"
    )

    result = described_class.new(
      attempt,
      {
        resolution_action: "approve_retry",
        resolution_note: "Confirmed no GitHub Issue exists after marker search delay.",
        resolution_approver: "Kazuya Reviewer",
        retry_reason_template: "github_issue_absence_confirmed"
      }
    ).call

    expect(result.status).to eq("retry_approved")
    expect(result.resolution_approver).to eq("Kazuya Reviewer")
    expect(result.retry_reason_template).to eq("github_issue_absence_confirmed")
    expect(issue_draft.reload.status).to eq("approved")
    expect(issue_draft.publish_error).to be_nil
    expect(attempt.reload.status).to eq("retry_approved")
    expect(attempt.safe_error_detail).to include("Controlled retry approved by Kazuya Reviewer")
    expect(review.reload.status).to eq("resolved")
    expect(review.resolution_note).to include("Kazuya Reviewer")
    audit_log = project.audit_logs.find_by!(action: "issue_draft.github_publish_retry_approved")
    expect(audit_log.metadata).to include(
      "attempt_id" => attempt.id,
      "resolution_approver" => "Kazuya Reviewer",
      "retry_reason_template" => "github_issue_absence_confirmed",
      "retry_reason_template_label" => "GitHub上でIssue未作成を確認したため1回だけ再試行を承認します。"
    )
  end

  it "rejects GitHub issue URLs outside the project repository" do
    expect {
      described_class.new(
        attempt,
        {
          resolution_action: "link_existing_issue",
          resolution_note: "Wrong repository should be rejected.",
          github_issue_number: 42,
          github_issue_url: "https://github.com/Other/repo/issues/42"
        }
      ).call
    }.to raise_error(GithubIssuePublish::ProviderError) { |error|
      expect(error.code).to eq("github_reconciliation_issue_url_invalid")
      expect(error.http_status).to eq(:unprocessable_entity)
    }
  end

  it "requires a resolution note" do
    expect {
      described_class.new(attempt, { resolution_action: "approve_retry" }).call
    }.to raise_error(GithubIssuePublish::ProviderError) { |error|
      expect(error.code).to eq("github_reconciliation_resolution_note_required")
    }
  end

  it "requires retry approval metadata for controlled retry" do
    expect {
      described_class.new(
        attempt,
        {
          resolution_action: "approve_retry",
          resolution_note: "Confirmed no GitHub Issue exists after marker search delay.",
          retry_reason_template: "github_issue_absence_confirmed"
        }
      ).call
    }.to raise_error(GithubIssuePublish::ProviderError) { |error|
      expect(error.code).to eq("github_reconciliation_retry_approver_required")
    }

    expect {
      described_class.new(
        attempt,
        {
          resolution_action: "approve_retry",
          resolution_note: "Confirmed no GitHub Issue exists after marker search delay.",
          resolution_approver: "Kazuya Reviewer",
          retry_reason_template: "custom_reason"
        }
      ).call
    }.to raise_error(GithubIssuePublish::ProviderError) { |error|
      expect(error.code).to eq("github_reconciliation_retry_reason_template_invalid")
    }

    expect {
      described_class.new(
        attempt,
        {
          resolution_action: "approve_retry",
          resolution_note: "Confirmed no GitHub Issue exists after marker search delay.",
          resolution_approver: "A" * 121,
          retry_reason_template: "github_issue_absence_confirmed"
        }
      ).call
    }.to raise_error(GithubIssuePublish::ProviderError) { |error|
      expect(error.code).to eq("github_reconciliation_retry_approver_too_long")
    }
  end

  it "rejects an oversized resolution note" do
    expect {
      described_class.new(
        attempt,
        {
          resolution_action: "approve_retry",
          resolution_note: "A" * 2001,
          resolution_approver: "Kazuya Reviewer",
          retry_reason_template: "github_issue_absence_confirmed"
        }
      ).call
    }.to raise_error(GithubIssuePublish::ProviderError) { |error|
      expect(error.code).to eq("github_reconciliation_resolution_note_too_long")
    }
  end
end
