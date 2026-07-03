# Production Job Queue ADR Review

## 評価日時

2026-07-03 19:19 JST

## 評価担当

Codex as CTO, DevOps, Security Engineer, QA, Tech Lead, Product Manager

## 使用フレームワーク

- G-STACK
- ADR
- DORA Metrics
- ISO25010
- STRIDE

## Issue番号

- ISSUE-004
- GitHub Issue #4

## 良かった点

- ActiveJob実装だけで本番可能と扱わず、production queue backendを別判断として切り出した。
- Redisなしの現行PostgreSQL構成に合わせ、MVP-to-betaではSolid Queueを採用する方針を明確にした。
- Product用 `jobs` table とqueue backendの責務を分離し、監査UIと実行基盤を混同しない方針にした。
- GitHub reconciliation retryの安全条件を、queue backendの自動retryに丸投げしない方針にした。
- worker process、queue latency、failed job、graceful shutdown、runbookを必須条件に含めた。

## 改善点

- Solid QueueはADRで採用判断しただけで、Gem追加、migration、production config、worker processは未実装。
- PostgreSQLをqueueにも使うため、DB負荷、connection pool、vacuum、long-running transactionの監視設計がまだ弱い。
- queue別concurrency、優先度、AI生成とGitHub reconciliationの分離はまだ具体値がない。
- GitHub Actionsでscheduled jobを本番相当adapterで検証する仕組みがない。
- failed job再実行の運用権限、承認者、監査文言が未定義。

## 優先順位

- P0: Solid Queue導入Issueを作成し、Gem、migration、production adapter、worker processを実装する。
- P0: GitHub reconciliation retry jobを `github_reconciliation` queueへ分離する。
- P0: worker health、queue latency、failed jobの最低限の運用runbookを作る。
- P1: PostgreSQL connection poolとqueue workloadのcapacity仮説を作る。
- P1: failed jobの再実行権限と承認ログを定義する。

## 次アクション

- ISSUE-004の残タスクとしてADR-0010を参照する。
- Solid Queue実装用のIssueを作成し、GitHub Issueへ同期する。
- 実装前にOpenAPI影響なしを明記し、Backend/DevOps変更として進める。
- 実装後にRSpec、Zeitwerk、OpenAPI verify、GitHub Actions CIを再確認する。

## G-STACK

### Goal

本番でGitHub reconciliation retryと将来のAI生成jobを失わず、監査可能に実行できるqueue基盤を決める。

### Strategy

現行PostgreSQL構成を活かし、MVP-to-betaではSolid Queueを採用する。ActiveJobを境界にして、将来Sidekiqへ移行できる余地を残す。

### Tactics

- `solid_queue` を追加する。
- production adapterを `:solid_queue` にする。
- worker processをweb processから分離する。
- Product用 `jobs` tableはユーザー向け監査として維持する。
- unsafe external side effectのretry判断はapplication service側に残す。

### Assessment

判断は妥当。ただし、実装と運用監視が未完了のままでは、世界レベルSaaS基準では本番利用不可。

### Conclusion

ADRとしてはAccepted。ただし、ISSUE-004はSolid Queue実装、live smoke、screen reader確認、controlled retry承認体験が残るためクローズ不可。

### Knowledge

Rails 7.1 API app、PostgreSQLのみのDocker構成、既存 `jobs` table、ActiveJob-based reconciliation retry実装を前提に評価した。

## AIレビュー比較

Codex一次レビューのみ。Claude、ChatGPT等の外部AIレビューは未実施。外部レビューが追加された場合は、queue backend選定、運用監視、DB負荷観点の相違を追記する。
