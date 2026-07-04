# ISSUE-027: Failed job safe visibility MVPを作る

## Issue番号

ISSUE-027

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/27

登録日: 2026-07-04

状態: 2026-07-04にcommit `1fe4963` をmainへ反映し、GitHub Actions CI `28706040725` success確認後にクローズ済み。

備考: 誤って重複作成した GitHub Issue #28 は #27 へ一本化し、重複としてクローズ済み。

## 背景

ISSUE-025でQueue health監視APIと運用監視パネルを実装し、failed execution countは確認できるようになった。しかし、運用者は「どのqueue/classが失敗しているか」をアプリ内で把握できず、runbookやDB確認へ戻る必要がある。

一方で、Solid Queueのfailed executionにはraw exceptionやjob argumentsが含まれ得るため、そのままUI/APIへ出すと情報漏えいにつながる。再実行/破棄の操作も、認証、operator権限、承認ログ、AuditLogが未整備の状態では危険である。

## 目的

Queue health APIと運用監視パネルへ、直近failed jobのsafe summaryをread-onlyで追加し、秘密情報を出さずに運用初動を速くする。

## 完了条件

- OpenAPIにfailed job safe summary schemaが追加されている
- `GET /api/v1/operations/queue-health` が直近failed job sampleをsafe fieldsだけで返す
- raw exception、backtrace、job arguments、DB URL、token、state digestを返さない
- Frontend運用監視パネルで直近failed jobのqueue/class/failed_atを確認できる
- failed jobの再実行/破棄は実装しない
- RSpec、OpenAPI verify、Frontend build、Playwright E2Eが成功している
- レビュー結果が `docs/review/` へ保存されている
- GitHub Issueへ同期されている

## スコープ

- Queue health OpenAPI schema拡張
- `Operations::QueueHealthQuery` のfailed job samples
- Request/service spec
- Frontend運用監視パネル表示
- Playwright mock E2E
- Issue台帳、API設計レビュー、実装レビュー

## 非スコープ

- failed job再実行
- failed job破棄
- queue pause/unpause
- worker起動/停止
- 認証/権限UI
- 外部監視SaaS連携
- 実staging/production worker smoke証跡取得

## 関連レビュー

- `docs/review/20260704_queue_health_api_design_review.md`
- `docs/review/20260704_queue_health_monitoring_implementation_review.md`
- `docs/review/20260704_failed_job_safe_visibility_api_design_review.md`
- `docs/review/20260704_failed_job_safe_visibility_implementation_review.md`

## レビュー結果

2026-07-04にAPI設計レビューを実施。failed jobは可視化だけに限定し、raw errorやargumentsを返さない方針で実装へ進める。

2026-07-04に実装レビューを実施。`GET /api/v1/operations/queue-health` に `failed_job_samples` を追加し、Frontend運用監視パネルで直近失敗ジョブのclass、queue、失敗時刻を確認できるようにした。Backendは `SolidQueue::FailedExecution#error` やjob argumentsを読まず、safe metadataだけを返す。retry/discardなどの操作系は未実装のまま分離した。

良かった点:

- OpenAPI contractを先に更新し、Frontend型生成へ同期した。
- failed execution countだけではなく、運用初動に必要なqueue/class/failed_atを表示できるようにした。
- raw exception、backtrace、job arguments、DB URL、token、state digestを返さないことをspecで固定した。
- Playwrightで長いjob class名の表示崩れを検出し、コンパクトパネルでも隠れない縦積みレイアウトへ修正した。

改善点:

- 実staging/production worker上のfailed execution表示smokeは未実施。
- retry/discard操作はoperator権限、承認者、理由テンプレート、AuditLog設計後に別Issue化が必要。
- 通知/SLO/外部監視連携は未設計。

検証結果:

- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK（Node engine warning: current v22.7.0）
- `bundle exec rspec spec/services/operations/queue_health_query_spec.rb spec/requests/api/v1/operations_spec.rb`: 3 examples, 0 failures
- `npm run display:check`: Display labels OK
- `npm run frontend:build`: success
- `npm run frontend:e2e -- e2e/queue-health.spec.ts`: 1 passed
- GitHub Actions CI `28706040725`: success（commit `1fe4963`）

## 優先度

P1

理由:

- ISSUE-004とISSUE-023の残タスクであるfailed job運用UIの前段になる
- live GitHub App credentialなしで進められる
- 操作系を入れずにread-only可視化だけなら安全に運用品質を上げられる

## 次アクション

- GitHub Issueへ登録する（完了）
- OpenAPI contractを更新する（完了）
- API設計レビューを保存する（完了）
- Backend/Frontendを実装する（完了）
- 実装レビューを保存する（完了）
- CI成功後にGitHub Issue #27へ検証結果をコメントし、クローズする（完了）
- retry/discard操作は認証/監査設計後に別Issueとして扱う
