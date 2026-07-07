# GitHub Webhook payload size / rate limit guard runbook

## 目的

GitHub App webhook endpointをproductionへ公開する前に、巨大payloadと短時間連打によるDoSリスクを下げる。

関連:

- ISSUE-069 / GitHub Issue #109
- ADR: `docs/decisions/ADR-0022_github_webhook_payload_rate_limit_guard.md`

## Guard方針

Rails application guard:

- `GITHUB_WEBHOOK_MAX_BYTES`: payload上限。既定値は1 MiB。
- `GITHUB_WEBHOOK_RATE_LIMIT_PER_MINUTE`: remote IP単位の1分あたり上限。既定値は120。

production upstream guard:

- reverse proxy / platformでbody size limitを設定する。
- `/api/v1/webhooks/github` にpath単位rate limitを設定する。
- upstreamの拒否logにもraw payload、signature、secret、delivery id生値を保存しない。

Rails guardは最終防衛線であり、productionの主防御はupstreamで行う。

## Release Gate

release前:

- OpenAPIに413 / 429が定義されている。
- request specでpayload超過とrate limit超過の副作用なしを確認している。
- `GITHUB_WEBHOOK_MAX_BYTES` と `GITHUB_WEBHOOK_RATE_LIMIT_PER_MINUTE` のproduction設定値が記録されている。
- upstream body size limitとrate limit設定の有無が記録されている。
- raw payload、signature、secret、delivery id生値を保存しないことを確認している。

release後:

- 正常なGitHub deliveryが202で受理される。
- 413 / 429がbaselineを超えていない。
- 429が継続する場合はGitHub delivery再送状況、upstream rate limit、app rate limitを確認する。

## Safe Evidence

保存してよい証跡:

- environment
- commit SHA
- 実行日時
- `GITHUB_WEBHOOK_MAX_BYTES` の数値
- `GITHUB_WEBHOOK_RATE_LIMIT_PER_MINUTE` の数値
- upstream guard有無
- HTTP status
- safe error code
- delivery digest
- conclusion

保存禁止:

- raw payload
- raw GitHub delivery id
- `X-Hub-Signature-256`
- webhook secret
- GitHub private key
- installation token

## 413確認

1. stagingで安全なtest payloadを使う。
2. `GITHUB_WEBHOOK_MAX_BYTES` より大きいbodyを送る。
3. 413 `github_webhook_payload_too_large` を確認する。
4. `GithubWebhookDelivery`、`AuditLog`、`IntegrationAccount` が更新されていないことを確認する。
5. raw payloadやsignatureがlogに残っていないことを確認する。

## 429確認

1. stagingで一時的に低い `GITHUB_WEBHOOK_RATE_LIMIT_PER_MINUTE` を設定する。
2. 同一remote IPからwindow内に上限を超えるrequestを送る。
3. 429 `github_webhook_rate_limited` と `Retry-After` headerを確認する。
4. 超過requestで `GithubWebhookDelivery`、`AuditLog`、`IntegrationAccount` が更新されていないことを確認する。
5. 確認後、production相当の閾値へ戻す。

## Rollback

正当なGitHub deliveryが誤って413 / 429になる場合:

1. `GITHUB_WEBHOOK_MAX_BYTES` または `GITHUB_WEBHOOK_RATE_LIMIT_PER_MINUTE` を一時的に緩和する。
2. upstream body size / rate limitも確認する。
3. GitHub delivery再送で202を確認する。
4. 緩和理由、開始/終了時刻、operator、commit SHA、safe error codeを `docs/review/` へ保存する。
