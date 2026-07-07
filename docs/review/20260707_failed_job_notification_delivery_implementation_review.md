# 2026-07-07 failed job運用通知 実送信 実装レビュー

## 評価日時

2026-07-07 19:43 JST

## 評価担当

Codex L1ロール分離レビュー

- Security Engineer
- Backend Architect
- DevOps
- QA / Release Manager
- Product Manager

## Issue番号

ISSUE-064 / GitHub Issue #101

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- DORA Metrics

## 対象

`Operations::NotificationGateway`、`Operations::FailedJobNotificationService`、`Operations::FailedJobOperationService`、`Operations::QueueHealthQuery`、RSpec、ADR、Runbook。

## Rails責務分離方針

- Controller: 変更なし。認証、認可、入力受け取り、レスポンス返却に限定した。
- Model: 変更なし。AuditLogの既存記録機能を利用し、新規tableは追加しない。
- Service Object: `FailedJobNotificationService` がevent判定、safe payload生成、AuditLog記録、重複抑制を担当する。
- Adapter / Gateway: `NotificationGateway` がwebhook送信だけを担当する。
- Query: `QueueHealthQuery` はrelease gate評価後に通知Serviceへ委譲するだけに留めた。
- 過剰設計回避: 通知設定DB、再送job、Project別通知routingはMVP範囲から外し、後続で扱う。

## 良かった点

- 通知処理をGatewayとServiceに分け、HTTP送信、payload制御、監査記録の責務が明確になった。
- `OPERATIONS_NOTIFICATION_WEBHOOK_URL` 未設定時は安全にno-opし、開発環境とCIでsecretを不要にした。
- 通知payloadはallowlist方式で、raw exception、token、database URLなどを捨てる。
- 通知失敗時に `operations.failed_job_notification_failed` をAuditLogへ保存する。
- release gate warning/blockはdedupe keyとcooldownで重複通知を抑える。

## 改善点

- webhook送信失敗の自動再送は未実装である。
- 通知先のProject別設定、重大度別routing、通知muteは未実装である。
- release gate通知はQueue health評価に接続しているため、将来は専用schedulerまたはrelease gate evaluatorへ切り出す余地がある。
- Slack payloadはtext中心であり、Block Kit最適化はしていない。
- 外部AI比較レビューは未実施で、Codex一次レビューとして保存する。

## 優先順位

| 優先度 | 項目 | 状態 |
| --- | --- | --- |
| P0 | safe payload allowlist | 完了 |
| P0 | webhook URL未設定no-op | 完了 |
| P0 | 通知失敗AuditLog | 完了 |
| P1 | failed job操作成功時通知 | 完了 |
| P1 | release gate warning/block通知 | 完了 |
| P2 | 通知再送、通知設定DB、Project別routing | 後続 |

## 検証結果

- `bundle exec rspec spec/services/operations/notification_gateway_spec.rb spec/services/operations/failed_job_notification_service_spec.rb spec/services/operations/failed_job_operation_service_spec.rb spec/services/operations/queue_health_query_spec.rb`: 20 examples, 0 failures
- `bundle exec rspec spec/services/operations/notification_gateway_spec.rb spec/services/operations/failed_job_notification_service_spec.rb spec/services/operations/failed_job_operation_service_spec.rb spec/services/operations/queue_health_query_spec.rb spec/requests/api/v1/operations_spec.rb`: 26 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: 成功
- `npm run api:verify`: 成功。Redocly CLIのNode version warningのみ非ブロッキング
- `npm run display:check`: 成功
- `npm run frontend:build`: 成功
- `npm run frontend:e2e -- --grep "Queue health operations panel"`: 1 passed

## 次アクション

1. GitHub Issue #101本文を更新する。
2. PRを作成し、GitHub Actions `verify` を確認する。
3. PRマージ後、通知再送、Project別routing、通知状態DBを後続Issueで検討する。
