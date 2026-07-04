class CreateConversationSummaryDrafts < ActiveRecord::Migration[7.1]
  def change
    create_table :conversation_summary_drafts, id: :uuid do |t|
      t.references :conversation_import, type: :uuid, null: false, foreign_key: true
      t.string :provider, null: false, default: "deterministic"
      t.string :model
      t.string :status, null: false, default: "draft"
      t.text :summary, null: false
      t.jsonb :decisions, null: false, default: []
      t.jsonb :open_questions, null: false, default: []
      t.jsonb :action_items, null: false, default: []
      t.jsonb :issue_candidates, null: false, default: []
      t.jsonb :requirement_candidates, null: false, default: []
      t.jsonb :risks, null: false, default: []
      t.jsonb :participants, null: false, default: []
      t.jsonb :source_quotes, null: false, default: []
      t.decimal :confidence, precision: 4, scale: 3
      t.jsonb :validation_errors, null: false, default: []
      t.datetime :generated_at, null: false
      t.datetime :approved_at
      t.string :approved_by
      t.timestamps
    end

    add_index :conversation_summary_drafts, [:conversation_import_id, :created_at], name: "index_conversation_summary_drafts_on_import_and_created"
    add_index :conversation_summary_drafts, :status
  end
end
