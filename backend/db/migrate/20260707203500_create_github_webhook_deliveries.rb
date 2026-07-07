class CreateGithubWebhookDeliveries < ActiveRecord::Migration[7.1]
  def change
    create_table :github_webhook_deliveries, id: :uuid do |t|
      t.string :delivery_digest, null: false
      t.string :event, null: false
      t.string :status, null: false, default: "processing"
      t.string :github_installation_id
      t.string :repository_full_name
      t.string :safe_error_code
      t.datetime :processed_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :github_webhook_deliveries, :delivery_digest, unique: true
    add_index :github_webhook_deliveries, %i[event status]
    add_index :github_webhook_deliveries, :github_installation_id
  end
end
