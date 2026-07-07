# 2026-07-07 failed job retry後再失敗率 実装レビュー

## 評価日時

2026-07-07 20:08 JST

## 評価担当

Codex L1ロール分離レビュー

- Product Manager
- Backend Architect
- QA / Release Manager
- Security Engineer

## Issue番号

ISSUE-066 / GitHub Issue #99

## 使用フレームワーク

- G-STACK
- DDD
- ISO25010
- DORA Metrics

## 対象

`Operations::RetryRefailureRateQuery`、`Operations::QueueHealthQuery`、`Operations::FailedJobReleaseGate`、OpenAPI、Frontend mock、RSpec、Playwright。

## Rails責務分離方針

- Query: `RetryRefailureRateQuery` がAuditLogと `job_queue_mappings` からretry後再失敗率を集計する。
- Query: `QueueHealthQuery` は集計結果を `failed_job_operation_metrics.retry_refailure` へ載せる。
- Service Object: `FailedJobReleaseGate` は集計済みmetricsを読み、pass/warning/not_measuredを判定する。
- Model: `Project` に `job_queue_mappings` 関連を追加しただけで、複雑な集計は入れていない。
- Controller: 変更なし。
- 過剰設計回避: 新規metrics table、BI集計基盤、原因分類jobは作らず、Queue healthのMVP計測に限定した。

## 良かった点

- `retry_refailure` に `measured`、`rate`、`numerator`、`denominator`、`threshold`、`exclusions` を持たせ、根拠をAPIで確認できる。
- release gateの `retry_refailure_rate` が `not_measured` から実測pass/warningへ進んだ。
- AuditLog safe metadataと明示mappingだけで集計し、raw payloadを扱わない。
- RSpecでAuditLogとmappingから再失敗を検出する経路を確認した。
- Playwright mockも実測値表示へ更新した。

## 改善点

- retry後成功率、平均復旧時間、原因分類はまだ未実装である。
- 長期トレンド保存はなく、Queue health取得時点の24時間windowのみである。
- 複数retryや連鎖再失敗の分析は同一Solid Queue job ID単位に留まる。
- 外部AI比較レビューは未実施で、Codex一次レビューとして保存する。

## 優先順位

| 優先度 | 項目 | 状態 |
| --- | --- | --- |
| P0 | 再失敗率定義 | 完了 |
| P0 | safe metadata集計 | 完了 |
| P1 | Queue health metrics追加 | 完了 |
| P1 | release gate実測判定 | 完了 |
| P2 | 長期トレンド、原因分類、MTTR | 後続 |

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
