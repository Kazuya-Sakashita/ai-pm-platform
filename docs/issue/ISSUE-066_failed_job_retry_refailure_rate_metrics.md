# ISSUE-066: failed job retry後再失敗率を計測する

## Issue番号

ISSUE-066

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/99

## 背景

ISSUE-062でProduct JobとSolid Queue jobの明示マッピングを保存し、ISSUE-063でrelease gateに `retry_refailure_rate` を `not_measured` として表示した。retry後に同種のfailed jobへ戻る比率を測れないと、retry操作が改善に効いているか判断できない。

## 目的

retry操作後の再失敗率を計測し、無効なretryや副作用リスクの高いretryをrelease gateで検知できるようにする。

## 完了条件

- retry後再失敗率の定義、計測窓、分母/分子、除外条件が設計されている
- `job_queue_mappings` とAuditLogを使って安全に集計できる
- Queue health APIの `retry_refailure_rate` checkが `not_measured` から実測値へ更新される
- 閾値10%以上でwarningまたはblockedにする基準がレビューされている
- raw exception、serialized arguments、secret、DM本文、AI入力全文を保存しない
- RSpecと必要ならFrontend/Playwrightが追加されている
- 設計レビューと実装レビューが `docs/review/` に保存されている

## スコープ

- retry後再失敗率の集計設計
- Queue health release gate check更新
- RSpec
- 必要なOpenAPI/Frontend表示更新

## 非スコープ

- Slack実通知
- 二人承認DB/API強制
- 外部監視SaaS連携
- 長期BI分析基盤

## 関連レビュー

- `docs/review/20260707_solid_queue_product_job_mapping_implementation_review.md`
- `docs/review/20260707_failed_job_notification_approval_slo_gate_implementation_review.md`

## レビュー結果

P2。release gateの精度向上に必要だが、ISSUE-063のMVP完了条件には含めず、明示マッピングの運用データが蓄積してから実装する。

## 計測定義

- 計測窓: 直近24時間。
- 分母: `operations.failed_job_retried` AuditLogのうち、`product_job_id` と `job_id` を持ち、同じProject / Product Jobの明示 `job_queue_mappings` と一致するretry。
- 分子: 分母のretry後、同じSolid Queue job IDが再びfailed executionへ戻ったretry。
- 除外条件: `product_job_id` 欠落、`job_id` 欠落、mapping不一致、ProjectなしQueue health、Solid Queue failed executionを参照できない場合。
- 閾値: 10%以上でwarning。初期MVPではblockedにしない。

## 実装結果

- `RetryRefailureRateQuery` を追加し、`QueueHealthQuery` から `retry_refailure` として返すようにした。
- `FailedJobReleaseGate` の `retry_refailure_rate` checkを実測pass/warningへ更新した。
- OpenAPIへ `FailedJobRetryRefailureMetrics` を追加した。
- Frontend default metricsとPlaywright mockを実測値へ更新した。
- raw exception、serialized arguments、secret、DM本文、AI入力全文は集計に使わない。

## 検証結果

- `bundle exec rspec spec/services/operations/retry_refailure_rate_query_spec.rb spec/services/operations/failed_job_release_gate_spec.rb spec/services/operations/queue_health_query_spec.rb spec/requests/api/v1/operations_spec.rb`: 23 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: 成功
- `npm run api:verify`: 成功。Redocly CLIのNode version warningのみ非ブロッキング
- `npm run display:check`: 成功
- `npm run frontend:build`: 成功
- `npm run frontend:e2e -- --grep "Queue health operations panel"`: 1 passed

## 次アクション

1. GitHub Issue #99本文を更新する。
2. PRを作成し、GitHub Actions `verify` を確認する。
3. PRマージ後、Queue health / failed job operationsの残課題を再棚卸しする。
