# ISSUE-004 live gate再確認レビュー

## 評価日時

2026-07-09 05:00:30 JST

## 評価担当

- Codex
- CTO
- DevOps
- Security Engineer
- QA
- Product Manager

## Issue番号

- ISSUE-004
- GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/4

## 対象

- `scripts/github-webhook-live-smoke.rb --limit 5`
- `scripts/solid-queue-worker-smoke-readiness.rb`
- `docs/release/20260708_issue004_live_gate_operator_checklist.md`
- `docs/evaluation/20260709_issue004_github_webhook_live_smoke_recheck.json`
- `docs/evaluation/20260709_issue004_solid_queue_worker_smoke_readiness_local.json`

## 使用フレームワーク

- G-STACK
- STRIDE
- ISO25010
- DORA Metrics
- MoSCoW

## 実施内容

Issue #4の残release gateであるGitHub webhook live delivery smokeとSolid Queue worker smoke readinessを再確認した。

GitHub webhook側はApp IDとprivate keyは設定済みだが、runtime `GITHUB_WEBHOOK_SECRET` が未設定で、GitHub App webhook URLが `https://example.com/github/webhook` のplaceholderのままだった。直近deliveryも502であり、live delivery smokeは未合格である。

Solid Queue worker側はlocal developmentでreadiness scriptを実行した。ActiveJob adapterはasyncで、Solid Queue tableも未準備のため、staging / production-equivalent worker smoke証跡としては未合格である。

## 良かった点

- GitHub App IDとprivate keyは引き続き設定済みであることを確認できた。
- GitHub App側ではWebhook secret自体は設定済みとして確認できた。
- delivery id生値ではなくdelivery digestのみを証跡化できた。
- worker readiness scriptはlocal developmentをproduction証跡として誤判定せず、安全に未合格として停止できた。
- `next_actions` により、運用担当者が次に直すべき設定が明確である。

## 改善点

- runtime `GITHUB_WEBHOOK_SECRET` が未設定のため、GitHub App側secretとアプリ側検証secretが一致していない。
- GitHub App webhook URLがplaceholderのため、GitHubからアプリへdeliveryが到達しない。
- Recent deliveriesがすべて502であり、2xx deliveryの証跡がない。
- local developmentのActiveJob adapterはasyncであり、Solid Queue worker heartbeatを確認できない。
- staging / production-equivalent環境でのqueue schema、worker heartbeat、recurring task loaded状態の証跡がまだない。

## 改善案

- GitHub App settingsのWebhook URLをowned staging / production endpointの `/api/v1/webhooks/github` へ変更する。
- GitHub App側のWebhook secretと同じ値をruntime `GITHUB_WEBHOOK_SECRET` へ設定し、backendを再起動する。
- 設定後にRecent Deliveriesからredeliverまたは再triggerし、2xx deliveryを確認する。
- 2xx delivery後に `GithubWebhookDelivery` と `AuditLog` のsafe metadataだけをRails runnerで確認する。
- staging / production-equivalent環境で `QUEUE_DATABASE_URL` とSolid Queue schemaを用意し、worker heartbeatとrecurring taskを確認する。

## 優先順位

| 優先度 | 対応 | 理由 |
| --- | --- | --- |
| P0 | secret、raw payload、signature、raw delivery idを保存しない | webhook検証の情報漏えい防止に必須 |
| P1 | Webhook URLをowned endpointへ変更する | GitHub deliveryが到達しない直接原因 |
| P1 | runtime `GITHUB_WEBHOOK_SECRET` を設定する | signature検証が成立しないため |
| P1 | staging / production-equivalent worker readinessを取得する | Issue #4のrelease gate |
| P2 | DB / AuditLog safe確認を実施する | delivery受信後のプロダクト同期確認に必要 |

## G-STACK

### Goal

Issue #4をクローズできるrelease gate証跡を取得する。

### Strategy

外部設定待ちのgateをsafe scriptで再確認し、未解消の設定差分を明確にする。

### Tactics

- GitHub App webhook設定とrecent deliveryをsafe JSONで確認する。
- Solid Queue worker readinessをRails runner経由で確認する。
- secret、raw payload、signature、raw delivery id、DB URLを保存しない。
- 未合格の場合はIssue台帳とレビューへ次アクションを残す。

### Assessment

現時点ではWebhook URLとruntime secretが未整備で、worker smokeもlocal development結果のみであるため、Issue #4はクローズ不可。

### Conclusion

Issue #4はOPEN継続。次はGitHub App settingsとruntime環境の外部設定を完了させたうえで、2xx deliveryとstaging / production-equivalent worker readinessを取得する。

### Knowledge

2026-07-09時点で、GitHub webhook live smokeのsafe failuresは `github_webhook_secret_missing`、`github_webhook_url_placeholder`、`github_webhook_recent_delivery_failed` である。worker readinessのsafe failuresは `solid_queue_tables_unavailable`、`active_job_adapter_not_solid_queue` である。

## STRIDE観点

| 観点 | リスク | 対応 |
| --- | --- | --- |
| Spoofing | webhook secret未設定により署名検証できない | runtime `GITHUB_WEBHOOK_SECRET` を設定する |
| Tampering | placeholder URLによりdelivery検証が成立しない | owned endpointへ変更し、2xx deliveryを確認する |
| Repudiation | delivery受信証跡が残らない | delivery digest、DB、AuditLogをsafe確認する |
| Information Disclosure | raw payloadやsignatureがdocsへ混入する | safe script outputのみ保存する |
| Denial of Service | worker未稼働で非同期処理が詰まる | worker heartbeatとqueue latencyを確認する |
| Elevation of Privilege | local development結果をrelease gate合格扱いにする | staging / production-equivalent証跡を必須にする |

## ISO25010観点

- 信頼性: 現時点ではdelivery 2xxとworker heartbeatが未確認のため不足。
- セキュリティ: secretやraw payloadを保存せず、safe evidenceに限定できている。
- 運用性: `next_actions` により外部設定の不足点が明確である。
- 保守性: reviewとevaluationを分離し、次回再確認しやすい。
- 可用性: worker smokeが未合格のため、production運用前の確認が必要。

## DORA Metrics観点

- Deployment frequency: release gate未合格のため本番リリース頻度向上には未寄与。
- Lead time for changes: 外部設定待ちがボトルネック。
- Change failure rate: webhook未到達とworker未確認は失敗率を高めるリスク。
- MTTR: safe failureとnext actionsにより復旧手順は明確化されている。

## MoSCoW

| 区分 | 内容 |
| --- | --- |
| Must | Webhook URL変更、runtime secret設定、2xx delivery確認 |
| Must | staging / production-equivalent worker readiness合格 |
| Should | DB / AuditLog safe metadata確認 |
| Could | production observation-onlyの初回証跡取得 |
| Won't | local developmentのasync adapter結果をrelease gate合格扱いにする |

## 次アクション

1. GitHub App settingsのWebhook URLをowned staging / production endpointの `/api/v1/webhooks/github` へ変更する。
2. GitHub App側のWebhook secretと同じ値をruntime `GITHUB_WEBHOOK_SECRET` へ設定する。
3. GitHub deliveryをredeliverまたは再triggerし、2xx deliveryを確認する。
4. `GithubWebhookDelivery` と `AuditLog` のsafe metadataだけを確認する。
5. staging / production-equivalent環境でworker readinessを実行し、`safe_failures` 空の証跡を保存する。

## 検証結果

- GitHub webhook live smoke: safe failuresあり
- GitHub webhook safe failures: `github_webhook_secret_missing`、`github_webhook_url_placeholder`、`github_webhook_recent_delivery_failed`
- Solid Queue worker readiness local: safe failuresあり
- Solid Queue safe failures: `solid_queue_tables_unavailable`、`active_job_adapter_not_solid_queue`
- 保存していない情報: webhook secret、signature、raw payload、raw delivery id、private key、DB URL

## 結論

Issue #4はクローズ不可。実装側のsafe checkは機能しているが、外部設定とstaging / production-equivalent証跡が不足している。次に進めるにはGitHub App webhook URL、runtime secret、worker実行環境の設定が必要である。
