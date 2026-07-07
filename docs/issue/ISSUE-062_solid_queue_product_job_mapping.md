# ISSUE-062: Product JobとSolid Queue jobの明示マッピングを保存する

## Issue番号

ISSUE-062

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/94

## 背景

ISSUE-059では、既存job互換を優先し、Solid Queue job argumentsからProduct Job ID候補を復元する方式でfailed job操作のProject境界を強化した。

この方式はMVPとして有効だが、ActiveJobの引数形式に依存する。将来、job引数の構造変更、複数Product Job IDの混入、別種jobの追加が発生すると、境界復元が不安定になる可能性がある。

世界レベルSaaSの本番運用では、運用操作対象のProject境界を偶然の引数構造に依存させず、監査可能な関連IDとして保存する必要がある。

## 目的

Product JobとSolid Queue jobの関連を明示的に保存し、Queue health表示、failed job retry/discard、AuditLogで安定したProject境界検証を行えるようにする。

## 完了条件

- Product Job IDとSolid Queue job IDの保存方式がADRまたは設計書に記録されている
- GitHub reconciliation retryなど既存Product Job enqueue時に関連IDを保存できる
- failed job操作時に明示マッピングを優先してProject境界を検証できる
- 既存jobやマッピング欠落時のfallback方針が安全側で定義されている
- Queue health sampleが明示マッピングを使ってProject別に安定表示できる
- OpenAPI、Backend、Frontend型、RSpecが必要に応じて同期されている
- 設計レビューと実装レビューが `docs/review/` に保存されている

## スコープ

- Product JobとSolid Queue jobの明示マッピング設計
- DB schemaまたは既存テーブル活用方針の決定
- enqueue時の関連ID保存
- failed job境界検証Resolverの明示マッピング優先化
- Queue health sampleの安定化
- RSpecと必要なAPI契約更新

## 非スコープ

- retry/discardの二人承認
- 通知、SLO、運用履歴UI
- bulk retry/discard
- staging/production worker smoke
- 外部監視SaaS連携

## 関連レビュー

- `docs/review/20260707_failed_job_project_boundary_design_review.md`
- `docs/review/20260707_failed_job_project_boundary_implementation_review.md`
- `docs/decisions/ADR-0018_solid_queue_product_job_mapping.md`
- `docs/review/20260707_solid_queue_product_job_mapping_design_review.md`
- `docs/review/20260707_solid_queue_product_job_mapping_implementation_review.md`

## レビュー結果

P2。ISSUE-059のMVPは合格だが、ActiveJob arguments依存は長期運用で脆い。Security EngineerとBackend Architect観点では、本番運用前またはfailed job操作対象が増える前に、明示マッピングへ移行できる設計を準備すべきである。

2026-07-07追記: ADR-0018で新規 `job_queue_mappings` table方式を採用した。Product Jobへ単一の `solid_queue_job_id` を持たせる案は、同一Product Jobの複数reschedule履歴を保持できないため不採用とした。

## 実装結果

- `job_queue_mappings` tableを追加し、Product JobとSolid Queue jobの明示マッピングを保存できるようにした。
- `GithubIssuePublish::ReconciliationRetryScheduler` と `GithubIssuePublish::ReconciliationRetryJob` のreschedule経路で、Solid Queueの `provider_job_id` が取得できる場合にmappingを保存するようにした。
- `Operations::FailedJobProjectResolver` は明示mappingを優先し、欠落時は既存のarguments fallbackを使うようにした。
- Queue health sample、failed job操作結果、AuditLog履歴に `product_job_mapping_source` を追加した。
- Frontendの運用画面で「境界根拠: 明示マッピング / 引数復元」を表示するようにした。

## 検証結果

- 2026-07-07: `RAILS_ENV=test bundle exec rails db:migrate`: 成功
- 2026-07-07: `bundle exec rspec spec/models/job_queue_mapping_spec.rb spec/services/github_issue_publish/reconciliation_retry_scheduler_spec.rb spec/services/operations/failed_job_project_resolver_spec.rb spec/services/operations/failed_job_operation_service_spec.rb spec/services/operations/queue_health_query_spec.rb spec/jobs/github_issue_publish/reconciliation_retry_job_spec.rb`: 29 examples, 0 failures
- 2026-07-07: `npm run api:verify`: 成功。Redocly CLIのNode version warningのみ非ブロッキング
- 2026-07-07: `npm run display:check`: 成功
- 2026-07-07: `npm run frontend:build`: 成功
- 2026-07-07: `npm run frontend:e2e -- e2e/queue-health.spec.ts`: 1 passed
- 2026-07-07: `bundle exec ruby bin/rails zeitwerk:check`: 成功

## 次アクション

1. PRを作成し、GitHub Actions `verify` を確認する。
2. CI成功後、GitHub Issue #94へ検証結果をコメントし、PR mergeでクローズする。
3. retry後再失敗率、mapping missing rate、通知/承認gateはISSUE-063 / GitHub Issue #96で継続する。
