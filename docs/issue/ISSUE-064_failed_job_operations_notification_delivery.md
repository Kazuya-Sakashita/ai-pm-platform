# ISSUE-064: failed job操作リリースゲート通知を実送信する

## Issue番号

ISSUE-064

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/101

## 背景

ISSUE-063ではQueue health API/UIに `failed_job_release_gate` とnotification policyを追加した。しかし、現時点では論理チャンネル `operations` を表示するだけで、Slackまたは運用通知チャンネルへの実送信はない。

## 目的

release gate warning/block、failed job操作実行、通知失敗を運用者へ確実に知らせ、検知遅れを減らす。

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

## 次アクション

1. Slack webhookまたは通知gatewayの秘密情報管理方針を設計する。
2. safe payload schemaをOpenAPIまたは内部型で定義する。
3. 通知失敗AuditLogとRSpecを追加する。
