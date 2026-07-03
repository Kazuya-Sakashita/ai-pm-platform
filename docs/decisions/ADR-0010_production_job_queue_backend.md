# ADR-0010: Production job queue backend for AI PM workflow

## Status

Accepted

## Date

2026-07-03

## Context

AI PM Platform now uses ActiveJob for GitHub publish reconciliation retry. This is enough for local and CI verification, but it is not enough for production operation.

Current state:

- Rails version is 7.1.x.
- `backend/Gemfile` does not include a production queue backend.
- `backend/config/environments/test.rb` uses `config.active_job.queue_adapter = :test`.
- `backend/config/environments/production.rb` still has only commented sample queue settings.
- Docker Compose currently provides PostgreSQL only. There is no Redis service.
- The application already has a domain `jobs` table for user-facing job state and auditability.

Production workflows that depend on background execution include:

- GitHub publish reconciliation retry after cooldown.
- AI minutes generation.
- Future AI review and evaluation pipelines.
- Future Discord, Notion, Google Drive, and Slack ingestion.

World-class SaaS operation requires persistent jobs, worker isolation, retry visibility, deploy-safe shutdown, queue latency monitoring, and failure audit. The default in-process async execution is not acceptable for these workflows because process restarts can drop or delay work without enough operational evidence.

## Decision

Adopt Solid Queue as the first production queue backend for the MVP-to-beta phase.

The current implementation remains ActiveJob-based. Before enabling production background execution, the backend must add and configure Solid Queue explicitly.

Rationale:

1. The product already depends on PostgreSQL, and the current local/CI architecture has no Redis.
2. Solid Queue keeps the operational stack smaller than Sidekiq for the first production phase.
3. ActiveJob can remain the application boundary, so job classes do not depend directly on the queue backend.
4. The existing user-facing `jobs` table can remain the product audit model, while Solid Queue owns execution scheduling and retries.
5. Database-backed queue behavior is easier to bootstrap for the first controlled beta than adding another stateful Redis dependency.

## Required Implementation

The following work is required before production use:

1. Add the Solid Queue gem to the backend.
2. Install and migrate Solid Queue tables.
3. Configure `config.active_job.queue_adapter = :solid_queue` in production.
4. Define named queues at minimum:
   - `github_reconciliation`
   - `ai_generation`
   - `ai_review`
   - `default`
5. Move GitHub reconciliation retry jobs from `queue_as :default` to `queue_as :github_reconciliation`.
6. Add a worker process command to Docker and deployment documentation.
7. Add graceful shutdown guidance for deploys.
8. Add queue health checks and runbook entries.
9. Add monitoring for:
   - queue latency
   - failed job count
   - retry count
   - job age
   - worker liveness
10. Keep application `Job` records as the product-facing audit trail.

## Operational Policy

### Retry

Business retry rules stay in application services. The queue backend should not blindly retry unsafe external side effects.

For GitHub reconciliation:

- `GithubIssuePublish::ReconciliationRetryJob` may reschedule itself when cooldown is still active.
- Provider errors should be captured in the application `jobs` table and audit logs.
- Reconciliation must not create a duplicate GitHub Issue without marker search or human approval.

### Data Safety

Job arguments must not contain:

- installation access tokens
- raw Authorization headers
- raw idempotency keys
- full prompt text containing secrets
- raw external API responses that may include secrets

Jobs should pass stable record IDs and load current state at execution time.

### Observability

Solid Queue provides execution state. The application `jobs` table provides user-facing state.

Both layers are needed:

- Solid Queue: worker health, scheduling, execution, retries.
- Application `jobs`: product audit, UI status, safe error details, review workflow.

### Deployment

Production deployment must include at least one independent worker process. Web processes must not be the only process executing jobs.

Deploys must prove:

- pending jobs survive web process restart
- scheduled jobs execute after cooldown
- failed jobs are visible to operators
- worker shutdown does not lose in-flight work

## Alternatives Considered

### Sidekiq with Redis

Not selected for the first production phase.

Sidekiq is mature and strong for high-throughput queues, but it introduces Redis as another stateful dependency. This is likely appropriate once AI ingestion and integration workloads grow, but it is more infrastructure than the current beta needs.

Revisit when:

- queue throughput becomes a bottleneck
- workload isolation requires more advanced concurrency tuning
- Redis is already required for caching or realtime features

### GoodJob

Not selected.

GoodJob is also PostgreSQL-backed and ActiveJob-compatible. It is a viable alternative, but Solid Queue is preferred because it is the more Rails-native direction for new Rails applications and has a simpler adoption story for this project.

### Rails async adapter

Rejected for production.

The async adapter is acceptable for local experimentation only. It does not provide durable execution across process restarts and does not meet the auditability bar for GitHub, AI generation, or release workflow automation.

## Consequences

### Positive

- Adds durable background execution without introducing Redis.
- Keeps the application boundary on ActiveJob.
- Aligns with the current PostgreSQL-only local and CI topology.
- Makes GitHub reconciliation retry production-operable.
- Preserves product audit via the existing `jobs` table.

### Negative

- Adds database tables and worker operations.
- Background workload can increase PostgreSQL pressure.
- Requires explicit queue monitoring and operational runbooks.
- Does not remove the need for future Sidekiq/Redis evaluation if workload grows.

## Follow-up

- [Done 2026-07-03] Create implementation issue for Solid Queue backend setup.
- [Done 2026-07-03] Add Solid Queue gem, queue schema, and production config.
- [Done 2026-07-03] Add worker process command and release runbook.
- [Done 2026-07-03] Move GitHub reconciliation retry job to `github_reconciliation` queue.
- [Done 2026-07-03] Add queue health and failed job runbook under `docs/release/`.
- [Todo] Add CI or smoke verification for production-adapter scheduled job execution.
