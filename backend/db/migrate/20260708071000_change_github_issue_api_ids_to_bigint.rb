class ChangeGithubIssueApiIdsToBigint < ActiveRecord::Migration[7.1]
  def change
    change_column :issue_drafts, :github_issue_api_id, :bigint
    change_column :github_issue_publish_attempts, :github_issue_api_id, :bigint
  end
end
