# ISSUE-064: failed job操作リリースゲート通知を実送信する

## Issue番号

ISSUE-064

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/101

## 背景

ISSUE-063ではQueue health API/UIに `failed_job_release_gate` とnotification policyを追加した。しかし、現時点では論理チャンネル `operations` を表示するだけで、Slackまたは運用通知チャンネルへの実送信はない。

## 目的

release gate warning/blocked、failed job操作実行、通知失敗を運用者へ確実に知らせ、検知遅れを減らす。

## 完了条件

- 通知adapterまたはgatewayの設計がADRまたは設計レビューに残っている
- webhook URLやtokenをAPIレスポンス、ログ、レビュー文書へ出さない
- release gate warning/block時にsafe payloadで通知できる
- failed job retry/discard操作実行時にsafe payloadで通知できる
- 通知失敗時にAuditLogへsafe metadataを残す
- RSpecと必要ならPlaywrightが追加されている
- 設計レビューと実装レビューが `docs/review/` に保存されている

## スコープ

- Slackまたは運用通知チャンネルへのMVP通知
- 通知payloadのsafe field制限
- 通知失敗時のAuditLog
- 環境変数未設定時の安全なno-op

## 非スコープ

- 外部監視SaaSの本格導入
- escalation policy全体
- 二人承認DB/API強制
- retry後再失敗率集計

## 関連レビュー

- `docs/review/20260707_failed_job_notification_approval_slo_gate_design_review.md`
- `docs/review/20260707_failed_job_notification_approval_slo_gate_implementation_review.md`

## レビュー結果

P1。ISSUE-063のMVPはrelease gateを可視化したが、実通知がないため運用者が画面を見ていない場合に検知遅れが残る。

## 実装方針

- `Operations::NotificationGateway` を追加し、webhook送信をAdapter / Gatewayとして分離する。
- `Operations::FailedJobNotificationService` を追加し、event判定、safe payload生成、通知成功/失敗AuditLog、release gate通知cooldownを担当させる。
- `OPERATIONS_NOTIFICATION_WEBHOOK_URL` 未設定時は安全なno-opにする。
- `FailedJobOperationService` は操作成功後に通知Serviceへ委譲する。
- `QueueHealthQuery` はrelease gate warning/block評価後に通知Serviceへ委譲する。
- Controller / Model には通知処理を入れない。

## 関連ADR

- `docs/decisions/ADR-0019_failed_job_operations_notification_gateway.md`

## 実装結果

- `Operations::NotificationGateway` を追加し、Slack incoming webhook互換の通知Gatewayを実装した。
- `Operations::FailedJobNotificationService` を追加し、safe payload allowlist、通知成功/失敗AuditLog、release gate通知cooldownを実装した。
- failed job retry/discard操作成功時に通知を試行する。
- Queue healthのrelease gate warning/block時に通知を試行する。
- `OPERATIONS_NOTIFICATION_WEBHOOK_URL` 未設定時は安全なno-opにする。
- 通知設定DB、再送job、Project別通知routingは後続課題とする。

## 検証結果

- `bundle exec rspec spec/services/operations/notification_gateway_spec.rb spec/services/operations/failed_job_notification_service_spec.rb spec/services/operations/failed_job_operation_service_spec.rb spec/services/operations/queue_health_query_spec.rb spec/requests/api/v1/operations_spec.rb`: 26 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: 成功
- `npm run api:verify`: 成功。Redocly CLIのNode version warningのみ非ブロッキング
- `npm run display:check`: 成功
- `npm run frontend:build`: 成功
- `npm run frontend:e2e -- --grep "Queue health operations panel"`: 1 passed

## 次アクション

1. GitHub Issue #101本文を更新する。
2. PRを作成し、GitHub Actions `verify` を確認する。
3. PRマージ後、#100と#99へ進む。
