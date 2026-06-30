module GithubIssuePublish
  class ProviderFactory
    def self.build
      case ENV.fetch("GITHUB_ISSUE_PUBLISH_PROVIDER", "").downcase
      when "github_app", "github"
        GithubAppProvider.new
      when "dry_run"
        DryRunProvider.new
      else
        DisabledProvider.new
      end
    end
  end
end
