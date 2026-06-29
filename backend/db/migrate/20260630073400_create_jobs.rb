class CreateJobs < ActiveRecord::Migration[7.1]
  def change
    create_table :jobs, id: :uuid do |t|
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.string :job_type, null: false
      t.string :status, null: false, default: "queued"
      t.string :target_type, null: false
      t.string :target_id
      t.integer :progress, null: false, default: 0
      t.string :error_code
      t.text :error_message
      t.text :safe_error_detail

      t.timestamps
    end

    add_index :jobs, [:project_id, :status]
    add_index :jobs, [:target_type, :target_id]
  end
end
