class AddRetentionFieldsToConversationImports < ActiveRecord::Migration[7.1]
  def change
    add_column :conversation_imports, :raw_text_retention_expires_at, :datetime
    add_column :conversation_imports, :raw_text_purged_at, :datetime
    add_column :conversation_imports, :anonymized_at, :datetime
    add_column :conversation_summary_drafts, :retention_expires_at, :datetime

    add_index :conversation_imports, :raw_text_retention_expires_at
    add_index :conversation_imports, :raw_text_purged_at
    add_index :conversation_imports, :anonymized_at
    add_index :conversation_summary_drafts, :retention_expires_at

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE conversation_imports
          SET raw_text_retention_expires_at = COALESCE(raw_text_retention_expires_at, created_at + INTERVAL '30 days'),
              retention_expires_at = COALESCE(retention_expires_at, created_at + INTERVAL '180 days')
        SQL

        execute <<~SQL.squish
          UPDATE conversation_summary_drafts
          SET retention_expires_at = COALESCE(retention_expires_at, created_at + INTERVAL '180 days')
        SQL
      end
    end
  end
end
