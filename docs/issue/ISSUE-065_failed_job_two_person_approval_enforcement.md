# ISSUE-065: failed job discardの二人承認をDB/APIで強制する

## Issue番号

ISSUE-065

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/100

## 背景

ISSUE-063ではdiscardに二人承認またはrelease owner承認が必要である方針をQueue healthに表示した。しかし、現時点ではAPIが二人承認状態をDBで保持しておらず、実操作を機械的にブロックできない。

## 目的

高リスクdiscardを単独operatorのUI確認だけで実行できる状態から、監査可能な二人承認またはrelease owner承認へ引き上げる。

## 完了条件

- approval request/approval eventのDB設計がADRまたは設計レビューに残っている
- discard実行前に二人承認またはrelease owner承認をAPIで検証できる
- 同一actorによる申請と承認の兼任を禁止する
- 期限切れ承認、Project不一致、権限不足を安全に拒否する
- AuditLogへ承認者、理由テンプレート、期限、対象safe IDを保存する
- OpenAPI、Backend、Frontend、RSpec、Playwrightが同期されている
- 設計レビューと実装レビューが `docs/review/` に保存されている

## スコープ

- failed job discard承認request
- 承認/却下API
- discard実行時の承認gate
- Frontend承認状態表示

## 非スコープ

- retryの二人承認
- Slack実通知
- 外部ワークフロー承認ツール連携
- bulk discard

## 関連レビュー

- `docs/review/20260707_failed_job_notification_approval_slo_gate_design_review.md`
- `docs/review/20260707_failed_job_notification_approval_slo_gate_implementation_review.md`

## レビュー結果

P1。世界レベルSaaS基準では、本番discardは不可逆性が高く、方針表示だけでは不足する。DB/API強制が必要である。

## 関連ADR

- `docs/decisions/ADR-0020_failed_job_discard_two_person_approval.md`

## 実装方針

- `failed_job_discard_approvals` tableを追加する。
- 承認依頼、承認、却下APIを追加する。
- 申請者と承認者が同一actorの場合は承認を拒否する。
- discard実行時に `discard_approval_id` を必須化する。
- Project、failed job ID、Solid Queue job ID、reason template、承認状態、期限、申請者/承認者の差分を検証する。
- 承認note/rejection reason本文はAuditLogへ保存せず、presenceだけをsafe metadataとして残す。
- Frontend運用監視で承認状態と承認/却下導線を表示する。

## 実装結果

- `FailedJobDiscardApproval` modelとmigrationを追加した。
- `Operations::FailedJobDiscardApprovalService` を追加した。
- `Operations::FailedJobOperationService` のdiscardに承認gateを追加した。
- `QueueHealthQuery` のfailed job sampleへ最新承認状態を追加した。
- OpenAPI、生成型、Frontend、Playwrightを同期した。
- release owner単独override、承認専用通知、承認一覧APIは後続課題とする。

## 検証結果

- `bundle exec rspec spec/services/operations/failed_job_discard_approval_service_spec.rb spec/services/operations/failed_job_notification_service_spec.rb spec/services/operations/failed_job_operation_service_spec.rb spec/services/operations/queue_health_query_spec.rb spec/requests/api/v1/operations_spec.rb`: 33 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: 成功
- `npm run api:verify`: 成功。Redocly CLIのNode version warningのみ非ブロッキング
- `npm run display:check`: 成功
- `npm run frontend:build`: 成功
- `npm run frontend:e2e -- --grep "Queue health operations panel"`: 1 passed

## 次アクション

1. GitHub Issue #100本文を更新する。
2. PRを作成し、GitHub Actions `verify` を確認する。
3. PRマージ後、ISSUE-066 / GitHub Issue #99でretry後再失敗率の実測へ進む。
