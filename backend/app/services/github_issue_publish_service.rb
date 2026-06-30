class GithubIssuePublishService
  def initialize(issue_draft, idempotency_key:, provider: GithubIssuePublish::ProviderFactory.build)
    @issue_draft = issue_draft
    @idempotency_key = idempotency_key.presence || SecureRandom.uuid
    @provider = provider
  end

  def call
    return published_result if issue_draft.github_issue_url.present?

    issue_draft.update!(
      status: "publishing",
      publish_idempotency_key: idempotency_key,
      publish_error: nil,
      last_publish_attempt_at: Time.current
    )

    result = provider.publish(
      issue_draft: issue_draft,
      project: project,
      idempotency_key: idempotency_key
    )

    issue_draft.update!(
      status: "published",
      github_issue_number: result.fetch(:github_issue_number),
      github_issue_url: result.fetch(:github_issue_url),
      github_repository: result.fetch(:github_repository, project.github_repo),
      github_issue_api_id: result[:github_issue_api_id],
      github_issue_node_id: result[:github_issue_node_id],
      publish_error: nil
    )

    published_result
  rescue GithubIssuePublish::ProviderError => e
    issue_draft.update!(
      status: "publish_failed",
      publish_error: e.safe_detail,
      last_publish_attempt_at: Time.current
    )
    raise
  end

  private

  attr_reader :issue_draft, :idempotency_key, :provider

  def project
    @project ||= issue_draft.requirement.minute.meeting.project
  end

  def published_result
    {
      status: "published",
      github_issue_number: issue_draft.github_issue_number,
      github_issue_url: issue_draft.github_issue_url
    }
  end
end
