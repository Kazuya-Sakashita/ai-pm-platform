# ISSUE-025: Queue health監視APIと運用パネルMVPを作る

## Issue番号

ISSUE-025

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/25

登録日: 2026-07-04

備考: 誤って重複作成した GitHub Issue #26 は #25 へ一本化し、重複としてクローズ済み。

## 背景

ISSUE-023でSolid Queueをproduction job queue backendとして導入し、ISSUE-004ではGitHub reconciliation retryとconnection state cleanupをqueueで扱うようになった。しかし、queue health、worker heartbeat、failed job、queue latencyはrunbookで確認する状態に留まり、アプリ内から運用状態を素早く確認できない。

世界レベルSaaSとしては、background jobが「動く」だけでは不十分であり、worker停止、queue詰まり、failed execution増加、recurring task未ロードを早期に検知できるread-onlyな監視面が必要である。

## 目的

Solid Queueの稼働状態をread-only APIとFrontend運用パネルで可視化し、GitHub連携復旧やAI生成jobの本番運用リスクを下げる。

## 完了条件

- Queue healthのOpenAPI contractが追加されている
- Backendにread-only queue health APIが追加されている
- worker heartbeat、recurring task、failed execution count、unfinished queue latency、Product jobs summaryをsafe fieldsだけで返す
- Solid Queue tableが未準備の環境でもAPIが500にならず、`unavailable` とsafe warningを返す
- Frontendに運用パネルが追加され、queue healthを手動更新できる
- failed jobの再実行/破棄など破壊的操作は実装しない
- RSpec、OpenAPI verify、Frontend build、Playwright E2Eまたは該当mock E2Eが成功している
- レビュー結果が `docs/review/` へ保存されている
- GitHub Issueへ同期されている

## スコープ

- `GET /api/v1/operations/queue-health`
- Queue health query/service
- Queue health serializerまたはsafe response builder
- Frontend運用パネル
- OpenAPI schema/type generation
- Request spec
- Playwright mock E2E
- Issue台帳、API設計、実装レビュー

## 非スコープ

- failed jobの再実行/破棄
- worker起動/停止操作
- production監視SaaS連携
- 認証/権限UI
- queue DBのmigration変更
- 実staging/production worker smoke証跡取得

## 関連レビュー

- `docs/review/20260703_solid_queue_production_job_backend_implementation_review.md`
- `docs/review/20260704_solid_queue_staging_worker_smoke_runbook_review.md`
- `docs/review/20260704_queue_health_api_design_review.md`
- `docs/review/20260704_queue_health_monitoring_implementation_review.md`

## レビュー結果

2026-07-04にAPI設計レビューを実施。監視MVPはread-onlyに限定し、秘密情報、raw job arguments、exception backtrace、database URL、state digestを返さない方針とした。

2026-07-04にQueue health監視MVPを実装。`GET /api/v1/operations/queue-health`、`Operations::QueueHealthQuery`、Frontend運用監視パネル、Playwright E2E、request spec、service specを追加した。

良かった点:

- OpenAPI contractを先に追加し、Frontend生成型へ同期してから実装した。
- Solid Queue table未準備時もAPIが500にならず、`unavailable` とsafe warningを返す。
- worker heartbeat、stale worker数、failed execution count、queue unfinished/latency、recurring task、Product jobs summaryをread-onlyで表示できる。
- raw job arguments、raw exception/backtrace、DB URL、state digestをresponseへ含めないことをrequest specで確認した。
- Frontendに「運用監視」パネルを追加し、手動更新でdegradedからhealthyへ変わる表示をE2Eで確認した。

改善点:

- 実staging/productionのSolid Queue tableでのhealthy/degraded確認は未実施。
- failed job再実行/破棄の権限、承認者、AuditLog、UIは未実装。
- queue latency、failed count、worker heartbeatの通知/SLO/外部監視連携は未実装。
- thresholdは固定値で、環境別設定ではない。
- 認証/認可未実装のため、閲覧権限はISSUE-006で制御が必要。

検証結果:

- `bundle exec rspec spec/requests/api/v1/operations_spec.rb spec/services/operations/queue_health_query_spec.rb`: 3 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK（Node engine warning: current v22.7.0）
- `npm run display:check`: Display labels OK
- `npm run frontend:build`: success
- `npm run frontend:e2e -- e2e/queue-health.spec.ts`: 1 passed
- `git diff --check`: pass

## 優先度

P1

理由:

- ISSUE-004の残タスクであるqueue監視を前進させる
- live GitHub App credentialがなくても進められる
- background jobの運用不備はAI PM Platform全体の信頼性に直結する
- 破壊的操作を避けたread-only監視なら認証導入前でも安全に価値を出せる

## 次アクション

- GitHub Issue #25へ実装結果と検証結果をコメントする
- GitHub Actions CIを確認する
- 実staging/production worker smoke証跡を取得する
- failed job操作系UIは認証/承認ログ設計後に別Issue化する
- queue latency、failed count、worker heartbeatの通知設計を追加する
