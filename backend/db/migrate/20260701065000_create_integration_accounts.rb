class CreateIntegrationAccounts < ActiveRecord::Migration[7.1]
  def change
    create_table :integration_accounts, id: :uuid do |t|
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.string :provider, null: false, default: "github"
      t.string :status, null: false, default: "not_connected"
      t.string :external_account_id
      t.string :repository_owner, null: false
      t.string :repository_name, null: false
      t.string :github_installation_id
      t.string :github_account_login
      t.string :github_account_type
      t.jsonb :granted_permissions, null: false, default: {}
      t.datetime :last_sync_at
      t.text :last_error_safe
      t.timestamps
    end

    add_index :integration_accounts,
              %i[project_id provider repository_owner repository_name],
              unique: true,
              name: "index_integration_accounts_on_project_provider_repository"
    add_index :integration_accounts, :github_installation_id
    add_index :integration_accounts, %i[provider status]
  end
end
