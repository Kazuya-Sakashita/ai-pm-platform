# ADR-0022: GitHub Webhook guardはpayload sizeをアプリで強制し、rate limitはアプリとupstreamの二層で扱う

## Status

Accepted

## Date

2026-07-07

## Context

ISSUE-067でGitHub App webhookの署名検証、delivery冪等性、installation同期を追加した。ISSUE-068ではwebhook secret rotationをcurrent / previous secret方式で定義した。

一方で、`POST /api/v1/webhooks/github` は公開endpointであり、巨大payloadや短時間の連続deliveryにより、raw body読み取り、HMAC計算、JSON parse、DB書き込み、AuditLog作成へ負荷がかかる可能性がある。

production公開前には、署名検証だけでなくDoS耐性の最低限の境界を持つ必要がある。

## Decision

MVP-to-betaでは以下を採用する。

- payload size guardはRails applicationで強制する。
- rate limitはRails applicationでbest-effort guardを持つ。
- productionではreverse proxy、platform、WAFのrate limitを主防御として扱い、Rails guardは最終防衛線にする。

環境変数:

- `GITHUB_WEBHOOK_MAX_BYTES`: webhook payload上限bytes。既定値は1 MiB。
- `GITHUB_WEBHOOK_RATE_LIMIT_PER_MINUTE`: remote IP単位の1分あたり上限。既定値は120。

処理順序:

1. `Content-Length` が上限を超える場合はbody読み取り前に413で拒否する。
2. remote IP単位のrate limitを確認し、超過時は429で拒否する。
3. `request.raw_post` を読み取る。
4. 実payload bytesizeが上限を超える場合は413で拒否する。
5. webhook signatureを検証する。
6. JSON parse、delivery冪等性、DB更新、AuditLog作成へ進む。

## Payload Size Limit

既定値は1 MiBとする。

理由:

- installation / installation_repositoriesのMVP処理に必要なpayloadとしては十分な余裕がある。
- JSON parse前に明確な失敗境界を作れる。
- 必要な場合は環境変数で増やせる。

size超過時:

- HTTP status: 413
- error code: `github_webhook_payload_too_large`
- safe detail: `GitHub Webhook payloadが上限を超えています。`

raw payload、signature、delivery id生値、secretは保存しない。

## Rate Limit

Rails側はremote IPをSHA-256 digest化したcache keyで固定window rate limitを行う。raw IPはDBやAuditLogへ保存しない。

既定値は120 requests / minuteとし、`GITHUB_WEBHOOK_RATE_LIMIT_PER_MINUTE` で調整できる。

rate limit超過時:

- HTTP status: 429
- error code: `github_webhook_rate_limited`
- safe detail: `GitHub Webhook requestが一時的に制限されています。`
- `Retry-After` headerを返す。

## Alternatives Considered

### upstreamのみ

不採用。

理由:

- local / staging / productionでguardの有無がぶれやすい。
- application code上の安全な副作用順序をRSpecで固定できない。

### Railsのみ

不採用。

理由:

- Rails processに到達する前の帯域、connection、body bufferingは守れない。
- 複数process / 複数instanceではcache store次第で厳密性が落ちる。

### delivery id単位のrate limit

不採用。

理由:

- delivery idを読む前にrate limitしたい。
- attackerはdelivery idを変えられるためDoS境界として弱い。
- delivery id生値を保存しない方針と相性が悪い。

## Consequences

良い点:

- 署名検証、JSON parse、DB副作用より前に過大payloadや過剰requestを拒否できる。
- OpenAPIで413 / 429を明示できる。
- RSpecで安全失敗と副作用なしを固定できる。
- productionではupstream guardを重ねる前提を明文化できる。

悪い点:

- Rails cache storeがprocess-localの場合、rate limitは厳密な全体上限にならない。
- GitHub正規deliveryの急増時に429を返す可能性があるため、閾値調整と運用監視が必要である。
- remote IP単位の制御はproxy設定に依存する。

## Follow-up

- ISSUE-004のlive smokeで413 / 429がraw secretやpayloadを保存しないことを確認する。
- production公開前にreverse proxy / platform側のbody size上限とrate limitを設定する。
- 将来、Redis等の共有cache storeを導入した場合はRails rate limitの精度を再評価する。
