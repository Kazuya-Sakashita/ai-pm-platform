class CreateMinutes < ActiveRecord::Migration[7.1]
  def change
    create_table :minutes, id: :uuid do |t|
      t.references :meeting, null: false, foreign_key: true, type: :uuid
      t.string :status, null: false, default: "generated"
      t.text :summary, null: false
      t.jsonb :decisions, null: false, default: []
      t.jsonb :open_questions, null: false, default: []
      t.jsonb :action_items, null: false, default: []
      t.string :generated_by_model

      t.timestamps
    end

    add_index :minutes, [:meeting_id, :created_at]
    add_index :minutes, :status
  end
end
