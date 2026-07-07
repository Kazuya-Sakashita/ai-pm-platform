# ISSUE-061: failed job操作の安全制御と通知/SLOを強化する

## Issue番号

ISSUE-061

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/90

## 背景

ISSUE-056では、project admin限定、理由テンプレート必須、AuditLog保存、raw exception非表示を満たすfailed job単体操作MVPを追加した。

しかし、discardは不可逆に近く、retryも外部API再実行や重複副作用を起こす可能性がある。長期運用では、action別理由テンプレート、確認導線、通知、SLO、操作失敗時のアラートが必要になる。

## 目的

failed job操作を本番SaaS運用に耐える安全制御へ引き上げ、誤操作、説明不足、検知遅れを減らす。

## 完了条件

- retry用とdiscard用の理由テンプレートがaction別に分離されている
- discard操作に追加確認またはリスク確認導線がある
- 操作結果と失敗を運用者が追跡しやすい通知または運用履歴に接続されている
- failed job件数、再実行回数、破棄回数、再失敗率などのSLO候補が定義されている
- UI、API、AuditLogがfree-form秘密情報を保存しない
- RSpec、Playwright、レビュー文書が更新されている

## スコープ

- action別理由テンプレート
- discard確認導線
- 操作結果の通知または運用履歴設計
- SLO/メトリクス候補の定義
- UI/API/AuditLogの安全性レビュー

## 非スコープ

- Project境界の厳密化
- staging/production worker smoke
- bulk retry/discard
- Slack連携の本実装
- 外部監視SaaS連携

## 関連レビュー

- `docs/review/20260707_failed_job_retry_discard_operations_design_review.md`
- `docs/review/20260707_failed_job_retry_discard_operations_implementation_review.md`
- `docs/review/20260707_failed_job_followup_issue_split_review.md`
- `docs/review/20260707_failed_job_operation_safety_design_review.md`
- `docs/review/20260707_failed_job_operation_safety_implementation_review.md`
- `docs/evaluation/20260707_failed_job_operation_slo_candidates.md`

## レビュー結果

P2。ISSUE-056のMVP完了後に取り組むべき運用品質改善である。現時点のMVPをブロックするほどではないが、世界レベルSaaSの運用UIとしては、誤操作防止、通知、SLOが不足している。

2026-07-07追記: ISSUE-061のMVPとして、action別理由テンプレート、discard確認必須、AuditLog由来のsafe運用履歴、24時間retry/discard/rejected件数、SLO候補文書を追加した。Slack通知、外部監視、二人承認、retry後再失敗率はISSUE-063 / GitHub Issue #96で継続する。

## 実装結果

- retry/discard request schemaをOpenAPIで分離した。
- Backendでretry理由とdiscard理由をaction別にvalidationするようにした。
- discard操作は `discard_safety_confirmed: true` がない場合に拒否するようにした。
- Queue health responseへ24時間のretry/discard/rejected件数とsafe操作履歴を追加した。
- Frontendで再実行理由、破棄理由、破棄リスク確認チェックを分離した。
- Queue health responseの古いモックや旧レスポンスで新規操作メトリクス、履歴が欠落しても、Frontend側で安全な既定値へ正規化するようにした。
- SLO候補を `docs/evaluation/20260707_failed_job_operation_slo_candidates.md` に保存した。

## 検証結果

- 2026-07-07: `git diff --check`: 成功
- 2026-07-07: `git diff --cached --check`: 成功
- 2026-07-07: `bundle exec rspec spec/services/operations/failed_job_operation_service_spec.rb spec/services/operations/queue_health_query_spec.rb spec/requests/api/v1/operations_spec.rb`: 18 examples, 0 failures
- 2026-07-07: `npm run api:verify`: 成功。Redocly CLIのNode version warningのみ非ブロッキング
- 2026-07-07: `npm run display:check`: 成功
- 2026-07-07: `npm run frontend:build`: 成功
- 2026-07-07: `npm run frontend:e2e -- --grep "Queue health operations panel"`: 1 passed
- 2026-07-07: PR #97 CIで旧queue-health mock由来のFrontendクラッシュを検出し、payload正規化で修正。`npm run frontend:e2e -- e2e/auth-session.spec.ts e2e/meeting-workspace.spec.ts e2e/queue-health.spec.ts` は20 passed、6 failed。失敗6件はローカルRails API未起動による接続不可で、今回の互換修正とは別要因。
- 2026-07-07: PR #97 GitHub Actions `verify` run 28857189655 / job 85586547052 は成功。CheckRun annotationsは空。

## 次アクション

1. GitHub Issue #90へ検証結果をコメントし、PR #97 mergeでクローズする。
2. Slack通知、外部監視、二人承認、retry後再失敗率はISSUE-063 / GitHub Issue #96で継続する。
