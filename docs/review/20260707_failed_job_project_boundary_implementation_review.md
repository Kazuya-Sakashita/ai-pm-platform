# 2026-07-07 failed job Project境界厳密化 実装レビュー

## 評価日時

2026-07-07 16:03:58 JST

## 評価担当

Codex（Security Engineer / Backend Architect / Frontend Architect / QA / Tech Lead）

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- DORA Metrics

## 対象Issue

- ISSUE-059
- GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/88
- 親Issue: ISSUE-004 / GitHub Issue #4

## 対象成果物

- `docs/api/openapi.yaml`
- `backend/app/controllers/api/v1/operations_controller.rb`
- `backend/app/services/operations/failed_job_project_resolver.rb`
- `backend/app/services/operations/failed_job_operation_service.rb`
- `backend/app/services/operations/queue_health_query.rb`
- `backend/spec/services/operations/failed_job_project_resolver_spec.rb`
- `backend/spec/services/operations/failed_job_operation_service_spec.rb`
- `backend/spec/services/operations/queue_health_query_spec.rb`
- `backend/spec/requests/api/v1/operations_spec.rb`
- `frontend/app/workspace-client.tsx`
- `frontend/e2e/queue-health.spec.ts`
- `frontend/lib/api/schema.d.ts`
- `docs/issue/ISSUE-059_failed_job_project_boundary_hardening.md`

## 評価概要

failed job retry/discard操作にProject境界検証を追加した。`Operations::FailedJobProjectResolver` がSolid Queue job argumentsからProduct Job ID候補を抽出し、単一のProduct Jobへ解決できる場合だけ `verified` とする。操作対象Projectと一致しない場合は `project_mismatch` としてsafe 404で拒否し、AuditLogには他ProjectのIDを保存しない。

Queue health APIはproject文脈を受け取り、境界確認済みのfailed job sampleだけを表示、操作可能にした。Frontendでは管理ジョブIDとProject境界確認済み表示を追加し、Playwrightで操作導線を確認した。

## Rails責務分離方針

- Controller: `Operations::QueueHealthQuery.new(project: project)` を呼び出し、操作APIでは既存の認可とResult返却に限定した。
- Resolver Object: `FailedJobProjectResolver` がProduct Job候補抽出、単一解決、境界ステータス、安全メタデータ生成を担当した。
- Service Object: `FailedJobOperationService` が境界検証、retry/discard実行、成功/拒否AuditLog保存を担当した。
- Query Object: `QueueHealthQuery` がProject単位のProduct Job summary、境界確認済みfailed job sample、Project単位のfailed execution summaryを返す。
- 過剰設計回避: 新規DBテーブル、bulk操作、通知、二人承認はISSUE-061以降へ分離し、ISSUE-059ではProject境界の最小強化に限定した。

## G-STACK

- Goal: failed job操作で別Project由来のjobを誤操作できないようにする。
- Strategy: Product Job IDをSolid Queue jobから復元し、要求Projectとの一致を操作前に検証する。
- Tactics: Resolver、Operation Service、Queue Health Query、OpenAPI、Frontend型、E2Eを同期した。
- Assessment: Project不一致と未解決はsafe 404で拒否され、AuditLogにも境界拒否を残せる。MVPの本番前安全性は改善した。
- Conclusion: PR CI成功後、GitHub Issue #88はクローズ可能。
- Knowledge: 境界拒否ログは監査に必要だが、他Project IDを保存しないことがテナント分離上重要である。

## 良かった点

- `FailedJobProjectResolver` を追加し、境界復元ロジックをServiceやControllerから分離できた。
- Project不一致時はretry/discardを実行せず、レスポンスは `failed_job_not_found` で統一した。
- 境界拒否AuditLogに `project_mismatch`、要求Project ID、Solid Queue job IDを残しつつ、他ProjectのProduct Job IDを保存しないようにした。
- Queue health sampleは境界確認済みのfailed jobだけを表示し、UI上でも「Project境界確認済み」を示した。
- OpenAPIと生成型を同期し、`FailedJobProjectBoundaryStatus` を定義できた。
- RSpecでResolver、操作成功、Project不一致拒否、未解決拒否、Queue health sample非表示を確認した。
- PlaywrightでQueue health表示、境界表示、再実行、再取得導線を確認した。

## 改善点

- Solid Queue job argumentsからUUIDを探索する方式のため、将来のjob引数変更に弱い。
- Queue healthのProject別failed execution countはlookup範囲内のsampleに基づくため、全件数を示すものではない。
- `project_mismatch` の発生時に運用者が調査するためのrunbookはまだ不足している。
- AuditLog viewerで境界拒否イベントを検索しやすくするUIは未実装である。

## 改善案

- 後続IssueでProduct Job IDとSolid Queue job IDの明示マッピングを保存する。
- Queue health responseにsample由来の件数であることを示すmetadataを追加する。
- release runbookへ `project_mismatch`、`product_job_unresolved`、`product_job_ambiguous` の調査手順を追記する。
- AuditLog viewerまたは運用履歴画面で境界拒否イベントを可視化する。

## 優先順位

- P0: PR CI `verify` 成功確認。
- P0: GitHub Issue #88へ実装内容、検証結果、残課題を同期する。
- P0: CI成功後にGitHub Issue #88をクローズする。
- P1: ISSUE-061で通知、SLO、二人承認、追加安全制御を進める。
- P2: 明示マッピング保存ADRを検討する。

## 検証結果

- `git diff --check`: 成功
- `bundle exec rspec spec/services/operations/failed_job_project_resolver_spec.rb spec/services/operations/failed_job_operation_service_spec.rb spec/services/operations/queue_health_query_spec.rb spec/requests/api/v1/operations_spec.rb`: 19 examples, 0 failures
- `npm run api:verify`: 成功。Redocly CLIのNode version warningのみ非ブロッキング
- `npm run display:check`: 成功
- `npm run frontend:build`: 成功
- `npm run frontend:e2e -- e2e/queue-health.spec.ts`: 1 passed

## 次アクション

1. PRを作成する。
2. GitHub Actions `verify` を確認する。
3. GitHub Issue #88へ検証結果をコメントする。
4. CI成功後、GitHub Issue #88をクローズする。
5. 残る安全制御はGitHub Issue #90 / ISSUE-061で継続する。

## Issue番号

- ISSUE-059
- GitHub Issue #88
- 親Issue: GitHub Issue #4

## 判定

合格。Project境界検証、safe error、AuditLog、OpenAPI/型同期、RSpec、Playwrightが揃っており、PR CI成功後にIssue #88はクローズ可能である。明示マッピング保存と運用可視化は後続改善として扱う。
