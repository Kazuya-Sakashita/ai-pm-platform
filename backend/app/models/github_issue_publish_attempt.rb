class GithubIssuePublishAttempt < ApplicationRecord
  STATUSES = %w[started github_created local_saved failed reconciliation_required reconciled retry_approved].freeze

  belongs_to :issue_draft
  belongs_to :project

  validates :github_repository, :idempotency_digest, :started_at, presence: true
  validates :status, inclusion: { in: STATUSES }

  before_validation :set_defaults

  def github_created?
    status == "github_created"
  end

  def mark_github_created!(result)
    update!(
      status: "github_created",
      github_issue_number: result.fetch(:github_issue_number),
      github_issue_url: result.fetch(:github_issue_url),
      github_issue_api_id: result[:github_issue_api_id],
      github_issue_node_id: result[:github_issue_node_id],
      github_created_at: Time.current,
      safe_error_code: nil,
      safe_error_detail: nil
    )
  end

  def mark_local_saved!
    update!(
      status: "local_saved",
      completed_at: Time.current,
      safe_error_code: nil,
      safe_error_detail: nil
    )
  end

  def mark_failed!(code:, detail:)
    update!(
      status: "failed",
      safe_error_code: code,
      safe_error_detail: detail,
      completed_at: Time.current
    )
  end

  def mark_reconciliation_required!(code:, detail:, result: nil)
    attributes = {
      status: "reconciliation_required",
      safe_error_code: code,
      safe_error_detail: detail,
      completed_at: Time.current
    }
    attributes.merge!(github_attributes(result)) if result

    update!(attributes)
  end

  def mark_reconciled!(result)
    update!(
      status: "reconciled",
      github_issue_number: result.fetch(:github_issue_number),
      github_issue_url: result.fetch(:github_issue_url),
      github_issue_api_id: result[:github_issue_api_id],
      github_issue_node_id: result[:github_issue_node_id],
      safe_error_code: nil,
      safe_error_detail: nil,
      completed_at: Time.current,
      reconciled_at: Time.current
    )
  end

  def mark_retry_approved!(detail:)
    update!(
      status: "retry_approved",
      safe_error_code: nil,
      safe_error_detail: detail,
      completed_at: Time.current
    )
  end

  private

  def set_defaults
    self.status ||= "started"
    self.started_at ||= Time.current
  end

  def github_attributes(result)
    {
      github_issue_number: result.fetch(:github_issue_number),
      github_issue_url: result.fetch(:github_issue_url),
      github_issue_api_id: result[:github_issue_api_id],
      github_issue_node_id: result[:github_issue_node_id],
      github_created_at: github_created_at || Time.current
    }
  end
end
