# ISSUE-056: failed job再実行/破棄のoperator操作API/UIを追加する

## Issue番号

ISSUE-056

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/81

## 背景

ISSUE-004ではQueue health監視MVPとfailed job safe visibilityを実装済みだが、failed jobの再実行/破棄は未実装である。現状は運用者が失敗を検知できても、復旧操作はRails consoleやrunbook依存になり、監査証跡とoperator権限が不足する。

## 目的

project adminだけが、直近failed jobに対して理由テンプレート付きで再実行または破棄できる最小操作API/UIを追加し、操作結果をAuditLogへ保存する。

## 完了条件

- `GET /operations/queue-health` のfailed job sampleに操作対象IDと操作可否が含まれる
- failed job再実行APIがOpenAPI、Backend、Frontend型へ同期されている
- failed job破棄APIがOpenAPI、Backend、Frontend型へ同期されている
- 再実行/破棄はproject adminのみ実行できる
- 操作理由テンプレートが必須で、free-form本文やraw exceptionはAuditLogへ保存しない
- 操作成功後にQueue healthを再取得できる
- RSpecとPlaywrightで成功、権限拒否、安全なレスポンスを確認する
- 設計レビューと実装レビューを `docs/review/` へ保存する

## スコープ

- Solid Queue failed executionの単体retry/discard操作
- 操作理由テンプレート
- AuditLog記録
- Queue health panelからの操作導線
- OpenAPIと生成型同期

## 非スコープ

- bulk retry/discard
- failed jobのraw error、backtrace、arguments表示
- Slack/メール通知
- SLO alerting
- staging/production worker smokeの実環境証跡
- GitHub App live smoke

## 関連レビュー

- `docs/review/20260704_failed_job_safe_visibility_implementation_review.md`
- `docs/review/20260704_queue_health_monitoring_implementation_review.md`
- `docs/review/20260703_solid_queue_production_job_backend_implementation_review.md`
- `docs/review/20260707_failed_job_retry_discard_operations_design_review.md`
- `docs/review/20260707_failed_job_retry_discard_operations_implementation_review.md`

## レビュー結果

P1。世界レベルSaaSではfailed jobを表示するだけでは運用復旧の責任を果たせない。一方で操作系は破壊的であるため、admin限定、理由テンプレート必須、AuditLog必須、raw exception非表示を最低条件にする。

2026-07-07実装レビューで、OpenAPI、Backend、Frontend型、Queue health panel、RSpec、Playwrightの接続を確認した。project admin限定、理由テンプレート必須、AuditLog保存、safe responseはMVP条件を満たす。staging/production worker smokeとProject境界の厳密化は後続改善として残す。

## 検証結果

- `bundle exec rspec spec/services/operations/failed_job_operation_service_spec.rb spec/services/operations/queue_health_query_spec.rb spec/requests/api/v1/operations_spec.rb`: 12 examples, 0 failures
- `npm run api:verify`: 成功。Redocly CLIのNode version warningのみ非ブロッキング
- `npm run display:check`: 成功
- `npm run frontend:build`: 成功
- `npm run frontend:e2e -- --grep "Queue health operations panel"`: 1 passed

## 次アクション

1. PRを作成し、GitHub Actions `verify` を確認する。
2. CI成功後にGitHub Issue #81へ検証結果をコメントする。
3. Issue #81をクローズする。
4. staging/production worker smokeはIssue #4またはrelease gateで継続する。
