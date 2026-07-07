# Solid Queue Staging/Production Worker Smoke Runbook

## Purpose

AI PM Platform uses Solid Queue for production background jobs. This runbook defines how to prove that a staging or production-equivalent worker can start, heartbeat, load recurring tasks, execute scheduled jobs, and expose failure evidence without relying on GitHub App credentials.

This smoke is required before Issue #4 can treat the GitHub connection state cleanup and reconciliation retry queue as production-operable, and before Issue #29 can treat Discord DM retention/anonymization as production-operable.

## Scope

- Solid Queue worker startup
- Queue database connectivity
- Worker heartbeat
- Recurring schedule loading
- `cleanup_expired_github_connection_states` scheduling
- `enforce_conversation_import_retention` scheduling
- Safe execution evidence for `GithubIntegration::ConnectionStateCleanupJob`
- Safe execution evidence for `ConversationImportRetentionJob`
- Restore-time retention/anonymization replay guidance
- Failed job and queue latency checks
- Failed job retry/discard operation evidence

Out of scope:

- Real GitHub App connect/publish/reconcile smoke
- GitHub webhook verification
- AI provider live calls
- Production incident response
- Real user DM data inspection
- Bulk failed job retry/discard
- Creating intentional production failures for smoke testing

## Preconditions

- GitHub Actions CI is green for the commit under smoke.
- Staging or production-equivalent environment has separate web and worker process definitions.
- `DATABASE_URL` points to the application database.
- `QUEUE_DATABASE_URL` points to the Solid Queue database prepared from `backend/db/queue_schema.rb`.
- `RAILS_ENV=production` or a staging environment using production-equivalent queue settings.
- `backend/config/recurring.yml` includes `cleanup_expired_github_connection_states`.
- `backend/config/recurring.yml` includes `enforce_conversation_import_retention`.
- Production-equivalent environments set Active Record Encryption keys without exposing their values.
- Operators can inspect Rails logs and queue database tables.

Do not run this smoke against production until it has passed in staging or an isolated production-equivalent environment.

## Required Environment Variables

```sh
RAILS_ENV=production
DATABASE_URL=postgres://...
QUEUE_DATABASE_URL=postgres://...
RAILS_MASTER_KEY=...
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=...
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=...
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=...
```

Optional:

```sh
RAILS_LOG_LEVEL=info
JOB_THREADS=...
JOB_CONCURRENCY=...
```

## Smoke Steps

### 1. Confirm Queue Configuration

Run from the backend release directory:

```sh
bundle exec ruby bin/rails runner 'puts Rails.application.config.active_job.queue_adapter'
```

Expected:

- Output is `solid_queue` in production-equivalent mode.
- Application boot does not raise `QUEUE_DATABASE_URL is required`.

Confirm recurring task config:

```sh
bundle exec ruby bin/rails runner 'puts SolidQueue::RecurringTask.count'
```

Expected:

- Command succeeds after worker/scheduler has loaded recurring tasks.
- If count is `0` before worker startup, continue to worker startup and verify again.

### 2. Start Worker

Start the worker process:

```sh
bundle exec bin/jobs
```

Expected logs:

- Supervisor started
- Dispatcher started
- Worker started
- Scheduler started

Do not run this inside the web process. The worker must be independently restartable.

### 3. Confirm Worker Heartbeat

Use a read-only query against the queue database:

```sql
select kind, name, last_heartbeat_at
from solid_queue_processes
order by last_heartbeat_at desc;
```

Expected:

- At least one `Worker` process has a recent `last_heartbeat_at`.
- `Supervisor`, `Dispatcher`, and `Scheduler` are visible, depending on supervisor mode.
- Heartbeat is recent enough for the deployment SLA, normally within 60 seconds.

### 4. Confirm Recurring Tasks

Use a read-only query:

```sql
select key, class_name, command, schedule, queue_name
from solid_queue_recurring_tasks
where key in (
  'cleanup_expired_github_connection_states',
  'enforce_conversation_import_retention'
)
order by key;
```

Expected:

- Two rows exist.
- `cleanup_expired_github_connection_states` class is `GithubIntegration::ConnectionStateCleanupJob`.
- `enforce_conversation_import_retention` class is `ConversationImportRetentionJob`.
- `queue_name` is `default`.
- Cleanup schedule matches `every hour at minute 24`.
- Retention schedule matches `every hour at minute 36`.

### 5. Safe Cleanup Execution Smoke

In staging only, create controlled test data with an expired state older than the retention window and one active state. Do not do this in production unless approved by the release owner.

Recommended staging runner:

```sh
bundle exec ruby bin/rails runner '
project = Project.first || Project.create!(name: "Solid Queue Smoke")
old_state = project.github_connection_states.create!(
  repository_owner: "Smoke",
  repository_name: "cleanup-old",
  nonce_digest: SecureRandom.hex(32),
  state_digest: SecureRandom.hex(32),
  expires_at: 26.hours.ago
)
active_state = project.github_connection_states.create!(
  repository_owner: "Smoke",
  repository_name: "cleanup-active",
  nonce_digest: SecureRandom.hex(32),
  state_digest: SecureRandom.hex(32),
  expires_at: 10.minutes.from_now
)
GithubIntegration::ConnectionStateCleanupJob.perform_later
puts({ old_state_id: old_state.id, active_state_id: active_state.id }.to_json)
'
```

Expected:

- Job is enqueued to Solid Queue.
- Worker executes the job.
- Old expired state is deleted.
- Active state remains.
- Rails log includes `event=github_connection_state_cleanup` or JSON-equivalent structured log with `deleted_count`.

Verification query:

```sql
select repository_owner, repository_name, expires_at, consumed_at
from github_connection_states
where repository_owner = 'Smoke'
order by created_at desc;
```

Expected:

- `cleanup-old` is absent after worker execution.
- `cleanup-active` remains until it expires and passes retention.

### 6. Conversation Import Retention Smoke

In staging only, create controlled DM import records that contain artificial smoke text. Do not use real user DM data. Do not run this data creation step in production.

Recommended staging runner:

```sh
bundle exec ruby bin/rails runner '
project = Project.first || Project.create!(name: "Solid Queue Retention Smoke")
raw_expired = project.conversation_imports.create!(
  title: "Retention Smoke Raw Purge",
  raw_text: "retention-smoke-raw-text-to-purge",
  redacted_text: "retention-smoke-redacted-text-to-keep",
  consent_confirmed: true,
  consent_statement_version: "retention-smoke-v1",
  status: "ready_for_ai",
  raw_text_retention_expires_at: 1.hour.ago,
  retention_expires_at: 30.days.from_now
)
full_expired = project.conversation_imports.create!(
  title: "Retention Smoke Full Anonymize",
  raw_text: "retention-smoke-raw-text-to-anonymize",
  redacted_text: "retention-smoke-redacted-text-to-anonymize",
  participants: ["Smoke User"],
  consent_confirmed: true,
  consent_statement_version: "retention-smoke-v1",
  status: "summary_draft",
  raw_text_retention_expires_at: 2.hours.ago,
  retention_expires_at: 1.hour.ago
)
full_expired.conversation_summary_drafts.create!(
  summary: "retention smoke summary",
  confidence: 0.8
)
ConversationImportRetentionJob.perform_later
puts({ raw_expired_id: raw_expired.id, full_expired_id: full_expired.id }.to_json)
'
```

Expected:

- Job is enqueued to Solid Queue.
- Worker executes `ConversationImportRetentionJob`.
- `raw_expired` has `raw_text_purged_at` set and remains non-anonymized.
- `full_expired` has `anonymized_at` set and related summary draft is anonymized.
- AuditLog contains `conversation_import.raw_text_purged` and `conversation_import.anonymized` safe metadata.
- Rails log includes `event=conversation_import_retention.completed` or JSON-equivalent structured log with counts only.

Verification runner. Replace the IDs with the values printed by the staging runner. Do not print raw text.

```sh
RETENTION_SMOKE_RAW_ID=... RETENTION_SMOKE_FULL_ID=... bundle exec ruby bin/rails runner '
ids = [ENV.fetch("RETENTION_SMOKE_RAW_ID"), ENV.fetch("RETENTION_SMOKE_FULL_ID")]
imports = ConversationImport.where(id: ids).order(:id).map do |conversation_import|
  {
    id: conversation_import.id,
    title: conversation_import.title,
    status: conversation_import.status,
    raw_text_purged: conversation_import.raw_text_purged_at.present?,
    anonymized: conversation_import.anonymized_at.present?,
    summary_draft_count: conversation_import.conversation_summary_drafts.count
  }
end
audit_actions = AuditLog
  .where(action: ["conversation_import.raw_text_purged", "conversation_import.anonymized"])
  .order(created_at: :desc)
  .limit(5)
  .pluck(:action, :metadata)
puts({ imports: imports, audit_actions: audit_actions }.to_json)
'
```

Expected:

- Output contains no raw DM body.
- Raw purge record has `raw_text_purged: true` and `anonymized: false`.
- Full anonymization record has `anonymized: true`.
- Audit metadata includes counts/reasons only, not DM body.

### 7. Queue Health API/UI Check

Use the application API or Frontend operations panel after the worker smoke.

API:

```sh
curl -s "$APP_BASE_URL/api/v1/operations/queue-health"
```

Frontend:

- Open the workspace.
- Go to the `運用監視` panel.
- Click manual refresh.

Expected:

- Queue health status is `healthy` or an explicitly explained `degraded`.
- Worker count is greater than zero in staging/production-equivalent environments.
- Stale worker count is zero.
- Failed execution count does not increase during smoke.
- Recurring task count includes both cleanup and retention tasks.
- Failed job samples show only safe queue/class/time fields.
- No raw job arguments, DM body, database URL, state digest, or encryption key is visible.

### 8. Restore-Time Retention Replay

After any database restore that can contain DM import data, run retention/anonymization before returning public traffic.

Required restore sequence:

1. Restore database into an isolated environment.
2. Confirm Active Record Encryption keys are available only to approved operators.
3. Run migrations to the release schema.
4. Start a worker or run the job manually in maintenance mode:

```sh
bundle exec ruby bin/rails runner 'ConversationImportRetentionJob.perform_now'
```

5. Reapply any manual anonymization/deletion events that happened after the backup timestamp.
6. Check queue health and failed executions.
7. Only then allow public traffic.

Expected:

- Expired raw text is purged before users can access restored data.
- Expired imports and summary drafts are anonymized before users can access restored data.
- Evidence contains counts, timestamps, and job status only.

### 9. Failed Job Visibility

Use a read-only query:

```sql
select count(*) as failed_count
from solid_queue_failed_executions;
```

Expected:

- Failed count does not increase during smoke.

If it increases:

1. Capture error class and message from Solid Queue failure detail.
2. Capture Rails log around the failed execution.
3. Do not discard or retry the job until the failure is reviewed.

### 10. Failed Job Retry/Discard Operation Smoke

This step verifies the operator-facing failed job operation path added after the first Queue health MVP.

Staging rule:

- Use only a staging failed execution that was created by an approved smoke scenario or a known safe test job.
- Do not use a job that can publish external GitHub Issues, send notifications, call an AI provider, or mutate real user data unless the release owner explicitly approves it.
- If no safe failed execution exists, record the step as `blocked` in the evidence template. Do not fabricate queue database rows by hand.

Production rule:

- Production is observation-only by default.
- Do not retry or discard a production failed job during release smoke unless all of the following are true:
  - incident commander or release owner approval is recorded
  - affected Project is identified
  - operator is project admin or owner
  - reason template is selected
  - side-effect risk has been reviewed
  - AuditLog can be inspected after the operation
- If these conditions are not met, record `not executed` with the reason.

Recommended staging API check:

```sh
curl -s "$APP_BASE_URL/api/v1/operations/queue-health?project_id=$PROJECT_ID"
```

Select one failed job sample from the response. Record only:

- `failed_job_id`
- `job_id`
- `queue_name`
- `class_name`
- `active_job_id` if present
- `failed_at`
- `operations.retryable`
- `operations.discardable`
- available `reason_templates`

Do not record raw error, backtrace, serialized job arguments, database URLs, tokens, webhook payloads, DM body, or AI prompt content.

Retry smoke request:

```sh
curl -s -X POST "$APP_BASE_URL/api/v1/operations/failed-jobs/$FAILED_JOB_ID/retry?project_id=$PROJECT_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPERATOR_TOKEN" \
  --data '{"reason_template":"operator_confirmed_safe_retry"}'
```

Discard smoke request:

```sh
curl -s -X POST "$APP_BASE_URL/api/v1/operations/failed-jobs/$FAILED_JOB_ID/discard?project_id=$PROJECT_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPERATOR_TOKEN" \
  --data '{"reason_template":"manually_resolved"}'
```

Use either retry or discard for a given failed job. Do not run both on the same failed execution.

Expected:

- API returns `200` with safe fields only.
- Operation response contains `failed_job_id`, `job_id`, `action`, `reason_template`, and `operated_at`.
- AuditLog contains `operations.failed_job_retried` or `operations.failed_job_discarded`.
- AuditLog metadata contains operator, reason template, queue/class, and IDs only.
- Queue health is refreshed after the operation.
- The operated failed job is no longer present as an actionable failed job sample.
- No raw exception, backtrace, job arguments, secret, token, database URL, DM body, or AI prompt is visible.

If the operation fails:

- Record the safe API error code.
- Capture only safe metadata and timestamps.
- Do not retry again until the failure is reviewed.
- Do not manually edit Solid Queue tables as a workaround.

Save this step using `docs/review/20260707_failed_job_worker_smoke_evidence_template.md`.

### 11. Queue Latency Snapshot

Use a read-only query:

```sql
select queue_name, min(created_at) as oldest_unfinished
from solid_queue_jobs
where finished_at is null
group by queue_name
order by oldest_unfinished asc;
```

Expected:

- No unexpectedly old unfinished jobs.
- `github_reconciliation` and `default` queues are not stuck.
- Retention work does not leave unexpectedly old unfinished `default` jobs.

## Production-Specific Rules

- Do not create smoke `github_connection_states` in production without explicit release owner approval.
- Do not create smoke `conversation_imports` in production.
- Prefer observation-only production smoke:
  - worker heartbeat
  - recurring task exists
  - failed executions count
  - queue latency
  - failed job operation availability from Queue health
  - Rails log confirms scheduled cleanup at the next minute 24
  - Rails log confirms scheduled retention at the next minute 36
- Production retry/discard is forbidden during release smoke unless release owner approval, Project ownership, reason template, side-effect review, and AuditLog inspection are all recorded.
- If production cleanup or retention execution is observed, record only counts and timestamps. Do not copy raw state, nonce digest, state digest, DM body, or encryption key into documents.
- If production retry/discard is executed under approval, record only safe operation fields and never save raw exception, backtrace, serialized arguments, tokens, database URLs, DM body, or AI prompt content.
- If `QUEUE_DATABASE_URL` is missing or points to the wrong database, stop the smoke and fail the release gate.
- If Active Record Encryption keys are missing, stop the smoke and fail the release gate.
- Retention/anonymization is not meaningfully reversible. If unexpected anonymization occurs, stop the worker, disable DM import, preserve logs without body content, and follow backup restore policy from ADR-0013.

## Evidence To Save

Save evidence in `docs/review/YYYYMMDD_solid_queue_worker_smoke_review.md`.

Required fields:

- evaluation datetime
- evaluator
- environment name
- commit SHA
- worker process command
- `QUEUE_DATABASE_URL` presence confirmed without exposing the value
- worker heartbeat timestamp
- recurring task row observed
- cleanup execution result or observation-only reason
- retention task row observed
- retention execution result or observation-only reason
- queue health API/UI result
- failed job count before/after
- failed job operation status: `executed`, `not executed`, or `blocked`
- failed job operation target safe fields
- reason template
- operator actor ID
- AuditLog action and safe metadata confirmation
- Queue health result after retry/discard
- queue latency snapshot
- restore-time retention replay status or not-applicable reason
- pass/fail conclusion
- Issue number

Never save secrets, raw state, nonce, state digest, database URLs, private keys, or full external API responses.

## Completion Criteria

Staging worker smoke is complete when:

- worker starts independently from web
- heartbeat is visible
- cleanup and retention recurring tasks are loaded
- cleanup job executes or is safely observed
- retention job executes or is safely observed
- Queue health API/UI confirms worker and failed job status without sensitive fields
- failed job count is reviewed
- failed job retry/discard operation is executed in staging with approved safe target or marked blocked with owner and next execution date
- failed job operation evidence template is saved without sensitive fields
- evidence review is saved under `docs/review/`

Production worker smoke is complete when:

- production worker heartbeat is visible
- cleanup and retention recurring tasks are loaded
- observation-only checks pass
- failed job retry/discard is either observation-only deferred or executed under explicit release owner approval
- next scheduled cleanup is observed without secret exposure
- next scheduled retention is observed without DM body exposure
- restore-time retention replay rule is acknowledged in the release review
- evidence review is saved under `docs/review/`
