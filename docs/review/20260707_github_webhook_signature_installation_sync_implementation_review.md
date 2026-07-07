# 2026-07-07 GitHub Webhook署名検証とinstallation状態同期 実装レビュー

## 評価日時

2026-07-07 20:58:00 JST

## 評価担当

Codex as Security Engineer / Backend Architect / Tech Lead / QA

専門サブエージェント:

- Arendt: Security Engineer
- Curie: Backend Architect / QA

外部AIレビュー: 未実施。Claude / ChatGPT等の外部AIレビューは追加待ち。

## Issue番号

ISSUE-067 / GitHub Issue #106

## 対象成果物

- `backend/config/routes.rb`
- `backend/app/controllers/api/v1/webhooks_controller.rb`
- `backend/app/models/github_webhook_delivery.rb`
- `backend/app/services/github_integration/webhook_error.rb`
- `backend/app/services/github_integration/webhook_signature_verifier.rb`
- `backend/app/services/github_integration/webhook_processor.rb`
- `backend/db/migrate/20260707203500_create_github_webhook_deliveries.rb`
- `backend/spec/requests/api/v1/webhooks_spec.rb`
- `backend/spec/services/github_integration/webhook_signature_verifier_spec.rb`
- `docs/api/openapi.yaml`
- `frontend/lib/api/schema.d.ts`

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- QA回帰テスト

## 評価サマリー

ISSUE-067として、GitHub App webhook受信経路を実装した。`POST /api/v1/webhooks/github` は認証トークンではなくGitHub署名で保護し、`X-Hub-Signature-256` をraw bodyと `GITHUB_WEBHOOK_SECRET` でHMAC SHA-256検証する。検証前にJSON parse、DB保存、AuditLog作成を行わない。

delivery冪等性は `GithubWebhookDelivery` にSHA-256 digestで保存する。raw delivery id、raw payload、signature、secretはDB、AuditLog、APIレスポンスへ保存しない。`installation.deleted` / `installation.suspend` は対象installationの `IntegrationAccount` を `revoked` へ同期し、`installation_repositories.removed` は対象repositoryだけを `revoked` へ同期する。`new_permissions_accepted` などの権限更新でIssues writeが失われた場合は `error` と `last_error_safe` を保存し、既存publish gateが公開を止められる状態にする。

## G-STACK評価

### Goal

GitHub Appの権限失効やrepository access変更を安全に同期し、古いconnected状態のまま自動公開を続けない。

### Strategy

Controllerを薄く保ち、署名検証、delivery記録、event処理、IntegrationAccount更新、AuditLog保存をServiceへ分離する。

### Tactics

- `WebhooksController#github` はraw bodyとheadersをServiceへ渡し、202またはsafe errorを返す。
- `WebhookSignatureVerifier` はconstant time compareで署名を検証する。
- `WebhookProcessor` はallowlist eventだけを処理し、未対応eventはignoredにする。
- `GithubWebhookDelivery` はdelivery digest uniqueで重複処理を止める。
- AuditLog metadataはdelivery digest、event、installation id、repository、sync statusに限定する。

### Assessment

対象RSpec 10件、GitHub連携周辺回帰 19件、Zeitwerk、OpenAPI検証が成功した。SecurityサブエージェントのP0指摘である「署名検証前の副作用禁止」「delivery冪等性」「safe metadata」「権限失効同期」は実装で採用した。

### Conclusion

実装は合格。PR作成とGitHub Actions `verify` 確認へ進めてよい。実GitHub webhook live delivery smokeは実credentialと到達可能URLが必要なため、ISSUE-004のrelease gateとして継続する。

### Knowledge

webhookの価値はイベントを受けることではなく、外部側の権限状態が変化した瞬間に安全に止まれることにある。AI PMの自動公開機能では、この停止能力がプロダクト信頼性の一部になる。

## 良かった点

- 署名検証前にJSON parse、DB保存、AuditLog作成をしない構成にした。
- delivery idは生値を保存せず、SHA-256 digestのみ保存・返却する。
- raw payload、signature、secret、delivery id生値をAuditLogに保存しないことをRSpecで確認した。
- 重複deliveryは `duplicate_ignored` として副作用を増やさない。
- repository removedでは対象repositoryだけを失効させ、同じinstallationの別repositoryを維持する。
- Issues write権限喪失を `error` に同期し、公開gateと整合しやすい状態にした。
- OpenAPIとFrontend生成型を同期した。

## 改善点

- GitHub webhook live delivery smokeは未実施で、実GitHub payloadの差分はまだ検証できていない。
- secret rotationは未実装で、現行secret単独検証である。
- payload size limitとrate limitingはRails / upstream設定に依存しており、明示的なapp-level guardは未実装である。
- webhook処理は同期実行であり、将来イベント数が増える場合はJob化を検討する必要がある。
- `github.webhook.installation_sync` actionに集約しており、将来UIで細かく見るならactionを分ける余地がある。

## 優先順位

| 優先度 | 対応 | 理由 |
| --- | --- | --- |
| P0 | GitHub Actions `verify` を確認 | main反映前の品質ゲート |
| P0 | 実GitHub webhook live delivery smokeをISSUE-004で実施 | 実payloadと到達性の証跡が必要 |
| P1 | webhook secret rotation方針をADR化 | 運用時のsecret更新に備える |
| P1 | payload size / rate limit guardを検討 | 公開endpointのDoS耐性を上げる |
| P2 | webhook actionの監査ログ分類を細分化 | 運用UIでの検索性を上げる |

## 次アクション

1. PRを作成し、GitHub Actions `verify` を確認する。
2. CI成功後にGitHub Issue #106をクローズする。
3. ISSUE-004側に、webhook live delivery smokeが残ることを維持する。
4. Secret rotationとpayload size guardは後続Issue候補として検討する。

## 検証結果

- `bundle exec rails db:migrate`: success
- `RAILS_ENV=test bundle exec rails db:migrate`: success
- `bundle exec rspec spec/services/github_integration/webhook_signature_verifier_spec.rb spec/requests/api/v1/webhooks_spec.rb`: 10 examples, 0 failures
- `bundle exec rspec spec/requests/api/v1/integration_accounts_spec.rb spec/services/github_issue_publish/github_app_provider_spec.rb spec/services/issue_draft_publish_gate_spec.rb`: 19 examples, 0 failures
- `bundle exec rspec`: 385 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run display:check`: Display labels OK
- `npm run frontend:build`: success
- `git diff --check`: success

## AIレビュー比較

ArendtのSecurityレビューでは、署名検証前の副作用禁止、delivery id冪等性、installation revoked同期、permissions changed同期、AuditLog情報漏えい防止がP0として示された。実装ではすべて採用した。

CurieのBackend/QAレビューでは、Controllerを薄くし、Serviceとdelivery modelを新設する方針、認証なし署名必須、既存 `IntegrationAccount` と `AuditLog.record!` の利用、最小request specが提案された。実装では `WebhooksController`、`WebhookSignatureVerifier`、`WebhookProcessor`、`GithubWebhookDelivery` に分離して採用した。

差分として、サブエージェント案ではraw delivery id保存も候補にあったが、Security by Designを優先してdigest保存に変更した。これはraw delivery idをAPIレスポンスやAuditLogへ出さないための安全側判断である。

## Rails責務分離

- Controller: raw bodyとheadersの受け渡し、safe error response、202 responseに限定した。
- Model: `GithubWebhookDelivery` はdelivery digest、event、statusの保存ルールに限定した。
- Service: 署名検証は `WebhookSignatureVerifier`、event処理と状態同期は `WebhookProcessor` に分離した。
- 過剰設計回避: webhook event数が少ないため、eventごとのStrategy classや非同期Jobは追加しなかった。
- テスト方針: 署名検証Service単体、request specで外部入力から状態同期までを固定した。

## 判定

合格。

PR作成とCI確認へ進んでよい。実GitHub webhook live delivery smokeは本Issueの完了条件ではなく、ISSUE-004のrelease gateとして残す。
