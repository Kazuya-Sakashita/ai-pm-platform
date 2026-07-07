# 2026-07-07 failed job discard二人承認 実装レビュー

## 評価日時

2026-07-07 20:00 JST

## 評価担当

Codex L1ロール分離レビュー

- Security Engineer
- Backend Architect
- Frontend Architect
- QA / Release Manager
- Product Manager

## Issue番号

ISSUE-065 / GitHub Issue #100

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- DDD
- ISO25010

## 対象

`FailedJobDiscardApproval`、`Operations::FailedJobDiscardApprovalService`、`Operations::FailedJobOperationService`、Operations API、OpenAPI、Frontend運用監視、RSpec、Playwright。

## Rails責務分離方針

- Controller: 認証、認可、params受け取り、Service結果のrenderに限定した。
- Model: `FailedJobDiscardApproval` は状態、関連、JSON表現、短いpredicateに限定した。
- Service Object: `FailedJobDiscardApprovalService` が承認依頼、承認、却下、期限切れ、AuditLogを担当する。
- Service Object: `FailedJobOperationService` がdiscard実行直前の承認gateと承認消費を担当する。
- Query: `QueueHealthQuery` はfailed job sampleへ最新承認状態を添えるだけに留めた。
- 過剰設計回避: release owner override、承認専用通知、外部承認ツール連携、Project別ポリシーDBはMVP範囲から外した。

## 良かった点

- discard実行時に `discard_approval_id` が必須になり、承認なし操作をAPIで拒否できる。
- 申請者と承認者が同一actorの場合は承認できない。
- 期限切れ承認、未承認、対象不一致、reason template不一致を実操作前に拒否する。
- 承認はdiscard成功後に `consumed` へ更新され、再利用しにくい。
- Frontendで未依頼、承認待ち、承認済み、却下、期限切れ、使用済みを表示できる。
- RSpecとPlaywrightで承認flowを確認した。

## 改善点

- release owner単独overrideは未実装である。
- 承認依頼専用通知、通知再送、外部承認ツール連携は未実装である。
- 承認期限は固定30分で、環境別/Project別に変更できない。
- 承認一覧APIはなく、Queue health sample上の最新承認だけを表示している。
- 外部AI比較レビューは未実施で、Codex一次レビューとして保存する。

## 優先順位

| 優先度 | 項目 | 状態 |
| --- | --- | --- |
| P0 | 承認DB table | 完了 |
| P0 | 同一actor承認禁止 | 完了 |
| P0 | discard API承認gate | 完了 |
| P1 | OpenAPI / Backend / Frontend同期 | 完了 |
| P1 | RSpec / Playwright | 完了 |
| P2 | release owner override、承認通知、承認一覧 | 後続 |

## 検証結果

- `bundle exec rspec spec/services/operations/failed_job_discard_approval_service_spec.rb spec/services/operations/failed_job_notification_service_spec.rb spec/services/operations/failed_job_operation_service_spec.rb spec/services/operations/queue_health_query_spec.rb spec/requests/api/v1/operations_spec.rb`: 33 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: 成功
- `npm run api:verify`: 成功。Redocly CLIのNode version warningのみ非ブロッキング
- `npm run display:check`: 成功
- `npm run frontend:build`: 成功
- `npm run frontend:e2e -- --grep "Queue health operations panel"`: 1 passed

## 次アクション

1. GitHub Issue #100本文を更新する。
2. PRを作成し、GitHub Actions `verify` を確認する。
3. PRマージ後、ISSUE-066 / GitHub Issue #99でretry後再失敗率の実測へ進む。
