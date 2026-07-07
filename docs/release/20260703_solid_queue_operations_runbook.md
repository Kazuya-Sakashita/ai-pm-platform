# Solid Queue Operations Runbook

## Purpose

Production background jobs must survive web process restarts and be observable by operators. This runbook defines the minimum operation policy for Solid Queue in AI PM Platform.

## Scope

- GitHub reconciliation retry
- Conversation import retention/anonymization
- Future AI generation jobs
- Future AI review jobs
- Future integration ingestion jobs

## Environment

Required:

- `DATABASE_URL`
- `QUEUE_DATABASE_URL`
- `RAILS_ENV=production`

Optional:

- `JOB_THREADS`
- `JOB_CONCURRENCY`
- `RAILS_LOG_LEVEL`

`QUEUE_DATABASE_URL` is required. It must point to a queue database prepared from `db/queue_schema.rb`. Do not point it at an existing primary database unless the Solid Queue tables have already been loaded there intentionally.

## Setup

Prepare the application and queue database:

```sh
export RAILS_ENV=production
export DATABASE_URL=postgres://...
export QUEUE_DATABASE_URL=postgres://...
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

Current recurring tasks:

- `cleanup_expired_github_connection_states`: `GithubIntegration::ConnectionStateCleanupJob`, every hour at minute 24
- `enforce_conversation_import_retention`: `ConversationImportRetentionJob`, every hour at minute 36

## Monitoring

Minimum checks:

- worker process is alive
- `solid_queue_processes.last_heartbeat_at` is recent
- `solid_queue_failed_executions` count is not increasing
- oldest unfinished `solid_queue_jobs.created_at` is within the expected SLA
- application `jobs.status = failed` is reviewed
- Queue health failed job samples expose only safe operation fields
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

When failed job retry/discard is considered:

1. Prefer the application Queue health panel or documented API path over Rails console.
2. Confirm the operator is project admin or owner for the target Project.
3. Select a reason template. Do not write free-form incident details into the operation payload.
4. Review side-effect risk before retrying jobs that can publish GitHub Issues, call external APIs, send notifications, or mutate user data.
5. For discard, confirm the job is manually resolved or unsafe to retry. 本番では実行前に二人承認またはrelease owner承認を記録する。
6. After operation, inspect `audit_logs` for `operations.failed_job_retried` or `operations.failed_job_discarded`.
7. Refresh Queue health and record only safe IDs, queue/class, reason template, operator, AuditLog action, and timestamps.
8. Never save raw exception, backtrace, serialized job arguments, tokens, database URLs, DM body, or AI prompt content in the incident note.

failed job release gateを評価する場合:

1. release前にQueue healthの `failed_job_release_gate.status` を確認する。
2. `blocked` はhard stopとして扱う。blocking checkが解消されるか、release ownerのリスク判断が文書化されるまでreleaseしない。
3. `warning` はrelease ownerレビュー必須として扱う。理由、owner、次回確認時刻、緩和策を記録する。
4. `pass` はsmoke証跡、AuditLog証跡、safe metadata確認が保存されている場合のみ許容する。
5. `boundary_rejected_count >= 1`、Queue health取得不能、queue DB欠落、Solid Queue schema欠落はhard stopとする。
6. `failed_execution_count >= 5`、24時間retry 10件以上、24時間discard 5件以上、stale worker heartbeat、古い未完了job、mapping fallback sampleはwarning review対象にする。
7. `notification_required` がtrueの場合、operationsチャンネルまたはIssueコメントへsafe fieldsのみを記録する。例外詳細、スタックトレース、直列化job引数、認証情報、DB接続情報、DM本文、AI入力全文は含めない。
8. 通知に失敗した場合は、AuditLogまたはrelease evidenceへfallback対応を記録し、release ownerの手動確認を必須にする。

When conversation import retention fails:

1. Check `solid_queue_failed_executions` and application logs for `ConversationImportRetentionJob`.
2. Record only job class, queue, timestamp, and safe error class/message.
3. Do not copy DM body, encrypted ciphertext, or Active Record Encryption keys into the incident note.
4. Stop DM import creation if retention failure means raw text purge or anonymization SLO cannot be met.
5. Run `ConversationImportRetentionJob.perform_now` only in maintenance mode or approved staging/production smoke.
6. If a database restore occurred, run retention/anonymization before public traffic returns.

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
- `cleanup_expired_github_connection_states` recurring task is loaded
- `enforce_conversation_import_retention` recurring task is loaded
- conversation import retention smoke is completed in staging or explicitly deferred with release-owner approval
- failed job path is visible in application `jobs` and `audit_logs`
- failed job retry/discard smoke evidence is saved or explicitly deferred with release-owner approval
- failed job release gate status、blocking checks、notification requirement、approval policyが記録されている
- GitHub Actions CI passed
