class CreateReviews < ActiveRecord::Migration[7.1]
  def change
    create_table :reviews, id: :uuid do |t|
      t.string :target_type, null: false
      t.string :target_id, null: false
      t.string :status, null: false, default: "open"
      t.string :reviewer_role, null: false
      t.jsonb :framework, null: false, default: []
      t.jsonb :positives, null: false, default: []
      t.jsonb :improvements, null: false, default: []
      t.jsonb :priority, null: false, default: []
      t.jsonb :next_actions, null: false, default: []
      t.jsonb :issue_numbers, null: false, default: []
      t.jsonb :accepted_risk
      t.text :resolution_note

      t.timestamps
    end

    add_index :reviews, [:target_type, :target_id]
    add_index :reviews, :status
  end
end
