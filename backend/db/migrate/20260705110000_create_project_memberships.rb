class CreateProjectMemberships < ActiveRecord::Migration[7.1]
  def change
    create_table :project_memberships, id: :uuid do |t|
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.string :actor_id, null: false
      t.string :role, null: false
      t.string :status, null: false, default: "active"

      t.timestamps
    end

    add_index :project_memberships, [:project_id, :actor_id], unique: true
    add_index :project_memberships, [:actor_id, :status]
    add_index :project_memberships, [:project_id, :role]
  end
end
