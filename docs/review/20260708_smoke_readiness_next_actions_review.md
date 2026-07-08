# 2026-07-08 smoke readiness next actions review

## 評価日時

2026-07-08 12:02:00 JST

## 評価担当

Codex / DevOps / Security Engineer / QA / Tech Lead

## Issue番号

ISSUE-004 / GitHub Issue #4

## 対象

- `scripts/github-webhook-live-smoke.rb`
- `scripts/solid-queue-worker-smoke-readiness.rb`
- `docs/release/20260704_github_app_live_smoke_runbook.md`
- `docs/release/20260704_solid_queue_staging_worker_smoke_runbook.md`

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- DORA Metrics
- ISO25010

## 評価サマリー

GitHub webhook live delivery smokeとSolid Queue staging / production worker smokeは、外部設定と実環境証跡が残るため未完了である。今回の改善では、既存のreadiness scriptが `safe_failures` だけで止まらず、operatorが次に直すべき設定を `next_actions` としてsafe JSONへ出力するようにした。

出力対象は失敗コードに対応する手順だけであり、webhook secret、private key、signature、raw payload、raw GitHub delivery id、DB URL、Rails master key、Active Record Encryption key、raw job argumentsは出力しない。

## 良かった点

- `safe_failures` から次アクションへ直結でき、外部設定待ちの手戻りを減らせる。
- GitHub webhook側では、runtime secret未設定、placeholder URL、delivery失敗をそれぞれ具体的な設定修正に変換できる。
- Solid Queue側では、Rails runner未使用、queue table未準備、worker heartbeat不足、recurring task未読込などを運用手順へ変換できる。
- 既存のsecret非出力方針を維持したまま、operator向けの情報量を増やせた。
- RSpecでsecret値を出力しないことと、主要failureのnext actionを固定した。

## 改善点

- GitHub App側のWebhook URLはまだ `https://example.com/github/webhook` のplaceholderである。
- runtimeの `GITHUB_WEBHOOK_SECRET` は未設定であり、GitHub App側secretとの一致確認も未完了である。
- 直近GitHub deliveryは502で失敗しており、2xx deliveryの証跡がない。
- local developmentではSolid Queue table未準備のため、worker smokeの合格証跡にはならない。
- staging / production-equivalent環境で `safe_failures` が空のJSON証跡は未取得である。

## 改善案

1. GitHub App settingsでWebhook URLをowned staging / production endpointの `/api/v1/webhooks/github` へ変更する。
2. GitHub App settingsのWebhook secretと同じ値をruntimeの `GITHUB_WEBHOOK_SECRET` へ設定する。
3. `scripts/github-webhook-live-smoke.rb --limit 5` を再実行し、`safe_failures` が空になることを確認する。
4. staging / production-equivalent環境でqueue schema適用済み `QUEUE_DATABASE_URL` を設定し、worker readiness scriptをRails runnerから再実行する。
5. 成功証跡をreview docへ保存し、GitHub Issue #4へ同期する。

## 優先順位

| 優先度 | 項目 | 理由 |
| --- | --- | --- |
| P0 | Webhook URLをowned endpointへ変更 | 現在はGitHub deliveryが到達できない |
| P0 | `GITHUB_WEBHOOK_SECRET` をruntimeへ設定 | 署名検証の信頼境界 |
| P0 | staging worker readinessで `safe_failures` 空を取得 | Issue #4のrelease gate |
| P1 | `next_actions` を運用Runbookの判定手順へ組み込む | 手作業ミスを減らす |
| P2 | deploy pipelineのoptional gate化 | 継続運用時の再現性を上げる |

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | release gate残件の外部設定待ちを安全に前進させる |
| Strategy | safe failure codeからoperator向けnext actionを生成する |
| Tactics | secret非出力、failure別mapping、RSpec、runbook追記 |
| Assessment | 診断の実用性は上がったが、実外部設定とstaging/prod証跡は未完了 |
| Conclusion | 改善は採用。ただしIssue #4は継続OPEN |
| Knowledge | smoke scriptは合否だけでなく、次の設定修正まで返すと運用負荷が下がる |

## STRIDE / OWASP観点

- Spoofing: webhook secret未設定は継続P0。`next_actions` で設定修正を明示した。
- Tampering: raw payloadを出力しない方針は維持している。
- Repudiation: 成功時はdelivery digest、DB保存、AuditLog同期の証跡が必要である。
- Information Disclosure: secret値、private key、signature、raw delivery id、DB URLは出力していない。
- Denial of Service: staging / production upstream guardとworker heartbeatは未確認である。
- OWASP A05 Security Misconfiguration: placeholder URLとsecret未設定は完了不可のblockerである。

## 検証結果

- `ruby -c scripts/github-webhook-live-smoke.rb`: Syntax OK
- `ruby -c scripts/solid-queue-worker-smoke-readiness.rb`: Syntax OK
- `bundle exec rspec spec/scripts/github_webhook_live_smoke_spec.rb spec/scripts/solid_queue_worker_smoke_readiness_spec.rb`: 5 examples, 0 failures
- `bundle exec rspec`: 405 examples, 0 failures
- `RAILS_ENV=test bundle exec rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、型生成OK
- `npm run display:check`: Display labels OK
- `npm run frontend:build`: success
- `npm run jwt:keyring:validate -- --file docs/release/examples/jwt-keyring.staging-smoke.example.json --environment staging --mode rotation --now 2026-07-06T00:30:00Z`: OK
- `git diff --check`: 問題なし
- `.env` 読込後の `ruby scripts/github-webhook-live-smoke.rb --limit 5`: exit 1
  - safe failures: `github_webhook_secret_missing`, `github_webhook_url_placeholder`, `github_webhook_recent_delivery_failed`
  - next actions: `GITHUB_WEBHOOK_SECRET` 設定、Webhook URL変更、delivery再送または再trigger
- Rails runner経由のlocal worker readiness: exit 1
  - safe failure: `solid_queue_tables_unavailable`
  - next action: staging / production-equivalent環境でqueue schema適用済み `QUEUE_DATABASE_URL` を設定して再実行

保存していない情報:

- GitHub App private key
- webhook secret
- signature
- raw payload
- raw GitHub delivery id
- `DATABASE_URL`
- `QUEUE_DATABASE_URL`
- Rails master key
- Active Record Encryption key
- raw exception / backtrace
- serialized job arguments

## 次アクション

1. GitHub App settingsのWebhook URLをowned endpointへ変更する。
2. runtimeへ `GITHUB_WEBHOOK_SECRET` を設定する。
3. GitHub deliveryを再送し、2xxとDB / AuditLog同期を確認する。
4. stagingでworker readiness scriptを実行し、`safe_failures` 空の証跡を保存する。
5. 成功後にIssue #4を再レビューし、クローズ可否を判断する。

## 結論

外部設定待ちのrelease gateに対して、operatorが迷わず次へ進むための診断改善は完了した。ただし、世界レベルSaaS基準では診断改善だけではIssue #4を完了扱いにできない。Webhook URL、webhook secret、2xx delivery、DB / AuditLog同期、staging / production worker heartbeatの証跡が揃うまでIssue #4は継続OPENとする。
