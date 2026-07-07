class CreateJobQueueMappings < ActiveRecord::Migration[7.1]
  def change
    create_table :job_queue_mappings, id: :uuid do |t|
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.references :job, null: false, foreign_key: true, type: :uuid
      t.string :provider, null: false, default: "solid_queue"
      t.bigint :solid_queue_job_id, null: false
      t.string :active_job_id
      t.string :queue_name
      t.string :job_class_name
      t.datetime :scheduled_at

      t.timestamps
    end

    add_index :job_queue_mappings, [ :provider, :solid_queue_job_id ], unique: true
    add_index :job_queue_mappings, [ :job_id, :created_at ]
    add_index :job_queue_mappings, [ :project_id, :created_at ]
    add_index :job_queue_mappings, :active_job_id
  end
end
