class CreateConversationImports < ActiveRecord::Migration[7.1]
  def change
    create_table :conversation_imports, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true
      t.string :source_type, null: false, default: "discord_dm_paste"
      t.string :title, null: false
      t.text :raw_text, null: false
      t.text :redacted_text
      t.jsonb :participants, null: false, default: []
      t.datetime :conversation_started_at
      t.datetime :conversation_ended_at
      t.boolean :consent_confirmed, null: false, default: false
      t.string :consent_confirmed_by
      t.datetime :consent_confirmed_at
      t.string :consent_statement_version, null: false
      t.string :status, null: false, default: "draft"
      t.jsonb :safety_flags, null: false, default: []
      t.jsonb :blocked_reasons, null: false, default: []
      t.string :imported_by, null: false, default: "system"
      t.datetime :last_scanned_at
      t.datetime :approved_at
      t.string :approved_by
      t.datetime :retention_expires_at
      t.timestamps
    end

    add_index :conversation_imports, [:project_id, :created_at]
    add_index :conversation_imports, [:project_id, :status]
    add_index :conversation_imports, [:imported_by, :created_at]
    add_index :conversation_imports, :retention_expires_at
  end
end
