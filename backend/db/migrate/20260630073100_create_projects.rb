class CreateProjects < ActiveRecord::Migration[7.1]
  def change
    create_table :projects, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.string :status, null: false, default: "active"
      t.string :github_repo

      t.timestamps
    end

    add_index :projects, :status
  end
end
