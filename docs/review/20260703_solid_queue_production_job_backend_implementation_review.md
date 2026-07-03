# Solid Queue Production Job Backend Implementation Review

## 評価日時

2026-07-03 21:10 JST

## 評価担当

Codex as CTO, DevOps, Backend Architect, Security Engineer, QA, Tech Lead

## 使用フレームワーク

- G-STACK
- DORA Metrics
- ISO25010
- STRIDE
- OWASP Top 10

## Issue番号

- ISSUE-023
- GitHub Issue #23
- Related: ISSUE-004 / GitHub Issue #4

## 良かった点

- `solid_queue` gemを導入し、production ActiveJob adapterを `:solid_queue` に設定した。
- `config.solid_queue.connects_to = { database: { writing: :queue } }` とproduction `queue` database設定を追加し、queue databaseを分離可能にした。
- `config/queue.yml` で wildcard ではなく `github_reconciliation`、`ai_generation`、`ai_review`、`default` を明示した。
- `GithubIssuePublish::ReconciliationRetryJob` を `github_reconciliation` queueへ移し、AI生成jobとの干渉を下げた。
- production `QUEUE_DATABASE_URL` を必須にし、queue schemaがprimary DBへ未投入のままworker起動する事故を避ける方針にした。
- `bin/jobs`、`config/recurring.yml`、`db/queue_schema.rb` を追加し、Solid Queueの標準起動経路とschemaを保存した。
- `docs/release/20260703_solid_queue_operations_runbook.md` を追加し、worker起動、停止、監視、失敗対応を運用手順化した。
- config specでqueue名とproduction queue database設定を検証した。

## 改善点

- production相当のSolid Queue worker実行 smoke は、別queue DBでSupervisor、Dispatcher、Worker、Scheduler起動とheartbeatを確認済み。ただしstaging/deploy環境でのscheduled executionまでは確認していない。
- `QUEUE_DATABASE_URL` 必須化により安全性は上がったが、deploy設定漏れではproduction bootが失敗するためrelease checklistが重要になる。
- queue latencyやfailed executionのメトリクス収集先はrunbookに留まり、アプリ内ダッシュボードや外部監視には未接続。
- failed jobのoperator retry/discard権限、承認者、監査UIは未実装。
- PostgreSQL connection pool、worker concurrency、AI生成負荷のcapacity testは未実施。

## 優先順位

- P0: GitHub Actions CIでSolid Queue導入後の全検証を通す。
- P0: stagingまたはlocal production modeで `bin/jobs` が起動し、scheduled jobを処理できることをsmokeする。
- P0: GitHub Actions CIで `QUEUE_DATABASE_URL` 必須化後の全検証を通す。
- P1: staging/deploy環境で `bin/jobs` worker smokeを再確認する。
- P1: failed job再実行/破棄の権限設計と監査文言を追加する。
- P1: queue latency、failed count、worker heartbeatの監視実装を追加する。

## 次アクション

- GitHub Issue #23へ実装結果、同一DB fallback検出、別queue DB smoke成功、検証結果を同期する。
- GitHub Actions CI成功後、Issue #23はクローズ候補にする。
- ISSUE-004はlive GitHub App smoke、screen reader確認、controlled retry承認者/理由テンプレートが残るためopen維持する。
- 次のP0候補としてlive GitHub App smokeまたはcontrolled retry承認体験の補強へ進む。

## G-STACK

### Goal

GitHub reconciliation retryと将来のAI jobを、本番で永続実行できるqueue backendへ移行する。

### Strategy

ADR-0010に従い、Redisを増やさずPostgreSQLベースのSolid Queueを採用し、ActiveJob境界を維持する。

### Tactics

- Gemfile/Gemfile.lockへ `solid_queue` を追加する。
- `solid_queue:install` で標準設定、schema、worker executableを生成する。
- production `database.yml` に `primary` と `queue` を定義する。
- reconciliation retry jobを専用queueへ分離する。
- runbookとspecで運用・設定の最低限を固定する。

### Assessment

MVP-to-betaのproduction queue backendとしては前進。ただし、worker実行のproduction-mode smokeと監視実装がないため、世界レベルSaaS基準では運用完成ではない。

### Conclusion

ISSUE-023の実装条件は概ね満たした。worker smokeで同一DB fallbackの危険を検出し、`QUEUE_DATABASE_URL` 必須化後、別queue DBでのworker smokeも確認した。GitHub Actions CI成功後にクローズ候補。ただしISSUE-004は残タスクがあるためクローズ不可。

### Knowledge

Solid Queue公式READMEのRails 7.1+導入手順、queue database設定、`bin/jobs` worker起動、queue explicit polling推奨、signal handlingを参照した。

## AIレビュー比較

Codex一次レビューのみ。Claude、ChatGPT等の外部AIレビューは未実施。外部レビューが追加された場合は、Solid QueueとSidekiq/GoodJob比較、DB負荷、worker運用監視の差分を追記する。
