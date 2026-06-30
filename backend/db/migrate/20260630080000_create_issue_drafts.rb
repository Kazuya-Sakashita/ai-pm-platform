class CreateIssueDrafts < ActiveRecord::Migration[7.1]
  def change
    create_table :issue_drafts, id: :uuid do |t|
      t.references :requirement, null: false, type: :uuid, foreign_key: true
      t.string :status, null: false, default: "draft"
      t.string :title, null: false
      t.text :body, null: false
      t.jsonb :acceptance_criteria, null: false, default: []
      t.jsonb :labels, null: false, default: []
      t.integer :github_issue_number
      t.string :github_issue_url
      t.text :publish_error

      t.timestamps
    end

    add_index :issue_drafts, :status
    add_index :issue_drafts, [:requirement_id, :created_at]
    add_index :issue_drafts, :github_issue_number
  end
end
