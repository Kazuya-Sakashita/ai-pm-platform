# GitHub Reconciliation Async Retry Job Review

## 評価日時

2026-07-03 12:09:36 JST

## 評価担当

Codex as Product Owner / CTO / Tech Lead / AI Architect / Backend Architect / DevOps / Security Engineer / QA

## 使用フレームワーク

- G-STACK
- ISO25010
- STRIDE
- DORA Metrics

## 対象

- Issue番号: ISSUE-004
- 対象実装: GitHub Issue publish reconciliation のcooldown後非同期retry
- 関連ADR: `docs/decisions/ADR-0008_github_search_retry_backoff.md`

## 良かった点

- cooldownを設定したattemptに対して、監査用の `github_reconciliation` Jobを `queued` で作成し、ActiveJobの `wait_until` でmarker search再実行を予約できるようにした。
- retry対象を `github_issue_publish_attempt` としてJobへ紐付け、手動reconciliation用のIssue Draft Jobと区別できるようにした。
- Job実行時にattemptが解決済みならcancelし、二重reconcileや不要なGitHub Searchを避ける安全弁を入れた。
- cooldownがまだ有効な場合は同じJobを再予約し、早すぎる実行でrate limitやindexing delayを悪化させないようにした。
- ProviderError発生時はsafe error detailとsafe metadataだけをJob/AuditLogに残し、tokenやraw responseを保存しない方針を維持した。
- 成功、失敗、reschedule、cancelをRSpecで検証し、同期reconcilerの既存specも同時に通した。

## 改善点

- Rails標準の開発向けActiveJob adapterに依存しており、productionで確実に遅延実行するための永続キュー基盤が未選定である。
- queued Jobとattemptの対応は `target_type/target_id` で表現しているが、Job metadata列がないため、UIや運用監視でretry理由を直接一覧しにくい。
- retry jobの最大回数はattempt側にあるが、運用上のdead letter queue、管理画面からの再実行、失敗通知は未実装である。
- live GitHub App credentialで、実Search APIのindexing delayと通常search成功経路を検証できていない。
- secondary rate limitやnetwork timeoutのrecording testはまだなく、現状はProviderErrorのunit test中心である。

## 優先順位

- P0: production向け永続Job基盤をADR化し、非同期retryがプロセス再起動で失われないようにする。
- P0: live GitHub App credentialでconnect/publish/reconcile/search smokeを実施する。
- P1: Job metadataまたは専用retry audit viewを追加し、retry理由、次回実行時刻、attempt idを運用者が追えるようにする。
- P1: controlled retry承認者、理由テンプレート、二重Issue防止チェック文言をUI/APIへ追加する。
- P2: GitHub Search rate limitのrecordingまたはmock contract testを追加する。

## 次アクション

- `docs/decisions/` にproduction queue基盤のADRを追加する。
- Issue #4に今回の実装と残課題を同期する。
- CI成功後もIssue #4はクローズせず、live smokeとproduction queue方針へ進む。

## Issue番号

- ISSUE-004

## 検証結果

- `bundle exec rspec spec/jobs/github_issue_publish/reconciliation_retry_job_spec.rb spec/services/github_issue_publish/reconciliation_retry_scheduler_spec.rb spec/services/github_issue_publish/reconciliation_service_spec.rb spec/models/github_issue_publish_attempt_spec.rb`: 16 examples, 0 failures
- `bundle exec rspec`: 137 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run frontend:build`: success
- `FRONTEND_URL=http://localhost:3002 NEXT_PUBLIC_API_BASE_URL=http://localhost:3003/api/v1 npm run frontend:e2e`: 14 passed
- 初回 `npm run frontend:e2e` は `localhost:3000` を別プロジェクトが使用していたため失敗。今回変更の不具合ではなく、専用ポートとCORS originを揃えて再実行した。

## 評価結論

G-STACK観点では、Goalである二重Issue防止とSearch cooldown統制に対して、非同期retryの最小実装は到達した。Strategyとして、既存の `ReconciliationService` を再利用した点はよく、TacticsとしてJob/AuditLogへ成功、失敗、cancel、rescheduleを残した点も監査性に効いている。

一方で、世界レベルSaaS基準では「ActiveJobを使った」だけでは不十分である。プロセス再起動やdeployを跨いでも遅延Jobが失われない永続キュー、運用監視、dead letter、手動再実行、live credential smokeまで揃って初めて完成扱いにできる。したがって今回の実装はISSUE-004の大きな前進だが、クローズ条件には未達である。
