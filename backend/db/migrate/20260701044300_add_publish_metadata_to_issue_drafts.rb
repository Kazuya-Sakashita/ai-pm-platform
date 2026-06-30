class AddPublishMetadataToIssueDrafts < ActiveRecord::Migration[7.1]
  def change
    add_column :issue_drafts, :publish_idempotency_key, :string
    add_column :issue_drafts, :github_repository, :string
    add_column :issue_drafts, :github_issue_api_id, :integer
    add_column :issue_drafts, :github_issue_node_id, :string
    add_column :issue_drafts, :last_publish_attempt_at, :datetime

    add_index :issue_drafts, :publish_idempotency_key, unique: true
    add_index :issue_drafts, :github_issue_url, unique: true
  end
end
