class CreateOpenApiDrafts < ActiveRecord::Migration[7.1]
  def change
    create_table :open_api_drafts, id: :uuid do |t|
      t.references :requirement, null: false, foreign_key: true, type: :uuid
      t.string :status, null: false, default: "draft"
      t.string :title, null: false
      t.text :content, null: false
      t.jsonb :validation_errors, null: false, default: []
      t.string :generated_by_model

      t.timestamps
    end

    add_index :open_api_drafts, :status
    add_index :open_api_drafts, [:requirement_id, :created_at]
  end
end
