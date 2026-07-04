# Queue Health API Design

## Issue

- ISSUE-025

## Goal

Solid QueueとProduct jobsの最低限の運用状態を、アプリ内からread-onlyで確認できるようにする。

## Endpoint

`GET /api/v1/operations/queue-health`

## Response

Top-level `data` は以下を返す。

- `status`: `healthy` / `degraded` / `unavailable`
- `checked_at`: ISO8601 datetime
- `heartbeat_stale_after_seconds`: worker heartbeatの鮮度判定しきい値
- `oldest_unfinished_threshold_seconds`: queue latencyの警戒しきい値
- `workers`: worker/scheduler/dispatcher/supervisorのsafe summary
- `queues`: queueごとのunfinished count、oldest unfinished、latency seconds
- `failed_executions`: failed execution countと直近失敗時刻
- `recurring_tasks`: recurring taskのkey、class、queue、schedule
- `product_jobs`: Product用 `jobs` tableのstatus別集計と直近失敗件数
- `warnings`: 運用者が確認すべきsafe warning

## Safety

APIは以下を返さない。

- Solid Queue job arguments
- raw exception / backtrace
- database URL
- raw GitHub state、nonce digest、state digest
- idempotency key生値またはdigest
- private key、token、secret

Solid Queue tableが未準備、またはqueue DBへ接続できない場合は、API自体を500にせず `status=unavailable` とsafe warningを返す。

## Read-Only Boundary

ISSUE-025では再実行、破棄、queue pause/unpause、worker stop/startは扱わない。操作系は認証/権限/承認ログ設計後に別Issueで扱う。

## Initial Thresholds

- heartbeat stale: 60秒
- oldest unfinished warning: 300秒

MVPでは環境変数化せず固定値にする。production運用でSLOが固まったらADRまたはrelease runbookで調整する。

## Frontend

Workspace左側に「運用監視」パネルを追加し、以下を表示する。

- Queue health status
- worker数、stale worker数
- failed execution count
- queueごとのunfinished/latency
- recurring taskロード状況
- Product jobsのfailed count
- 手動更新ボタン

## Review Gate

OpenAPI追加後、実装前に `docs/review/20260704_queue_health_api_design_review.md` を保存する。
