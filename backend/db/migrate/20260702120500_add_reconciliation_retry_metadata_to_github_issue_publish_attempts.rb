class AddReconciliationRetryMetadataToGithubIssuePublishAttempts < ActiveRecord::Migration[7.1]
  def change
    add_column :github_issue_publish_attempts, :reconciliation_retry_count, :integer, null: false, default: 0
    add_column :github_issue_publish_attempts, :next_reconciliation_retry_at, :datetime
  end
end
