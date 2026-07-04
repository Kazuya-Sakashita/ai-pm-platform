# ISSUE-023: Solid Queueでproduction job queue基盤を実装する

## Issue番号

ISSUE-023

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/23

登録理由: ADR-0010でproduction向け永続Job基盤としてSolid Queue採用方針を決定したため。

登録日: 2026-07-03

## 背景

AI PM Platformは、GitHub publish reconciliation retryをActiveJobで実装済みである。しかし、現在のproduction設定には永続queue backendがなく、process restartやdeploy時にbackground jobの実行保証と運用監視が不足する。

会議ログ取り込み、AI議事録生成、AIレビュー、GitHub Issue/OpenAPI生成、外部連携復旧を自動化するAI PMとしては、jobの永続性、worker分離、失敗監査、再実行方針、queue latency監視が必須である。

## 目的

Solid Queueをproduction job queue backendとして導入し、GitHub reconciliation retryと将来のAI/連携jobを失わず、監査可能に実行できる基盤を作る。

## 完了条件

- `solid_queue` gemが追加されている
- Solid Queue用migration/tableが追加されている
- productionのActiveJob adapterが `:solid_queue` に設定されている
- productionで `QUEUE_DATABASE_URL` が必須になっている
- GitHub reconciliation retry jobが `github_reconciliation` queueへ分離されている
- worker processの起動方法がDockerまたはrelease docsに記載されている
- queue health、failed job、queue latency、worker livenessの最低限のrunbookがある
- Job引数にsecretやraw idempotency keyを含めないことをテストまたはレビューで確認している
- RSpec、Zeitwerk、OpenAPI verify、CIが成功している
- 実装レビューが `docs/review/` に保存されている

## スコープ

- Backend Gemfile/Gemfile.lock
- Solid Queue migration/config
- ActiveJob production adapter
- GitHub reconciliation retry queue名
- worker process documentation
- release runbook
- RSpecまたは設定検証
- 実装レビュー

## 非スコープ

- Sidekiq/Redis導入
- AI生成job全体の実装
- queue管理画面の実装
- 本番監視SaaS連携
- GitHub App live credential smoke
- screen reader確認

## 関連レビュー

- `docs/review/20260703_github_reconciliation_async_retry_job_review.md`
- `docs/review/20260703_production_job_queue_adr_review.md`
- `docs/review/20260703_solid_queue_production_job_backend_implementation_review.md`
- `docs/review/20260704_queue_health_monitoring_implementation_review.md`
- `docs/review/20260704_failed_job_safe_visibility_implementation_review.md`

## 関連ADR

- `docs/decisions/ADR-0010_production_job_queue_backend.md`
- `docs/decisions/ADR-0008_github_search_retry_backoff.md`

## レビュー結果

2026-07-03にCodex一次レビューを実施。ActiveJobによるGitHub reconciliation retryはローカル/CIでは検証済みだが、productionでは永続queue backendなしに完了扱いにできない。Solid Queue採用は、既存PostgreSQL構成とAI PM Platformの監査要件に合っている。ただし、実装後もworker health、queue latency、failed job、DB負荷、connection poolを継続監視する必要がある。

2026-07-03にSolid Queue実装を追加。`solid_queue` gem、production adapter、queue database設定、`QUEUE_DATABASE_URL` 必須化、`bin/jobs`、`config/queue.yml`、`config/recurring.yml`、`db/queue_schema.rb`、GitHub reconciliation専用queue、運用runbook、config specを追加した。

良かった点:

- ADR-0010で採用判断を先に文書化してから実装Issue化した。
- Product用 `jobs` table とqueue backendの責務を分離できている。
- GitHub reconciliation retryを専用queueへ分離することで、AI生成jobとの干渉を減らせる。
- RedisなしでMVP-to-betaの本番queueを開始できる。
- Solid Queueの標準generator出力を取り込み、`bin/jobs` でworkerを起動できるようにした。
- `docs/release/20260703_solid_queue_operations_runbook.md` にworker起動、監視、停止、失敗対応を整理した。
- config specでqueue名とproduction queue database設定を検証した。
- production smokeで同一DB fallbackの危険を検出し、`QUEUE_DATABASE_URL` 必須に修正した。
- ISSUE-025でread-only Queue health APIとFrontend運用監視パネルを追加し、runbook外でもworker heartbeat、failed count、queue latencyを確認できるようにした。
- ISSUE-027で直近failed jobのsafe summaryを追加し、raw exceptionやjob argumentsを出さずにqueue/class/failed_atを確認できるようにした。

改善点:

- production相当のSolid Queue worker smokeは別queue DBで確認済み。staging/deploy環境での確認は未実施。
- worker processのdeploy組み込みはrunbookまでで、実際のホスティング設定は未作成。
- Queue health監視MVPとfailed job safe visibilityは追加済み。ただしfailed job再実行/破棄の権限、承認ログ、操作UI、通知/SLOは未整備。
- DB負荷とconnection poolのcapacity仮説が未作成。

検証結果:

- `RAILS_ENV=test bundle exec rails db:prepare`: success
- `bundle exec rspec spec/config/solid_queue_configuration_spec.rb spec/jobs/github_issue_publish/reconciliation_retry_job_spec.rb spec/services/github_issue_publish/reconciliation_retry_scheduler_spec.rb spec/services/github_issue_publish/reconciliation_service_spec.rb spec/models/github_issue_publish_attempt_spec.rb`: 19 examples, 0 failures
- `bundle exec rspec`: 140 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK（Node engine警告あり）
- `npm run frontend:build`: success
- `FRONTEND_URL=http://localhost:3002 NEXT_PUBLIC_API_BASE_URL=http://localhost:3003/api/v1 npm run frontend:e2e`: 14 passed
- production config runner: `active_job.queue_adapter=solid_queue`、DB configs=`primary,queue`
- production mode local worker smoke: `RAILS_ENV=production ... QUEUE_DATABASE_URL=postgres://.../ai_pm_queue_test bundle exec bin/jobs` がSupervisor、Dispatcher、Worker、Schedulerを起動
- production mode heartbeat check: `SolidQueue::Process` に Dispatcher、Scheduler、Supervisor(async)、Worker を確認
- 2026-07-04 failed job safe visibility: `bundle exec rspec spec/services/operations/queue_health_query_spec.rb spec/requests/api/v1/operations_spec.rb`: 3 examples, 0 failures
- 2026-07-04 failed job safe visibility: `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- 2026-07-04 failed job safe visibility: `npm run frontend:build`: success
- 2026-07-04 failed job safe visibility: `npm run frontend:e2e -- e2e/queue-health.spec.ts`: 1 passed

## 優先度

P0

理由:

- ISSUE-004のGitHub reconciliation retryをproduction-readyにするための残タスクである
- AI PM Platformの外部連携復旧、AI生成、レビュー自動化の共通基盤になる
- 永続queueなしでは本番SaaS基準で「ジョブが動く」と評価できない

## 次アクション

- GitHub Actions CIを確認する
- GitHub Actions CIを確認し、成功後にIssue #23のクローズ可否を判断する
- staging/deploy環境で `bin/jobs` worker smokeを再確認する
- queue latency、failed job、worker heartbeatの通知/SLOを設計する
- failed job再実行/破棄のoperator権限、承認ログ、監査UIを設計する
