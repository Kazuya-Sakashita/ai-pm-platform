# ISSUE-063: failed job操作の通知、二人承認、SLOアラートをrelease gateへ接続する

## Issue番号

ISSUE-063

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/96

## 背景

ISSUE-061では、failed job操作のMVP安全制御として、action別理由テンプレート、discard確認必須、AuditLog由来の運用履歴、24時間retry/discard/rejected件数、SLO候補定義を追加した。

しかし、世界レベルSaaSの本番運用では、高リスク操作の二人承認、操作発生時の通知、SLO閾値超過時のアラート、release gateへの接続が必要になる。特にdiscardは不可逆に近く、retryも外部API再実行や重複副作用を起こし得るため、単独operator判断だけでは成熟度が足りない。

## 目的

failed job操作を本番運用に耐える監視、承認、通知フローへ引き上げ、誤操作、検知遅れ、説明責任不足を減らす。

## 完了条件

- 高リスクdiscard操作の二人承認またはowner承認の要否が設計されている
- Slackまたは運用通知チャンネルへの通知方針が設計されている
- failed job操作SLO候補がrelease gateまたはrunbookへ接続されている
- retry/discard/rejected件数の閾値超過時の対応手順が定義されている
- ISSUE-062完了後にretry後再失敗率を計測する方針が定義されている
- OpenAPI、Backend、Frontend、AuditLog、RSpec、Playwrightの変更範囲が整理されている
- 設計レビューと実装レビューが `docs/review/` に保存されている

## スコープ

- failed job操作通知設計
- 高リスクdiscardの承認フロー設計
- SLO閾値とrelease gate接続
- retry後再失敗率の計測方針
- AuditLog viewerまたは運用履歴の検索導線検討
- 必要なOpenAPI、Backend、Frontend、テスト更新

## 非スコープ

- ISSUE-061で完了したaction別理由テンプレート
- ISSUE-061で完了したdiscard確認必須
- ISSUE-062のProduct JobとSolid Queue job明示マッピング保存
- 外部監視SaaSの本格導入
- bulk retry/discard

## 関連レビュー

- `docs/review/20260707_failed_job_operation_safety_design_review.md`
- `docs/review/20260707_failed_job_operation_safety_implementation_review.md`
- `docs/evaluation/20260707_failed_job_operation_slo_candidates.md`
- `docs/release/20260707_failed_job_operation_release_gate.md`
- `docs/review/20260707_failed_job_notification_approval_slo_gate_design_review.md`
- `docs/review/20260707_failed_job_notification_approval_slo_gate_implementation_review.md`
- ISSUE-064 / GitHub Issue #101
- ISSUE-065 / GitHub Issue #100
- ISSUE-066 / GitHub Issue #99

## レビュー結果

P2。ISSUE-061のMVPは合格見込みだが、本番release gate観点では通知、承認、SLOアラートが不足している。Security Engineer観点では、高リスクdiscardを単独operatorのUI確認だけで完結させる状態は長期運用では不十分である。

2026-07-07追記: MVPとしてQueue health API/UIへ `failed_job_release_gate` を追加した。Project境界拒否、Queue health取得不能はrelease停止、failed job残存、retry/discard件数、worker heartbeat、oldest unfinished、mapping fallbackはwarning/not_measuredとして表示する。実Slack送信と二人承認DB強制は後続課題として残す。

## 実装結果

- `Operations::FailedJobReleaseGate` serviceを追加し、SLO閾値、通知方針、承認方針、release gate statusを判定するようにした。
- Queue health API responseへ `failed_job_release_gate` を追加した。
- OpenAPIとFrontend生成型へ `FailedJobReleaseGate` 関連schemaを追加した。
- Frontend運用監視で、リリースゲート、通知要否、破棄承認方針、主要checkを表示した。
- 通知policyは論理チャンネル `operations` とsafe metadataのみを返し、`raw_exception`、`backtrace`、`serialized_arguments`、`token`、`database_url`、`dm_body`、`ai_prompt` を禁止fieldとして明示した。
- release runbook `docs/release/20260707_failed_job_operation_release_gate.md` を追加した。

## 検証結果

- 2026-07-07: `bundle exec rspec spec/services/operations/failed_job_release_gate_spec.rb spec/services/operations/queue_health_query_spec.rb spec/requests/api/v1/operations_spec.rb`: 15 examples, 0 failures
- 2026-07-07: `npm run api:verify`: 成功。Redocly CLIのNode version warningのみ非ブロッキング
- 2026-07-07: `npm run display:check`: 成功
- 2026-07-07: `npm run frontend:build`: 成功
- 2026-07-07: `npm run frontend:e2e -- e2e/queue-health.spec.ts`: 1 passed
- 2026-07-07: `bundle exec ruby bin/rails zeitwerk:check`: 成功

## 次アクション

1. PRを作成し、GitHub Actions `verify` を確認する。
2. CI成功後、GitHub Issue #96へ検証結果をコメントする。
3. Slack実送信はISSUE-064 / #101で進める。
4. 二人承認DB/API強制はISSUE-065 / #100で進める。
5. retry後再失敗率集計はISSUE-066 / #99で進める。
6. staging/production worker smokeでは `docs/release/20260707_failed_job_operation_release_gate.md` を参照する。
