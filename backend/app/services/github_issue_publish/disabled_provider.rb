module GithubIssuePublish
  class DisabledProvider
    def publish(issue_draft:, project:, idempotency_key:)
      raise ProviderError.new(
        code: "github_integration_not_connected",
        message: "GitHub integration is not connected for project #{project.id}.",
        safe_detail: "GitHub integration is not connected.",
        http_status: :failed_dependency
      )
    end
  end
end
