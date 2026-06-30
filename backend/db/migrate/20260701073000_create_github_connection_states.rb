class CreateGithubConnectionStates < ActiveRecord::Migration[7.1]
  def change
    create_table :github_connection_states, id: :uuid do |t|
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.string :repository_owner, null: false
      t.string :repository_name, null: false
      t.string :nonce_digest, null: false
      t.string :state_digest, null: false
      t.string :redirect_uri
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps
    end

    add_index :github_connection_states, :nonce_digest, unique: true
    add_index :github_connection_states, :state_digest, unique: true
    add_index :github_connection_states, %i[project_id expires_at]
    add_index :github_connection_states, :consumed_at
  end
end
