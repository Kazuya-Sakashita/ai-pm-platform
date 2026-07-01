require "digest"

class GithubIssuePublishService
  RECONCILIATION_REQUIRED_DETAIL = "GitHub issue may have been created. Reconciliation is required.".freeze

  def initialize(issue_draft, idempotency_key:, provider: GithubIssuePublish::ProviderFactory.build)
    @issue_draft = issue_draft
    @idempotency_key = idempotency_key.presence || SecureRandom.uuid
    @provider = provider
  end

  def call
    return published_result if issue_draft.github_issue_url.present?

    attempt = nil
    result = nil
    issue_draft.update!(
      status: "publishing",
      publish_idempotency_key: idempotency_digest,
      publish_error: nil,
      last_publish_attempt_at: Time.current
    )
    attempt = create_attempt!

    result = provider.publish(
      issue_draft: issue_draft,
      project: project,
      idempotency_key: idempotency_key
    )
    attempt.mark_github_created!(result)

    issue_draft.update!(
      status: "published",
      github_issue_number: result.fetch(:github_issue_number),
      github_issue_url: result.fetch(:github_issue_url),
      github_repository: result.fetch(:github_repository, project.github_repo),
      github_issue_api_id: result[:github_issue_api_id],
      github_issue_node_id: result[:github_issue_node_id],
      publish_error: nil
    )
    attempt.mark_local_saved!

    published_result(attempt)
  rescue GithubIssuePublish::ProviderError => e
    attempt&.mark_failed!(code: e.code, detail: e.safe_detail)
    issue_draft.update!(
      status: "publish_failed",
      publish_error: e.safe_detail,
      last_publish_attempt_at: Time.current
    )
    raise
  rescue ActiveRecord::ActiveRecordError => e
    handle_local_save_failure!(attempt, result, e)
  end

  private

  attr_reader :issue_draft, :idempotency_key, :provider

  def project
    @project ||= issue_draft.requirement.minute.meeting.project
  end

  def create_attempt!
    issue_draft.github_issue_publish_attempts.create!(
      project: project,
      github_repository: project.github_repo.presence || "unknown/repository",
      idempotency_digest: idempotency_digest,
      status: "started",
      started_at: Time.current
    )
  end

  def idempotency_digest
    @idempotency_digest ||= Digest::SHA256.hexdigest(idempotency_key.to_s)
  end

  def handle_local_save_failure!(attempt, result, error)
    raise error unless result

    record_reconciliation_required!(attempt, result)
    record_issue_draft_reconciliation_failure!

    raise GithubIssuePublish::ProviderError.new(
      code: "github_publish_reconciliation_required",
      message: "GitHub issue publish requires reconciliation after local save failure: #{error.class}",
      safe_detail: RECONCILIATION_REQUIRED_DETAIL,
      http_status: :conflict
    )
  end

  def record_reconciliation_required!(attempt, result)
    attempt&.mark_reconciliation_required!(
      code: "github_publish_reconciliation_required",
      detail: RECONCILIATION_REQUIRED_DETAIL,
      result: result
    )
  rescue ActiveRecord::ActiveRecordError
    nil
  end

  def record_issue_draft_reconciliation_failure!
    issue_draft.update!(
      status: "publish_failed",
      publish_error: RECONCILIATION_REQUIRED_DETAIL,
      last_publish_attempt_at: Time.current
    )
  rescue ActiveRecord::ActiveRecordError
    nil
  end

  def published_result(attempt = nil)
    result = {
      status: "published",
      github_issue_number: issue_draft.github_issue_number,
      github_issue_url: issue_draft.github_issue_url
    }
    result[:attempt_id] = attempt.id if attempt
    result
  end
end
