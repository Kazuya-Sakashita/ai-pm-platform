# 2026-07-07 failed job retry後再失敗率 設計レビュー

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

Queue healthにおけるretry後再失敗率の定義、計測窓、分母/分子、除外条件、release gate反映。

## 計測定義

- 計測窓: Queue healthと同じ直近24時間。
- 分母: 直近24時間の `operations.failed_job_retried` AuditLogのうち、`product_job_id` を持つretry。
- 分子: 分母のretry後、AuditLogの `job_id` と一致する明示 `job_queue_mappings` が同じProject / Product Jobに存在し、そのSolid Queue job IDが再びfailed executionへ戻ったretry。
- 除外条件: `product_job_id` がないretry、ProjectがないQueue health、`job_queue_mappings` またはSolid Queue failed executionを参照できない場合。
- 閾値: 10%以上でwarning。初期MVPではblockedにしない。
- 表示: `rate` は0から1の小数で返し、release gateではpercentageと `numerator/denominator` で表示する。

## G-STACK

- Goal: retryが改善に効いているかをrelease gateで判断できるようにする。
- Strategy: raw job argumentsではなく、AuditLog safe metadataと明示mappingだけで集計する。
- Tactics: `QueueHealthQuery` で `retry_refailure` を集計し、`FailedJobReleaseGate` の `retry_refailure_rate` checkへ接続する。
- Assessment: MVPとして妥当。ただし長期BI分析や原因分類は後続。
- Conclusion: 実装へ進む。
- Knowledge: ISSUE-062の明示mappingがretry後再失敗率の前提である。

## 良かった点

- raw exception、serialized arguments、secret、DM本文、AI入力全文を使わずに集計できる。
- 既存のAuditLogと `job_queue_mappings` を活用し、新規tableを作らない。
- 分母/分子/閾値をAPIに返すため、Frontendや運用レビューで根拠を確認できる。
- 10%以上をwarningに留め、初期計測の誤検知でreleaseを過剰停止しない。

## 改善点

- 同じProduct Jobに複数retryが走る場合の原因分類はまだ粗い。
- retry後の成功率や平均復旧時間までは見ていない。
- failed executionの原因分類はsafe error detailに依存し、raw exception分析はしない。
- 外部AI比較レビューは未実施で、Codex一次レビューとして保存する。

## 優先順位

| 優先度 | 項目 | 判断 |
| --- | --- | --- |
| P0 | 分母/分子/除外条件の定義 | 完了 |
| P0 | safe metadataだけで集計 | 完了 |
| P1 | Queue health APIへmetrics追加 | 今回対応 |
| P1 | release gate checkを実測値へ更新 | 今回対応 |
| P2 | 原因分類、BI分析、MTTR連携 | 後続 |

## 次アクション

1. `QueueHealthQuery` に `retry_refailure` 集計を追加する。
2. `FailedJobReleaseGate` の `retry_refailure_rate` を実測値でpass/warning判定する。
3. OpenAPI、Frontend mock、RSpec、Playwrightを同期する。
4. 実装レビューを保存する。
