# Failed Job Safe Visibility API Design

## Issue

- ISSUE-027

## Goal

Queue health APIに直近failed jobのsafe summaryを追加し、運用者がどのqueue/classで失敗が起きているかをアプリ内で把握できるようにする。

## Endpoint

既存endpointを拡張する。

`GET /api/v1/operations/queue-health`

## Added Response Field

`data.failed_job_samples`

各要素は以下のみ返す。

- `queue_name`
- `class_name`
- `active_job_id`
- `failed_at`

## Safety Boundary

返さないもの:

- Solid Queue job arguments
- raw exception
- exception backtrace
- database URL
- token/private key
- raw GitHub state
- nonce/state digest
- idempotency key/digest

`active_job_id` は運用上の相関IDとして返すが、job argumentsやexception本文とは切り離す。

## Operation Boundary

ISSUE-027ではread-only表示のみ。retry/discard/pause/unpauseは実装しない。操作系はoperator role、承認者、理由テンプレート、AuditLog設計後に別Issueで扱う。

## Frontend

運用監視パネルに「直近Failed job」を追加する。

表示するもの:

- queue
- class
- failed_at

表示しないもの:

- raw error
- arguments
- stack trace
- secret-like values

## Review Gate

実装前に `docs/review/20260704_failed_job_safe_visibility_api_design_review.md` を保存する。
