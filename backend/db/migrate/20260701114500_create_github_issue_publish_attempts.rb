class CreateGithubIssuePublishAttempts < ActiveRecord::Migration[7.1]
  def change
    create_table :github_issue_publish_attempts, id: :uuid do |t|
      t.references :issue_draft, null: false, foreign_key: true, type: :uuid
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.string :github_repository, null: false
      t.string :idempotency_digest, null: false
      t.string :status, null: false, default: "started"
      t.integer :github_issue_number
      t.string :github_issue_url
      t.integer :github_issue_api_id
      t.string :github_issue_node_id
      t.string :safe_error_code
      t.text :safe_error_detail
      t.datetime :started_at, null: false
      t.datetime :github_created_at
      t.datetime :completed_at
      t.datetime :reconciled_at
      t.timestamps
    end

    add_index :github_issue_publish_attempts,
              %i[issue_draft_id idempotency_digest],
              name: "index_github_publish_attempts_on_draft_and_digest"
    add_index :github_issue_publish_attempts, %i[project_id status]
    add_index :github_issue_publish_attempts, %i[github_repository github_issue_number]
    add_index :github_issue_publish_attempts, :github_issue_node_id
  end
end
