class CreateMeetings < ActiveRecord::Migration[7.1]
  def change
    create_table :meetings, id: :uuid do |t|
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.string :title, null: false
      t.string :source_type, null: false, default: "manual"
      t.date :meeting_date
      t.jsonb :participants, null: false, default: []
      t.text :raw_text, null: false
      t.string :status, null: false, default: "draft"
      t.jsonb :tags, null: false, default: []

      t.timestamps
    end

    add_index :meetings, [:project_id, :created_at]
    add_index :meetings, :status
  end
end
