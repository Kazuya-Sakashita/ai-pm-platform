require "zlib"

module GithubIssuePublish
  class DryRunProvider
    def publish(issue_draft:, project:, idempotency_key:)
      repository = project.github_repo.presence || "dry-run/repository"
      number = Zlib.crc32("#{issue_draft.id}:#{idempotency_key}") % 90_000 + 10_000

      {
        github_issue_number: number,
        github_issue_url: "https://github.com/#{repository}/issues/#{number}",
        github_repository: repository,
        github_issue_api_id: number,
        github_issue_node_id: "DRY_RUN_#{number}"
      }
    end
  end
end
