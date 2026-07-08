# ISSUE-004 live gate運用チェックリスト

## 目的

Issue #4をクローズする前に必要な外部設定と実環境証跡を、運用担当者が迷わず順番に確認できるようにする。

このチェックリストは既存runbookの短縮版であり、詳細手順は以下を参照する。

- `docs/release/20260704_github_app_live_smoke_runbook.md`
- `docs/release/20260704_solid_queue_staging_worker_smoke_runbook.md`
- `docs/review/20260708_issue004_live_gate_recheck_review.md`

## 現在のブロッカー

2026-07-08時点の再確認結果:

- runtimeの `GITHUB_WEBHOOK_SECRET` が未設定
- GitHub App webhook URLが `https://example.com/github/webhook` のplaceholder
- 直近GitHub deliveryが502
- local developmentはActiveJob adapterがasyncで、Solid Queue table未準備
- staging / production-equivalent worker readinessの合格証跡が未取得

## 完了条件

- GitHub App webhook URLがowned staging / production endpointの `/api/v1/webhooks/github` を指している
- GitHub App側のWebhook secretとruntimeの `GITHUB_WEBHOOK_SECRET` が一致している
- GitHub deliveryが2xxで成功している
- `GithubWebhookDelivery` とAuditLog同期を確認できる
- staging / production-equivalent環境でworker readiness scriptの `safe_failures` が空である
- secret、raw payload、raw delivery id、DB URL、job argumentsを証跡へ保存していない
- 結果レビューが `docs/review/` に保存され、GitHub Issue #4へ同期されている

## 手順1: GitHub App側のWebhook設定

GitHub AppのApp settingsで、Webhook設定を確認する。

設定対象:

- Webhook URL
- Webhook secret
- SSL verification
- Content type

期待値:

- Webhook URL: `https://<owned-staging-or-production-host>/api/v1/webhooks/github`
- Webhook secret: secret storeまたはruntimeへ設定する値と同じ
- SSL verification: enabled
- Content type: `application/json`

禁止:

- `https://example.com/github/webhook` のままにする
- repository settingsのInstalled Apps画面だけを確認して完了扱いにする
- Webhook secret値をIssue、PR、docs、AIチャット、スクリーンショットへ貼る

## 手順2: runtime secret設定

staging / production runtime、またはlive smoke対象runtimeへ `GITHUB_WEBHOOK_SECRET` を設定する。

local smokeで `.env` を使う場合:

```sh
GITHUB_WEBHOOK_SECRET=<GitHub App側と同じsecret>
```

backend起動時は `.env` を読み込む。

```sh
cd backend
set -a
source ../.env
set +a
PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec rails server -p 3001
```

確認:

```sh
cd ..
set -a
source .env
set +a
ruby scripts/github-webhook-live-smoke.rb --limit 5
```

期待値:

- `webhook_secret_configured`: true
- `hook_config.url`: owned endpoint
- `safe_failures`: 空

## 手順3: GitHub delivery再送

GitHub App settingsのRecent Deliveriesから、失敗deliveryをredeliverする。新しいeventを起こして再triggerしてもよい。

期待値:

- GitHub delivery statusが2xx
- app側が202を返す
- `safe_failures` が空
- delivery id生値ではなくdelivery digestだけを証跡へ保存

確認:

```sh
set -a
source .env
set +a
ruby scripts/github-webhook-live-smoke.rb --limit 5
```

## 手順4: DB / AuditLog同期確認

2xx delivery後、Rails runnerでsafe metadataだけを確認する。

```sh
cd backend
set -a
source ../.env
set +a
PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec ruby bin/rails runner '
deliveries = GithubWebhookDelivery.order(created_at: :desc).limit(5).map do |delivery|
  {
    id: delivery.id,
    delivery_digest_present: delivery.delivery_digest.present?,
    event: delivery.event,
    action: delivery.action,
    status: delivery.status,
    created_at: delivery.created_at.utc.iso8601
  }
end
audit_logs = AuditLog.where(action: "github.webhook.installation_sync").order(created_at: :desc).limit(5).map do |log|
  {
    id: log.id,
    action: log.action,
    created_at: log.created_at.utc.iso8601
  }
end
puts({ deliveries: deliveries, audit_logs: audit_logs }.to_json)
'
```

保存してよい情報:

- `delivery_digest_present`
- event
- action
- status
- created_at
- AuditLog id / action / created_at

保存してはいけない情報:

- raw delivery id
- webhook secret
- signature
- raw payload
- repository private data
- token

## 手順5: worker readiness確認

staging / production-equivalent環境で実行する。local developmentのasync adapter結果は、Issue #4の完了証跡として扱わない。

```sh
cd backend
bundle exec ruby bin/rails runner ../scripts/solid-queue-worker-smoke-readiness.rb \
  --smoke-environment staging \
  --production-like \
  --expect-solid-queue \
  --require-worker
```

期待値:

- `active_job_adapter` がSolid Queueを示す
- `secret_presence.queue_database_url`: true
- Solid Queue主要tableがすべてtrue
- worker heartbeatが存在し、staleではない
- recurring taskがconfiguredかつloaded
- `safe_failures`: 空

## safe failure対応表

| safe failure | 対応 |
| --- | --- |
| `github_webhook_secret_missing` | runtimeへ `GITHUB_WEBHOOK_SECRET` を設定し、backendを再起動する |
| `github_webhook_url_placeholder` | GitHub App settingsのWebhook URLをowned endpointへ変更する |
| `github_webhook_recent_delivery_failed` | URLとsecret設定後にdeliveryをredeliverまたは再triggerする |
| `github_webhook_insecure_ssl_enabled` | GitHub App settingsでSSL verificationを有効にする |
| `solid_queue_tables_unavailable` | staging / production-equivalent環境でqueue schema適用済み `QUEUE_DATABASE_URL` を設定する |
| `active_job_adapter_not_solid_queue` | production-like環境のActiveJob adapterをSolid Queueへ設定する |
| `worker_heartbeat_missing` | worker processをweb processと別に起動する |
| `recurring_task_missing` | worker / scheduler起動と `backend/config/recurring.yml` を確認する |

## 保存するレビュー項目

`docs/review/YYYYMMDD_issue004_live_gate_evidence_review.md` として保存する。

- 評価日時
- 評価担当
- 使用フレームワーク
- commit SHA
- 環境名
- GitHub repository
- webhook delivery digest
- delivery status code
- `GithubWebhookDelivery` safe summary
- AuditLog safe summary
- worker readiness safe JSON summary
- 良かった点
- 改善点
- 優先順位
- 次アクション
- Issue番号: ISSUE-004 / GitHub Issue #4

## クローズ判定

Issue #4は、以下がすべて揃った場合だけクローズ候補にする。

- GitHub App connect / publish / reconcile smokeが成功している
- webhook delivery smokeが2xxで成功している
- `GithubWebhookDelivery` とAuditLog同期が確認できている
- staging / production-equivalent worker readinessが合格している
- secret漏えいがない
- review docとGitHub Issue commentへ証跡が同期されている

どれか1つでも未完了なら、Issue #4はOPENを継続する。
