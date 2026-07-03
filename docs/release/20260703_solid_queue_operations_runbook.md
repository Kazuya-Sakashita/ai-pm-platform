# Solid Queue Operations Runbook

## Purpose

Production background jobs must survive web process restarts and be observable by operators. This runbook defines the minimum operation policy for Solid Queue in AI PM Platform.

## Scope

- GitHub reconciliation retry
- Future AI generation jobs
- Future AI review jobs
- Future integration ingestion jobs

## Environment

Required:

- `DATABASE_URL`
- `RAILS_ENV=production`

Optional:

- `QUEUE_DATABASE_URL`
- `JOB_THREADS`
- `JOB_CONCURRENCY`
- `RAILS_LOG_LEVEL`

If `QUEUE_DATABASE_URL` is not set, the queue database uses `DATABASE_URL`. This is acceptable for a small beta, but production should prefer a separated queue database when traffic grows.

## Setup

Prepare the application and queue database:

```sh
bundle exec rails db:prepare
```

Start the web process separately from the worker process.

Start Solid Queue worker:

```sh
bundle exec bin/jobs
```

For constrained single-process environments, async supervisor mode can be used only as a temporary beta fallback:

```sh
SOLID_QUEUE_SUPERVISOR_MODE=async bundle exec bin/jobs
```

## Queues

Configured queues:

- `github_reconciliation`
- `ai_generation`
- `ai_review`
- `default`

Queue order is explicit. Avoid wildcard queue polling in production unless an operator intentionally changes the runbook and review result.

## Monitoring

Minimum checks:

- worker process is alive
- `solid_queue_processes.last_heartbeat_at` is recent
- `solid_queue_failed_executions` count is not increasing
- oldest unfinished `solid_queue_jobs.created_at` is within the expected SLA
- application `jobs.status = failed` is reviewed
- queue database connection usage stays below capacity

Suggested SQL checks:

```sql
select kind, name, last_heartbeat_at
from solid_queue_processes
order by last_heartbeat_at desc;
```

```sql
select count(*) as failed_count
from solid_queue_failed_executions;
```

```sql
select queue_name, min(created_at) as oldest_unfinished
from solid_queue_jobs
where finished_at is null
group by queue_name;
```

## Failure Response

When GitHub reconciliation retry fails:

1. Check the application `jobs` row for `safe_error_detail`.
2. Check `audit_logs` for `issue_draft.github_publish_reconciliation_retry_failed`.
3. Confirm whether the failure is rate limit, permission, missing repository, or transient network.
4. Do not create another GitHub Issue manually until marker search or reviewer confirmation is complete.
5. Record the operator decision in the related Issue or Review document.

When worker heartbeat is stale:

1. Confirm the worker process is running.
2. Restart `bundle exec bin/jobs` if the process is stopped.
3. Check database connectivity and connection pool saturation.
4. Review failed executions before discarding or retrying jobs.

## Shutdown

Use graceful termination for deploys:

```sh
kill -TERM <worker-pid>
```

Avoid `kill -9` unless the process is unrecoverable. A forced kill can turn in-flight jobs into failed executions that need operator review.

## Release Checklist

- `bundle exec rails db:prepare` completed
- worker process command is configured in deployment
- queue database is reachable
- worker heartbeat is visible
- a scheduled GitHub reconciliation retry can be enqueued
- failed job path is visible in application `jobs` and `audit_logs`
- GitHub Actions CI passed
