# 2026-07-07 Product Job / Solid Queue明示マッピング 実装レビュー

## 評価日時

2026-07-07 19:04 JST

## 評価担当

Codex一次レビュー

- Security Engineer
- Backend Architect
- Frontend Architect
- QA
- Product Manager

## Issue番号

ISSUE-062 / GitHub Issue #94

## 使用フレームワーク

- G-STACK
- DDD
- STRIDE
- OWASP Top 10
- ISO25010

## 対象

Product JobとSolid Queue jobの明示マッピング実装、Resolver、Queue health、Frontend表示、RSpec。

## 実装内容

- `job_queue_mappings` tableと `JobQueueMapping` modelを追加した。
- Reconciliation retryのschedule/reschedule経路で、Solid Queueの `provider_job_id` を明示mappingとして保存するようにした。
- failed job Project境界Resolverは、明示mappingを優先し、欠落時のみ従来のarguments fallbackを使うようにした。
- Queue health sample、failed job操作結果、AuditLog履歴へ `product_job_mapping_source` を追加した。
- Frontend運用画面に「境界根拠: 明示マッピング / 引数復元」を表示した。

## Rails責務分離方針

- Model: `JobQueueMapping` がprovider job idの正規化、保存、validationを担当。
- Service: `ReconciliationRetryScheduler` はenqueueとmapping保存の接続を担当。
- Job: cooldown中のreschedule時もmapping保存を担当。
- Query: `QueueHealthQuery` はResolver結果を表示用に整形するだけに限定。
- Resolver: `FailedJobProjectResolver` が明示mapping優先とfallback判定を担当。
- 過剰設計回避: provider汎用tableにはせず、現時点のSolid Queueに必要な列へ限定した。ただしprovider列を残し、将来拡張は可能にした。

## G-STACK

- Goal: failed job操作のProject境界をpayload推測から明示mappingへ移行する。
- Strategy: enqueue時に対応IDを保存し、運用画面と監査ログに根拠を表示する。
- Tactics: DB、OpenAPI、Backend、Frontend、RSpec、ADR、レビューを同期した。
- Assessment: 新規jobでは明示mappingが優先され、既存jobはfallbackで扱える。安全性と移行容易性のバランスは妥当。
- Conclusion: PR CI成功後、ISSUE-062はクローズ可能。
- Knowledge: queue providerが返すprovider job idは、運用操作の境界検証に使える一次情報として保存すべきである。

## STRIDE / OWASP確認

| 観点 | 評価 | 対応 |
| --- | --- | --- |
| Spoofing | 改善 | Project IDとProduct Job IDをmapping tableで明示 |
| Tampering | 改善 | provider + solid_queue_job_idのunique indexで一意性を確保 |
| Repudiation | 改善 | AuditLogへmapping sourceを保存 |
| Information Disclosure | 維持 | raw exception、backtrace、secret、queue payload全文を保存しない |
| Denial of Service | 維持 | mapping保存失敗時はsafe AuditLogへ記録し、fallback可能 |
| Elevation of Privilege | 改善 | Project境界検証で明示mappingを優先 |
| OWASP A01 Broken Access Control | 改善 | failed job操作のProject境界根拠を明確化 |
| OWASP A09 Logging/Monitoring | 改善 | 境界根拠をQueue healthとAuditLogへ表示 |

## 良かった点

- Product Jobへの単一ID追加ではなくmapping tableを選び、複数reschedule履歴を保持できる。
- 新規jobは明示mapping、既存jobはarguments fallbackの段階移行になっている。
- Queue healthとAuditLogで、境界検証の根拠を運用者が確認できる。
- RSpecでmapping保存、Resolver優先、Queue health表示、reschedule経路を確認した。
- OpenAPIとFrontend型を同期した。

## 改善点

- mapping保存失敗率やmissing rateはまだメトリクス化していない。
- 既存failed executionの過去データはfallbackのままである。
- GitHub reconciliation以外の将来jobでは、enqueue時mapping保存の共通化が必要になる可能性がある。
- mapping tableの専用管理UIはまだない。

## 改善案

- ISSUE-063 / GitHub Issue #96でmapping missing rateをSLO候補に追加する。
- retry後再失敗率を `job_queue_mappings` とAuditLogを使って集計する。
- 複数job typeでmapping保存が必要になった段階で、enqueue helperまたはserviceへ共通化する。
- 運用履歴の検索UIを追加する場合は、mapping source filterを用意する。

## 優先順位

| 優先度 | 項目 | 状態 |
| --- | --- | --- |
| P0 | mapping table追加 | 完了 |
| P0 | Resolver明示mapping優先 | 完了 |
| P1 | enqueue/reschedule時mapping保存 | 完了 |
| P1 | Queue health / AuditLog mapping source表示 | 完了 |
| P2 | mapping missing rate / retry後再失敗率 | ISSUE-063 / GitHub Issue #96で継続 |

## 検証結果

- `RAILS_ENV=test bundle exec rails db:migrate`: 成功
- `bundle exec rspec spec/models/job_queue_mapping_spec.rb spec/services/github_issue_publish/reconciliation_retry_scheduler_spec.rb spec/services/operations/failed_job_project_resolver_spec.rb spec/services/operations/failed_job_operation_service_spec.rb spec/services/operations/queue_health_query_spec.rb spec/jobs/github_issue_publish/reconciliation_retry_job_spec.rb`: 29 examples, 0 failures
- `npm run api:verify`: 成功。Redocly CLIのNode version warningのみ非ブロッキング
- `npm run display:check`: 成功
- `npm run frontend:build`: 成功
- `npm run frontend:e2e -- e2e/queue-health.spec.ts`: 1 passed
- `bundle exec ruby bin/rails zeitwerk:check`: 成功

## 次アクション

1. PRを作成し、GitHub Actions `verify` を確認する。
2. CI成功後、GitHub Issue #94へ検証結果をコメントし、PR mergeでクローズする。
3. mapping missing rate、retry後再失敗率、通知/承認gateはISSUE-063 / GitHub Issue #96で継続する。
