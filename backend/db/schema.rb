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

ActiveRecord::Schema[7.1].define(version: 2026_07_07_203500) do
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

  create_table "auth_actors", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "subject", null: false
    t.string "status", default: "active", null: false
    t.integer "session_version", default: 1, null: false
    t.datetime "sessions_revoked_at"
    t.string "display_name"
    t.string "email_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_auth_actors_on_status"
    t.index ["subject"], name: "index_auth_actors_on_subject", unique: true
  end

  create_table "auth_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "sid", null: false
    t.string "actor_subject", null: false
    t.string "status", default: "active", null: false
    t.integer "session_version", default: 1, null: false
    t.datetime "issued_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "last_seen_at"
    t.datetime "revoked_at"
    t.string "revoked_by_actor_id"
    t.string "revocation_reason"
    t.string "ip_hash"
    t.string "user_agent_hash"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_subject", "status"], name: "index_auth_sessions_on_actor_subject_and_status"
    t.index ["expires_at"], name: "index_auth_sessions_on_expires_at"
    t.index ["revoked_at"], name: "index_auth_sessions_on_revoked_at"
    t.index ["sid"], name: "index_auth_sessions_on_sid", unique: true
  end

  create_table "auth_token_revocations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "jti_digest", null: false
    t.string "sid"
    t.string "actor_subject"
    t.datetime "expires_at", null: false
    t.string "reason", default: "incident", null: false
    t.string "created_by_actor_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_subject", "expires_at"], name: "index_auth_token_revocations_on_actor_subject_and_expires_at"
    t.index ["expires_at"], name: "index_auth_token_revocations_on_expires_at"
    t.index ["jti_digest"], name: "index_auth_token_revocations_on_jti_digest", unique: true
    t.index ["sid", "expires_at"], name: "index_auth_token_revocations_on_sid_and_expires_at"
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

  create_table "failed_job_discard_approvals", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "project_id", null: false
    t.string "failed_job_id", null: false
    t.string "solid_queue_job_id", null: false
    t.uuid "product_job_id"
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.string "reason_template", null: false
    t.boolean "discard_safety_confirmed", default: false, null: false
    t.string "status", default: "pending", null: false
    t.string "requested_by_actor_id", null: false
    t.string "requested_by_role"
    t.string "approved_by_actor_id"
    t.string "approved_by_role"
    t.string "rejected_by_actor_id"
    t.string "rejected_by_role"
    t.string "consumed_by_actor_id"
    t.string "consumed_by_role"
    t.text "approval_note"
    t.text "rejection_reason"
    t.datetime "expires_at", null: false
    t.datetime "approved_at"
    t.datetime "rejected_at"
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_actor_id"], name: "idx_failed_job_discard_approvals_approver"
    t.index ["project_id", "expires_at"], name: "idx_failed_job_discard_approvals_expiry"
    t.index ["project_id", "failed_job_id", "reason_template"], name: "idx_failed_job_discard_approvals_active_unique", unique: true, where: "((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('approved'::character varying)::text]))"
    t.index ["project_id", "failed_job_id", "status"], name: "idx_failed_job_discard_approvals_lookup"
    t.index ["project_id"], name: "index_failed_job_discard_approvals_on_project_id"
    t.index ["requested_by_actor_id"], name: "idx_failed_job_discard_approvals_requester"
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

  create_table "github_webhook_deliveries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "delivery_digest", null: false
    t.string "event", null: false
    t.string "status", default: "processing", null: false
    t.string "github_installation_id"
    t.string "repository_full_name"
    t.string "safe_error_code"
    t.datetime "processed_at"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["delivery_digest"], name: "index_github_webhook_deliveries_on_delivery_digest", unique: true
    t.index ["event", "status"], name: "index_github_webhook_deliveries_on_event_and_status"
    t.index ["github_installation_id"], name: "index_github_webhook_deliveries_on_github_installation_id"
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

  create_table "job_queue_mappings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "project_id", null: false
    t.uuid "job_id", null: false
    t.string "provider", default: "solid_queue", null: false
    t.bigint "solid_queue_job_id", null: false
    t.string "active_job_id"
    t.string "queue_name"
    t.string "job_class_name"
    t.datetime "scheduled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_job_queue_mappings_on_active_job_id"
    t.index ["job_id", "created_at"], name: "index_job_queue_mappings_on_job_id_and_created_at"
    t.index ["job_id"], name: "index_job_queue_mappings_on_job_id"
    t.index ["project_id", "created_at"], name: "index_job_queue_mappings_on_project_id_and_created_at"
    t.index ["project_id"], name: "index_job_queue_mappings_on_project_id"
    t.index ["provider", "solid_queue_job_id"], name: "index_job_queue_mappings_on_provider_and_solid_queue_job_id", unique: true
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

  create_table "project_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "project_id", null: false
    t.string "actor_id", null: false
    t.string "role", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id", "status"], name: "index_project_memberships_on_actor_id_and_status"
    t.index ["project_id", "actor_id"], name: "index_project_memberships_on_project_id_and_actor_id", unique: true
    t.index ["project_id", "role"], name: "index_project_memberships_on_project_id_and_role"
    t.index ["project_id"], name: "index_project_memberships_on_project_id"
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
    t.datetime "approved_at"
    t.string "approved_by"
    t.text "approval_note"
    t.index ["approved_at"], name: "index_requirements_on_approved_at"
    t.index ["approved_by", "approved_at"], name: "index_requirements_on_approved_by_and_approved_at"
    t.index ["minutes_id", "created_at"], name: "index_requirements_on_minutes_id_and_created_at"
    t.index ["minutes_id"], name: "index_requirements_on_minutes_id"
    t.index ["status"], name: "index_requirements_on_status"
  end

  create_table "review_state_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "review_id", null: false
    t.uuid "project_id", null: false
    t.string "target_type", null: false
    t.string "target_id", null: false
    t.string "event_type", null: false
    t.string "from_status"
    t.string "to_status", null: false
    t.string "actor_id", default: "system", null: false
    t.string "reason_code"
    t.string "reason_summary"
    t.jsonb "issue_numbers", default: [], null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_type", "occurred_at"], name: "index_review_state_events_on_event_type_and_occurred_at"
    t.index ["project_id", "occurred_at"], name: "index_review_state_events_on_project_id_and_occurred_at"
    t.index ["project_id"], name: "index_review_state_events_on_project_id"
    t.index ["review_id", "occurred_at"], name: "index_review_state_events_on_review_id_and_occurred_at"
    t.index ["review_id"], name: "index_review_state_events_on_review_id"
    t.index ["target_type", "target_id", "occurred_at"], name: "idx_on_target_type_target_id_occurred_at_ceaa381147"
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

  create_table "security_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "project_id"
    t.string "actor_id", default: "system", null: false
    t.string "action", null: false
    t.string "target_type", null: false
    t.string "target_id", null: false
    t.string "severity", default: "info", null: false
    t.string "summary"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action", "created_at"], name: "index_security_events_on_action_and_created_at"
    t.index ["actor_id", "created_at"], name: "index_security_events_on_actor_id_and_created_at"
    t.index ["project_id", "created_at"], name: "index_security_events_on_project_id_and_created_at"
    t.index ["project_id"], name: "index_security_events_on_project_id"
    t.index ["severity"], name: "index_security_events_on_severity"
    t.index ["target_type", "target_id"], name: "index_security_events_on_target_type_and_target_id"
  end

  add_foreign_key "audit_logs", "projects"
  add_foreign_key "auth_sessions", "auth_actors", column: "actor_subject", primary_key: "subject"
  add_foreign_key "conversation_imports", "projects"
  add_foreign_key "conversation_summary_drafts", "conversation_imports"
  add_foreign_key "failed_job_discard_approvals", "projects"
  add_foreign_key "github_connection_states", "projects"
  add_foreign_key "github_issue_publish_attempts", "issue_drafts"
  add_foreign_key "github_issue_publish_attempts", "projects"
  add_foreign_key "integration_accounts", "projects"
  add_foreign_key "issue_drafts", "requirements"
  add_foreign_key "job_queue_mappings", "jobs"
  add_foreign_key "job_queue_mappings", "projects"
  add_foreign_key "jobs", "projects"
  add_foreign_key "meetings", "projects"
  add_foreign_key "minutes", "meetings"
  add_foreign_key "open_api_drafts", "requirements"
  add_foreign_key "project_memberships", "projects"
  add_foreign_key "requirements", "minutes", column: "minutes_id"
  add_foreign_key "review_state_events", "projects"
  add_foreign_key "review_state_events", "reviews"
  add_foreign_key "security_events", "projects"
end
