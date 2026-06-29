class CreateAuditLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :audit_logs, id: :uuid do |t|
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.string :actor_id, null: false, default: "system"
      t.string :action, null: false
      t.string :target_type, null: false
      t.string :target_id, null: false
      t.string :summary
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :audit_logs, [:project_id, :created_at]
    add_index :audit_logs, [:target_type, :target_id]
  end
end
