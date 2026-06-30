class CreateRequirements < ActiveRecord::Migration[7.1]
  def change
    create_table :requirements, id: :uuid do |t|
      t.references :minutes, null: false, type: :uuid, foreign_key: true
      t.string :status, null: false, default: "generated"
      t.text :background, null: false
      t.text :goal, null: false
      t.jsonb :user_stories, null: false, default: []
      t.jsonb :functional_requirements, null: false, default: []
      t.jsonb :non_functional_requirements, null: false, default: []
      t.jsonb :acceptance_criteria, null: false, default: []
      t.jsonb :out_of_scope, null: false, default: []
      t.jsonb :open_questions, null: false, default: []
      t.jsonb :risks, null: false, default: []
      t.string :generated_by_model

      t.timestamps
    end

    add_index :requirements, :status
    add_index :requirements, [:minutes_id, :created_at]
  end
end
