# ISSUE-059: failed job操作のProject境界を厳密化する

## Issue番号

ISSUE-059

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/88

## 背景

ISSUE-056でfailed jobの再実行/破棄APIとUIを追加した。MVPではproject admin権限と運用画面文脈を前提にしているが、Solid Queue job単体から対象Projectとの厳密な関連を常に復元できる設計にはなっていない。

世界レベルSaaSの運用操作では、operatorが別Project由来のjobを誤って操作しない境界検証が必要である。

## 目的

Product JobとSolid Queue jobの関連を明示的に保存または検証し、failed job retry/discard操作が対象Project由来であることをAPI側で厳密に確認できるようにする。

## 完了条件

- failed job操作時に対象Projectとの関連をAPI側で検証できる
- 関連が確認できないfailed jobは403または404のsafe errorで拒否される
- OpenAPI、Backend、Frontend型、RSpecが同期されている
- AuditLogにProject境界検証結果がsafe metadataとして保存される
- 既存のQueue health表示とfailed job操作UIが破綻しない
- 設計レビューと実装レビューが `docs/review/` に保存されている

## スコープ

- Product JobとSolid Queue jobの関連ID保存または検証設計
- failed job操作APIのProject境界検証
- Queue health sampleの関連情報追加
- RSpec、必要に応じたPlaywright更新
- OpenAPIと生成型同期

## 非スコープ

- bulk retry/discard
- staging/production worker smoke
- 通知、SLO、二人承認
- GitHub App live smoke

## 関連レビュー

- `docs/review/20260707_failed_job_retry_discard_operations_design_review.md`
- `docs/review/20260707_failed_job_retry_discard_operations_implementation_review.md`
- `docs/review/20260707_failed_job_followup_issue_split_review.md`
- `docs/review/20260707_failed_job_project_boundary_design_review.md`
- `docs/review/20260707_failed_job_project_boundary_implementation_review.md`

## レビュー結果

P1。ISSUE-056のMVPは合格だが、Project境界の厳密化は本番運用前に強化すべき重要課題である。Security Engineer観点では、operator UIの文脈だけに依存した境界判断は長期的に不十分である。

2026-07-07追記: 設計レビューでは、既存job互換を優先してSolid Queue job argumentsからProduct Job ID候補を解決する方式をISSUE-059のMVPとして採用した。実装レビューでは、retry/discard前のProject境界検証、cross-project/unresolvedのsafe not_found拒否、Queue health sampleのProject絞り込み、AuditLog safe metadata保存を確認した。

追加改善として、Project不一致時に他ProjectのProduct Job IDやProject IDを現在ProjectのAuditLogへ保存しない方針にした。監査可能性を維持しながら、テナント境界情報の露出を避ける。

## 実装結果

- `Operations::FailedJobProjectResolver` を追加し、Solid Queue job argumentsからProduct Job ID候補を抽出するようにした。
- failed job retry/discard前に、Product Jobが要求Projectに属することを検証するようにした。
- Project不一致、未解決、複数候補、lookup失敗は `failed_job_not_found` のsafe 404で拒否するようにした。
- 境界拒否時は `operations.failed_job_project_boundary_rejected` をAuditLogへ保存し、他ProjectのIDは保存しないようにした。
- Queue health APIはProject文脈を受け取り、境界確認済みfailed job sampleだけを返すようにした。
- OpenAPIへ `FailedJobProjectBoundaryStatus`、`product_job_id`、`project_id`、`project_boundary_status` を追加し、Frontend型を同期した。
- Frontendの直近失敗ジョブ表示へ「管理ジョブID」と「Project境界確認済み」を追加した。

## 検証結果

- 2026-07-07: `git diff --check`: 成功
- 2026-07-07: `bundle exec rspec spec/services/operations/failed_job_project_resolver_spec.rb spec/services/operations/failed_job_operation_service_spec.rb spec/services/operations/queue_health_query_spec.rb spec/requests/api/v1/operations_spec.rb`: 19 examples, 0 failures
- 2026-07-07: `npm run api:verify`: 成功。Redocly CLIのNode version warningのみ非ブロッキング
- 2026-07-07: `npm run display:check`: 成功
- 2026-07-07: `npm run frontend:build`: 成功
- 2026-07-07: `npm run frontend:e2e -- e2e/queue-health.spec.ts`: 1 passed

## 次アクション

1. PR #93をmerge済み。GitHub Actions `verify` は成功。
2. GitHub Issue #88はクローズ済み。
3. 通知、SLO、二人承認、追加安全制御はGitHub Issue #90 / ISSUE-061で継続する。
4. Product JobとSolid Queue jobの明示関連ID保存はISSUE-062 / GitHub Issue #94で継続する。
