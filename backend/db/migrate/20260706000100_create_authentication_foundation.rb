class CreateAuthenticationFoundation < ActiveRecord::Migration[7.1]
  def change
    create_table :auth_actors, id: :uuid do |t|
      t.string :subject, null: false
      t.string :status, null: false, default: "active"
      t.integer :session_version, null: false, default: 1
      t.datetime :sessions_revoked_at
      t.string :display_name
      t.string :email_digest

      t.timestamps
    end

    add_index :auth_actors, :subject, unique: true
    add_index :auth_actors, :status

    create_table :auth_sessions, id: :uuid do |t|
      t.string :sid, null: false
      t.string :actor_subject, null: false
      t.string :status, null: false, default: "active"
      t.integer :session_version, null: false, default: 1
      t.datetime :issued_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :last_seen_at
      t.datetime :revoked_at
      t.string :revoked_by_actor_id
      t.string :revocation_reason
      t.string :ip_hash
      t.string :user_agent_hash

      t.timestamps
    end

    add_index :auth_sessions, :sid, unique: true
    add_index :auth_sessions, [:actor_subject, :status]
    add_index :auth_sessions, :expires_at
    add_index :auth_sessions, :revoked_at
    add_foreign_key :auth_sessions, :auth_actors, column: :actor_subject, primary_key: :subject

    create_table :auth_token_revocations, id: :uuid do |t|
      t.string :jti_digest, null: false
      t.string :sid
      t.string :actor_subject
      t.datetime :expires_at, null: false
      t.string :reason, null: false, default: "incident"
      t.string :created_by_actor_id

      t.timestamps
    end

    add_index :auth_token_revocations, :jti_digest, unique: true
    add_index :auth_token_revocations, [:sid, :expires_at]
    add_index :auth_token_revocations, [:actor_subject, :expires_at]
    add_index :auth_token_revocations, :expires_at

    create_table :security_events, id: :uuid do |t|
      t.references :project, foreign_key: true, type: :uuid
      t.string :actor_id, null: false, default: "system"
      t.string :action, null: false
      t.string :target_type, null: false
      t.string :target_id, null: false
      t.string :severity, null: false, default: "info"
      t.string :summary
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :security_events, [:action, :created_at]
    add_index :security_events, [:actor_id, :created_at]
    add_index :security_events, [:project_id, :created_at]
    add_index :security_events, [:target_type, :target_id]
    add_index :security_events, :severity
  end
end
