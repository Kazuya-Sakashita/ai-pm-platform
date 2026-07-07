# ADR-0021: GitHub Webhook secret rotationはcurrent / previous secret方式を採用する

## Status

Accepted

## Date

2026-07-07

## Context

ISSUE-067でGitHub App webhookの署名検証を追加した。`POST /api/v1/webhooks/github` は `X-Hub-Signature-256` をraw bodyと `GITHUB_WEBHOOK_SECRET` で検証し、署名検証前にpayload保存やAuditLog作成をしない。

一方で、単一secretだけでは、staging / productionでsecretを交換する瞬間にGitHub側とアプリ側の設定差分が発生し、正当なdeliveryを拒否する可能性がある。secret漏えい時には即時封じ込めが必要だが、通常rotationではdelivery dropを最小化する必要がある。

## Decision

GitHub Webhook secret rotationは、MVP-to-betaではcurrent / previous secret方式を採用する。

環境変数:

- `GITHUB_WEBHOOK_SECRET`: current secret。通常時に検証するsecret。
- `GITHUB_WEBHOOK_PREVIOUS_SECRET`: rotation window中だけ許可するprevious secret。

署名検証では、current secretとprevious secretの両方でHMAC SHA-256を計算し、どちらかに一致すれば受理する。raw secret、raw signature、raw delivery id、raw payloadは保存しない。

## Rotation Window

通常rotationのprevious secret許容期間は、原則24時間以内とする。

許容期間の考え方:

- GitHub側のsecret変更直後に再送される旧secret署名deliveryを落としにくくする。
- deployment propagationやrollbackに耐える。
- 24時間を超えるprevious secret残留はSecurityレビュー対象にする。

productionでは、`GITHUB_WEBHOOK_PREVIOUS_SECRET` を設定したままrelease完了扱いにしない。release evidenceには、設定開始時刻、削除予定時刻、削除確認時刻、承認者、対象環境を保存する。

## Normal Rotation Procedure

1. 新secretをsecret storeへ登録する。
2. アプリ側に `GITHUB_WEBHOOK_SECRET=new`、`GITHUB_WEBHOOK_PREVIOUS_SECRET=old` を設定してdeployする。
3. GitHub App側のWebhook secretをnewへ変更する。
4. signed test deliveryまたはstaging smokeでnew secret署名が受理されることを確認する。
5. 旧secret署名の再送を一時的に受理できることを確認する。
6. 最大24時間以内に `GITHUB_WEBHOOK_PREVIOUS_SECRET` を削除してdeployする。
7. current secretだけでdeliveryを受理できることを確認する。
8. rotation evidenceをreviewまたはrelease docsへ保存する。

## Emergency Rotation Procedure

secret漏えい疑い、CI log露出、operator端末侵害、GitHub App管理者権限侵害が疑われる場合は、previous secretを設定しない。

1. 旧secretをGitHub App側とアプリ側の両方で即時無効化する。
2. `GITHUB_WEBHOOK_SECRET=new` のみをdeployする。
3. `GITHUB_WEBHOOK_PREVIOUS_SECRET` は設定しない。
4. GitHub webhook delivery失敗、権限同期停止、publish gate影響を確認する。
5. incident reviewへ影響範囲と再発防止策を保存する。

## Rollback

通常rotation中にnew secretでdeliveryを受理できない場合:

1. GitHub App側のWebhook secretをoldへ戻す。
2. アプリ側は `GITHUB_WEBHOOK_SECRET=old` に戻し、`GITHUB_WEBHOOK_PREVIOUS_SECRET` を削除する。
3. deliveryが受理されることを確認する。
4. rollback理由、開始/終了時刻、承認者、失敗原因をreviewへ保存する。

## Audit and Evidence

アプリはsecret値やsecret versionをdeliveryごとに保存しない。deliveryごとの保存対象は、ISSUE-067と同様にdelivery digest、event、installation id、repository、sync resultに限定する。

rotation evidenceには以下を保存する:

- rotation日時
- 対象環境
- 変更理由
- 承認者
- deploy commit SHA
- previous secret設定開始時刻
- previous secret削除予定時刻
- previous secret削除確認時刻
- signed test deliveryの結果
- secret漏えいがないことの確認

## Alternatives Considered

### Versioned keyring

不採用。

理由:

- GitHub webhook signature headerにはkey idが含まれず、JWTの `kid` のような明示的key選択ができない。
- keyring JSON schema、validation、deploy toolingが必要になり、ISSUE-068の範囲を超える。
- GitHub webhook secretは通常1つのsecretで運用されるため、MVP-to-betaではcurrent / previousで十分である。

### 即時切替のみ

不採用。

理由:

- deployment propagation中に正当なdeliveryを落とす可能性がある。
- GitHub側変更とアプリ側deployの順序に強く依存する。
- rollbackが難しい。

### previous secretを長期保持する

不採用。

理由:

- 漏えい時の攻撃可能期間が伸びる。
- rotation完了状態を監査できない。
- production release gateとして弱い。

## Consequences

良い点:

- 通常rotation中のdelivery dropを減らせる。
- 実装が小さく、OpenAPI影響がない。
- emergency rotationではprevious secretを使わないことで封じ込めを優先できる。
- runbookとreview evidenceにより運用監査へ接続できる。

悪い点:

- previous secretの削除は運用ゲートに依存する。
- secret versionをdeliveryごとに記録しないため、どのsecretで受理したかの詳細分析はできない。
- 将来、複数secretやsecret manager連携が必要になった場合はkeyring方式へ再設計が必要になる。

## Follow-up

- ISSUE-004のlive smokeで、rotation window中のsigned delivery受理を確認する。
- ISSUE-069でpayload sizeとrate limit guardを設計する。
- production deploy workflowにprevious secret残留チェックを追加するか検討する。
