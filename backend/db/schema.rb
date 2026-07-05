# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_07_05_103000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "audit_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "project_id", null: false
    t.string "actor_id", default: "system", null: false
    t.string "action", null: false
    t.string "target_type", null: false
    t.string "target_id", null: false
    t.string "summary"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "created_at"], name: "index_audit_logs_on_project_id_and_created_at"
    t.index ["project_id"], name: "index_audit_logs_on_project_id"
    t.index ["target_type", "target_id"], name: "index_audit_logs_on_target_type_and_target_id"
  end

  create_table "conversation_imports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "project_id", null: false
    t.string "source_type", default: "discord_dm_paste", null: false
    t.string "title", null: false
    t.text "raw_text", null: false
    t.text "redacted_text"
    t.jsonb "participants", default: [], null: false
    t.datetime "conversation_started_at"
    t.datetime "conversation_ended_at"
    t.boolean "consent_confirmed", default: false, null: false
    t.string "consent_confirmed_by"
    t.datetime "consent_confirmed_at"
    t.string "consent_statement_version", null: false
    t.string "status", default: "draft", null: false
    t.jsonb "safety_flags", default: [], null: false
    t.jsonb "blocked_reasons", default: [], null: false
    t.string "imported_by", default: "system", null: false
    t.datetime "last_scanned_at"
    t.datetime "approved_at"
    t.string "approved_by"
    t.datetime "retention_expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "raw_text_retention_expires_at"
    t.datetime "raw_text_purged_at"
    t.datetime "anonymized_at"
    t.index ["anonymized_at"], name: "index_conversation_imports_on_anonymized_at"
    t.index ["imported_by", "created_at"], name: "index_conversation_imports_on_imported_by_and_created_at"
    t.index ["project_id", "created_at"], name: "index_conversation_imports_on_project_id_and_created_at"
    t.index ["project_id", "status"], name: "index_conversation_imports_on_project_id_and_status"
    t.index ["project_id"], name: "index_conversation_imports_on_project_id"
    t.index ["raw_text_purged_at"], name: "index_conversation_imports_on_raw_text_purged_at"
    t.index ["raw_text_retention_expires_at"], name: "index_conversation_imports_on_raw_text_retention_expires_at"
    t.index ["retention_expires_at"], name: "index_conversation_imports_on_retention_expires_at"
  end

  create_table "conversation_summary_drafts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "conversation_import_id", null: false
    t.string "provider", default: "deterministic", null: false
    t.string "model"
    t.string "status", default: "draft", null: false
    t.text "summary", null: false
    t.jsonb "decisions", default: [], null: false
    t.jsonb "open_questions", default: [], null: false
    t.jsonb "action_items", default: [], null: false
    t.jsonb "issue_candidates", default: [], null: false
    t.jsonb "requirement_candidates", default: [], null: false
    t.jsonb "risks", default: [], null: false
    t.jsonb "participants", default: [], null: false
    t.jsonb "source_quotes", default: [], null: false
    t.decimal "confidence", precision: 4, scale: 3
    t.jsonb "validation_errors", default: [], null: false
    t.datetime "generated_at", null: false
    t.datetime "approved_at"
    t.string "approved_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "retention_expires_at"
    t.text "protected_payload", null: false
    t.index ["conversation_import_id", "created_at"], name: "index_conversation_summary_drafts_on_import_and_created"
    t.index ["conversation_import_id"], name: "index_conversation_summary_drafts_on_conversation_import_id"
    t.index ["retention_expires_at"], name: "index_conversation_summary_drafts_on_retention_expires_at"
    t.index ["status"], name: "index_conversation_summary_drafts_on_status"
  end

  create_table "github_connection_states", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "project_id", null: false
    t.string "repository_owner", null: false
    t.string "repository_name", null: false
    t.string "nonce_digest", null: false
    t.string "state_digest", null: false
    t.string "redirect_uri"
    t.datetime "expires_at", null: false
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["consumed_at"], name: "index_github_connection_states_on_consumed_at"
    t.index ["nonce_digest"], name: "index_github_connection_states_on_nonce_digest", unique: true
    t.index ["project_id", "expires_at"], name: "index_github_connection_states_on_project_id_and_expires_at"
    t.index ["project_id"], name: "index_github_connection_states_on_project_id"
    t.index ["state_digest"], name: "index_github_connection_states_on_state_digest", unique: true
  end

  create_table "github_issue_publish_attempts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "issue_draft_id", null: false
    t.uuid "project_id", null: false
    t.string "github_repository", null: false
    t.string "idempotency_digest", null: false
    t.string "status", default: "started", null: false
    t.integer "github_issue_number"
    t.string "github_issue_url"
    t.integer "github_issue_api_id"
    t.string "github_issue_node_id"
    t.string "safe_error_code"
    t.text "safe_error_detail"
    t.datetime "started_at", null: false
    t.datetime "github_created_at"
    t.datetime "completed_at"
    t.datetime "reconciled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "reconciliation_retry_count", default: 0, null: false
    t.datetime "next_reconciliation_retry_at"
    t.index ["github_issue_node_id"], name: "index_github_issue_publish_attempts_on_github_issue_node_id"
    t.index ["github_repository", "github_issue_number"], name: "idx_on_github_repository_github_issue_number_d3ec04d8f3"
    t.index ["issue_draft_id", "idempotency_digest"], name: "index_github_publish_attempts_on_draft_and_digest"
    t.index ["issue_draft_id"], name: "index_github_issue_publish_attempts_on_issue_draft_id"
    t.index ["project_id", "status"], name: "index_github_issue_publish_attempts_on_project_id_and_status"
    t.index ["project_id"], name: "index_github_issue_publish_attempts_on_project_id"
  end

  create_table "integration_accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "project_id", null: false
    t.string "provider", default: "github", null: false
    t.string "status", default: "not_connected", null: false
    t.string "external_account_id"
    t.string "repository_owner", null: false
    t.string "repository_name", null: false
    t.string "github_installation_id"
    t.string "github_account_login"
    t.string "github_account_type"
    t.jsonb "granted_permissions", default: {}, null: false
    t.datetime "last_sync_at"
    t.text "last_error_safe"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["github_installation_id"], name: "index_integration_accounts_on_github_installation_id"
    t.index ["project_id", "provider", "repository_owner", "repository_name"], name: "index_integration_accounts_on_project_provider_repository", unique: true
    t.index ["project_id"], name: "index_integration_accounts_on_project_id"
    t.index ["provider", "status"], name: "index_integration_accounts_on_provider_and_status"
  end

  create_table "issue_drafts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "requirement_id", null: false
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.jsonb "acceptance_criteria", default: [], null: false
    t.jsonb "labels", default: [], null: false
    t.integer "github_issue_number"
    t.string "github_issue_url"
    t.text "publish_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "publish_idempotency_key"
    t.string "github_repository"
    t.integer "github_issue_api_id"
    t.string "github_issue_node_id"
    t.datetime "last_publish_attempt_at"
    t.index ["github_issue_number"], name: "index_issue_drafts_on_github_issue_number"
    t.index ["github_issue_url"], name: "index_issue_drafts_on_github_issue_url", unique: true
    t.index ["publish_idempotency_key"], name: "index_issue_drafts_on_publish_idempotency_key", unique: true
    t.index ["requirement_id", "created_at"], name: "index_issue_drafts_on_requirement_id_and_created_at"
    t.index ["requirement_id"], name: "index_issue_drafts_on_requirement_id"
    t.index ["status"], name: "index_issue_drafts_on_status"
  end

  create_table "jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "project_id", null: false
    t.string "job_type", null: false
    t.string "status", default: "queued", null: false
    t.string "target_type", null: false
    t.string "target_id"
    t.integer "progress", default: 0, null: false
    t.string "error_code"
    t.text "error_message"
    t.text "safe_error_detail"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "status"], name: "index_jobs_on_project_id_and_status"
    t.index ["project_id"], name: "index_jobs_on_project_id"
    t.index ["target_type", "target_id"], name: "index_jobs_on_target_type_and_target_id"
  end

  create_table "meetings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "project_id", null: false
    t.string "title", null: false
    t.string "source_type", default: "manual", null: false
    t.date "meeting_date"
    t.jsonb "participants", default: [], null: false
    t.text "raw_text", null: false
    t.string "status", default: "draft", null: false
    t.jsonb "tags", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "created_at"], name: "index_meetings_on_project_id_and_created_at"
    t.index ["project_id"], name: "index_meetings_on_project_id"
    t.index ["status"], name: "index_meetings_on_status"
  end

  create_table "minutes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "meeting_id", null: false
    t.string "status", default: "generated", null: false
    t.text "summary", null: false
    t.jsonb "decisions", default: [], null: false
    t.jsonb "open_questions", default: [], null: false
    t.jsonb "action_items", default: [], null: false
    t.string "generated_by_model"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["meeting_id", "created_at"], name: "index_minutes_on_meeting_id_and_created_at"
    t.index ["meeting_id"], name: "index_minutes_on_meeting_id"
    t.index ["status"], name: "index_minutes_on_status"
  end

  create_table "open_api_drafts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "requirement_id", null: false
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.text "content", null: false
    t.jsonb "validation_errors", default: [], null: false
    t.string "generated_by_model"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["requirement_id", "created_at"], name: "index_open_api_drafts_on_requirement_id_and_created_at"
    t.index ["requirement_id"], name: "index_open_api_drafts_on_requirement_id"
    t.index ["status"], name: "index_open_api_drafts_on_status"
  end

  create_table "projects", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "status", default: "active", null: false
    t.string "github_repo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_projects_on_status"
  end

  create_table "requirements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "minutes_id", null: false
    t.string "status", default: "generated", null: false
    t.text "background", null: false
    t.text "goal", null: false
    t.jsonb "user_stories", default: [], null: false
    t.jsonb "functional_requirements", default: [], null: false
    t.jsonb "non_functional_requirements", default: [], null: false
    t.jsonb "acceptance_criteria", default: [], null: false
    t.jsonb "out_of_scope", default: [], null: false
    t.jsonb "open_questions", default: [], null: false
    t.jsonb "risks", default: [], null: false
    t.string "generated_by_model"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["minutes_id", "created_at"], name: "index_requirements_on_minutes_id_and_created_at"
    t.index ["minutes_id"], name: "index_requirements_on_minutes_id"
    t.index ["status"], name: "index_requirements_on_status"
  end

  create_table "reviews", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "target_type", null: false
    t.string "target_id", null: false
    t.string "status", default: "open", null: false
    t.string "reviewer_role", null: false
    t.jsonb "framework", default: [], null: false
    t.jsonb "positives", default: [], null: false
    t.jsonb "improvements", default: [], null: false
    t.jsonb "priority", default: [], null: false
    t.jsonb "next_actions", default: [], null: false
    t.jsonb "issue_numbers", default: [], null: false
    t.jsonb "accepted_risk"
    t.text "resolution_note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_reviews_on_status"
    t.index ["target_type", "target_id"], name: "index_reviews_on_target_type_and_target_id"
  end

  add_foreign_key "audit_logs", "projects"
  add_foreign_key "conversation_imports", "projects"
  add_foreign_key "conversation_summary_drafts", "conversation_imports"
  add_foreign_key "github_connection_states", "projects"
  add_foreign_key "github_issue_publish_attempts", "issue_drafts"
  add_foreign_key "github_issue_publish_attempts", "projects"
  add_foreign_key "integration_accounts", "projects"
  add_foreign_key "issue_drafts", "requirements"
  add_foreign_key "jobs", "projects"
  add_foreign_key "meetings", "projects"
  add_foreign_key "minutes", "meetings"
  add_foreign_key "open_api_drafts", "requirements"
  add_foreign_key "requirements", "minutes", column: "minutes_id"
end
