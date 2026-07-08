# 2026-07-08 ISSUE-004 live gate再確認レビュー

## 評価日時

2026-07-08 19:00:51 JST

## 評価担当

Codex / DevOps / Security Engineer / QA / Tech Lead

## Issue番号

ISSUE-004 / GitHub Issue #4

## 対象

- `scripts/github-webhook-live-smoke.rb`
- `scripts/solid-queue-worker-smoke-readiness.rb`
- `docs/issue/ISSUE-004_github_issue_and_openapi_pipeline.md`

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- DORA Metrics
- ISO25010

## 評価サマリー

Issue #4の残タスクであるGitHub webhook live delivery smokeとstaging / production worker smokeについて、現時点のreadinessを再確認した。

GitHub webhook側は、App IDとprivate keyは設定済みで、GitHub App側にはwebhook secretが設定されている。一方で、runtimeの `GITHUB_WEBHOOK_SECRET` は未設定、Webhook URLは `https://example.com/github/webhook` のplaceholder、直近deliveryは502で失敗している。したがってlive delivery smokeは未合格である。

Solid Queue worker側はlocal developmentで確認したが、ActiveJob adapterがasync、Solid Queue table未準備のため、staging / production worker smokeの合格証跡にはならない。stagingまたはproduction-equivalent環境でqueue schema適用済み `QUEUE_DATABASE_URL` を設定して再実行する必要がある。

## 良かった点

- GitHub App IDとprivate keyは設定済みで、GitHub App APIからhook configとdelivery履歴を確認できた。
- GitHub App側のwebhook secret設定有無は確認でき、secret値そのものは保存していない。
- delivery id生値ではなくdigestで証跡化できている。
- webhook smokeとworker readinessの両方で `next_actions` が出力され、次の設定修正が明確である。
- secret、raw payload、raw delivery id、DB URL、Rails master keyは出力していない。

## 改善点

- runtimeの `GITHUB_WEBHOOK_SECRET` が未設定で、署名検証の信頼境界がまだ成立していない。
- Webhook URLがplaceholderのため、GitHub deliveryが実backendへ到達しない。
- 直近deliveryはすべて502で、2xx delivery証跡がない。
- local developmentはSolid Queue adapter / queue table条件を満たしておらず、staging / production worker smokeの代替にならない。
- `GithubWebhookDelivery` とAuditLogへのlive同期成功証跡がまだない。

## 改善案

1. GitHub App settingsのWebhook URLをowned staging / production endpointの `/api/v1/webhooks/github` へ変更する。
2. GitHub App側のWebhook secretと同じ値をruntimeの `GITHUB_WEBHOOK_SECRET` へ設定する。
3. GitHub deliveryをredeliverまたは再triggerし、2xx deliveryを確認する。
4. 2xx後に `GithubWebhookDelivery` とAuditLog同期を確認する。
5. staging / production-equivalent環境でSolid Queue schema適用済み `QUEUE_DATABASE_URL` を設定し、worker readinessを再実行する。

## 優先順位

| 優先度 | 項目 | 理由 |
| --- | --- | --- |
| P0 | `GITHUB_WEBHOOK_SECRET` をruntimeへ設定 | webhook署名検証の必須条件 |
| P0 | Webhook URLをowned endpointへ変更 | delivery到達性の必須条件 |
| P0 | 2xx deliveryとDB / AuditLog同期の証跡取得 | Issue #4のlive gate |
| P0 | staging worker readinessで `safe_failures` 空を取得 | release gate |
| P1 | production observation-only smoke | 本番影響を抑えて運用証跡を取得するため |

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | Issue #4のクローズ可否をlive gateから判断する |
| Strategy | safe readiness scriptで外部設定と実環境証跡を切り分ける |
| Tactics | webhook config、delivery digest、worker readiness、next actionsを確認する |
| Assessment | 設定確認は進んだが、webhook secret、URL、2xx delivery、staging worker証跡が未完了 |
| Conclusion | Issue #4は継続OPEN |
| Knowledge | live gateは実装済みコードよりも、外部設定と実到達証跡の不足で止まることが多い |

## STRIDE / OWASP観点

- Spoofing: `GITHUB_WEBHOOK_SECRET` 未設定のため、署名検証前提のlive gateは未完了である。
- Tampering: Webhook URLがplaceholderで、正しいbackend endpointへの到達が未確認である。
- Repudiation: 2xx delivery、`GithubWebhookDelivery`、AuditLog同期の監査証跡がまだない。
- Information Disclosure: secret、private key、signature、raw payload、raw delivery id、DB URLは保存していない。
- Denial of Service: 502 deliveryが続いており、delivery到達性は未合格である。
- OWASP A05 Security Misconfiguration: placeholder URLとruntime secret未設定はP0 blockerである。

## 検証結果

- `.env` 読込後の `ruby scripts/github-webhook-live-smoke.rb --limit 5`: exit 1
  - `app_id_configured`: true
  - `private_key_configured`: true
  - `webhook_secret_configured`: false
  - GitHub App hook URL: `https://example.com/github/webhook`
  - GitHub App secret configured: true
  - safe failures: `github_webhook_secret_missing`, `github_webhook_url_placeholder`, `github_webhook_recent_delivery_failed`
- Rails runner経由の `scripts/solid-queue-worker-smoke-readiness.rb --smoke-environment local --no-production-like`: exit 1
  - Rails env: development
  - ActiveJob adapter: async
  - Solid Queue tables: unavailable
  - safe failures: `solid_queue_tables_unavailable`, `active_job_adapter_not_solid_queue`

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

1. GitHub App settingsでWebhook URLをowned staging / production endpointへ変更する。
2. runtimeへ `GITHUB_WEBHOOK_SECRET` を設定する。
3. GitHub deliveryをredeliverまたは再triggerし、2xx deliveryを確認する。
4. `GithubWebhookDelivery` とAuditLog同期を確認する。
5. staging / production-equivalent環境でworker readiness scriptを実行し、`safe_failures` が空の証跡を保存する。

## 結論

Issue #4の主要実装は完了済みだが、live gateはまだ未合格である。世界レベルSaaS基準では、Webhook URL、runtime secret、2xx delivery、DB / AuditLog同期、staging worker readinessの証跡が揃うまで、Issue #4をクローズしてはならない。
