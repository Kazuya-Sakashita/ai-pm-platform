# Solid Queue Staging/Production Worker Smoke Runbook

## Purpose

AI PM Platform uses Solid Queue for production background jobs. This runbook defines how to prove that a staging or production-equivalent worker can start, heartbeat, load recurring tasks, execute scheduled jobs, and expose failure evidence without relying on GitHub App credentials.

This smoke is required before Issue #4 can treat the GitHub connection state cleanup and reconciliation retry queue as production-operable.

## Scope

- Solid Queue worker startup
- Queue database connectivity
- Worker heartbeat
- Recurring schedule loading
- `cleanup_expired_github_connection_states` scheduling
- Safe execution evidence for `GithubIntegration::ConnectionStateCleanupJob`
- Failed job and queue latency checks

Out of scope:

- Real GitHub App connect/publish/reconcile smoke
- GitHub webhook verification
- AI provider live calls
- Production incident response

## Preconditions

- GitHub Actions CI is green for the commit under smoke.
- Staging or production-equivalent environment has separate web and worker process definitions.
- `DATABASE_URL` points to the application database.
- `QUEUE_DATABASE_URL` points to the Solid Queue database prepared from `backend/db/queue_schema.rb`.
- `RAILS_ENV=production` or a staging environment using production-equivalent queue settings.
- `backend/config/recurring.yml` includes `cleanup_expired_github_connection_states`.
- Operators can inspect Rails logs and queue database tables.

Do not run this smoke against production until it has passed in staging or an isolated production-equivalent environment.

## Required Environment Variables

```sh
RAILS_ENV=production
DATABASE_URL=postgres://...
QUEUE_DATABASE_URL=postgres://...
RAILS_MASTER_KEY=...
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

### 4. Confirm Recurring Cleanup Task

Use a read-only query:

```sql
select key, class_name, command, schedule, queue_name
from solid_queue_recurring_tasks
where key = 'cleanup_expired_github_connection_states';
```

Expected:

- One row exists.
- `class_name` is `GithubIntegration::ConnectionStateCleanupJob`.
- `queue_name` is `default`.
- Schedule matches `every hour at minute 24`.

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

### 6. Failed Job Visibility

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

### 7. Queue Latency Snapshot

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

## Production-Specific Rules

- Do not create smoke `github_connection_states` in production without explicit release owner approval.
- Prefer observation-only production smoke:
  - worker heartbeat
  - recurring task exists
  - failed executions count
  - queue latency
  - Rails log confirms scheduled cleanup at the next minute 24
- If production cleanup execution is observed, record only counts and timestamps. Do not copy raw state, nonce digest, or state digest into documents.
- If `QUEUE_DATABASE_URL` is missing or points to the wrong database, stop the smoke and fail the release gate.

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
- failed job count before/after
- queue latency snapshot
- pass/fail conclusion
- Issue number

Never save secrets, raw state, nonce, state digest, database URLs, private keys, or full external API responses.

## Completion Criteria

Staging worker smoke is complete when:

- worker starts independently from web
- heartbeat is visible
- recurring task is loaded
- cleanup job executes or is safely observed
- failed job count is reviewed
- evidence review is saved under `docs/review/`

Production worker smoke is complete when:

- production worker heartbeat is visible
- recurring task is loaded
- observation-only checks pass
- next scheduled cleanup is observed without secret exposure
- evidence review is saved under `docs/review/`
