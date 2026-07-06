class CreateReviewStateEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :review_state_events, id: :uuid do |t|
      t.references :review, null: false, foreign_key: true, type: :uuid
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.string :target_type, null: false
      t.string :target_id, null: false
      t.string :event_type, null: false
      t.string :from_status
      t.string :to_status, null: false
      t.string :actor_id, null: false, default: "system"
      t.string :reason_code
      t.string :reason_summary
      t.jsonb :issue_numbers, null: false, default: []
      t.jsonb :metadata, null: false, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :review_state_events, [:review_id, :occurred_at]
    add_index :review_state_events, [:project_id, :occurred_at]
    add_index :review_state_events, [:target_type, :target_id, :occurred_at]
    add_index :review_state_events, [:event_type, :occurred_at]
  end
end
