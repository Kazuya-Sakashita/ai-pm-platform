# 2026-07-07 GitHub Webhook payload size / rate limit guard 実装レビュー

## 評価日時

2026-07-07 21:45:00 JST

## 評価担当

Codex L1ロール分離レビュー

- Security Engineer
- DevOps
- Backend Architect
- QA

Codex L2サブエージェントレビュー:

- Aquinas: Security Engineer / DoS観点
- Gibbs: Backend Architect / QA観点

外部AIレビュー: 未実施。Claude / ChatGPT等の外部AIレビューは追加待ち。

## Issue番号

ISSUE-069 / GitHub Issue #109

## 対象成果物

- `backend/app/controllers/api/v1/webhooks_controller.rb`
- `backend/app/services/github_integration/webhook_request_guard.rb`
- `backend/app/services/github_integration/webhook_rate_limiter.rb`
- `backend/app/services/github_integration/webhook_processor.rb`
- `backend/app/services/github_integration/webhook_error.rb`
- `backend/spec/services/github_integration/webhook_request_guard_spec.rb`
- `backend/spec/requests/api/v1/webhooks_spec.rb`
- `docs/api/openapi.yaml`
- `frontend/lib/api/schema.d.ts`
- `docs/decisions/ADR-0022_github_webhook_payload_rate_limit_guard.md`
- `docs/release/20260707_github_webhook_payload_rate_limit_guard_runbook.md`

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- QA回帰テスト

## 評価サマリー

GitHub Webhook endpointに、payload size guardとremote IP単位のbest-effort rate limitを追加した。guardは署名検証、JSON parse、`GithubWebhookDelivery` 作成、AuditLog作成、`IntegrationAccount` 更新より前に実行される。

payload sizeは `Content-Length` とraw body bytesizeの二段確認にした。rate limitはRails cacheを使い、test / fallbackではprocess-local memory storeを使う。productionではupstreamのbody size limitとrate limitを主防御にする方針をADRとrunbookで明記した。

また、重複deliveryはJSON parse前にdelivery digestで確認するようにし、GitHub再送や同一delivery再到達時のparse負荷を下げた。

## G-STACK評価

### Goal

巨大payloadと短時間連打を副作用前に拒否し、公開webhook endpointのDoS耐性を上げる。

### Strategy

Controllerの冒頭で薄くguard serviceを呼び、判定ロジックは `GithubIntegration::WebhookRequestGuard` と `WebhookRateLimiter` に分離する。OpenAPIとRSpecで413 / 429 contractを固定する。

### Tactics

- `GITHUB_WEBHOOK_MAX_BYTES` を追加し、既定値を1 MiBにした。
- `GITHUB_WEBHOOK_RATE_LIMIT_PER_MINUTE` を追加し、既定値を120 requests / minuteにした。
- 413 `github_webhook_payload_too_large` を追加した。
- 429 `github_webhook_rate_limited` と `Retry-After` headerを追加した。
- 重複deliveryをJSON parse前に `duplicate_ignored` へ分岐した。
- Request specで413 / 429時にdelivery、AuditLog、IntegrationAccount副作用がないことを固定した。

### Assessment

実装はSecurity/Backend/QAレビュー方針に沿っている。Rails内rate limitは分散環境では厳密でないため、production release gateではupstream guardの設定確認が必要である。

### Conclusion

実装は合格。GitHub Actions `verify` が通ればISSUE-069はクローズ可能である。

### Knowledge

DoS耐性は「処理を失敗させる」だけでは不十分である。どの副作用より前に失敗させるか、どの情報を保存しないか、どの層を主防御にするかを合わせて固定する必要がある。

## 良かった点

- guardをControllerに直書きせずServiceに分離した。
- Content-Lengthと実payload bytesizeの二段確認にした。
- rate limitを署名検証とJSON parseより前に置いた。
- 413 / 429をOpenAPIへ追加した。
- raw payload、signature、secret、delivery id生値を保存しない方針を維持した。
- 重複deliveryのJSON parseを避ける改善を入れた。

## 改善点

- productionのupstream body size / rate limit設定は未実施である。
- Rails rate limitはcache store次第でprocess-localになり、分散環境では厳密ではない。
- `GithubWebhookDelivery` のTTL cleanupは未実装であり、signed unsupported event大量到達時の長期保存対策は後続検討である。
- `IntegrationAccount` 更新とAuditLogのtransaction化は未実装である。

## 優先順位

| 優先度 | 対応 | 理由 |
| --- | --- | --- |
| P0 | productionでupstream guardを設定 | Rails到達前の主防御 |
| P0 | raw payload / signature / secret非保存を維持 | 情報漏えい防止 |
| P1 | GitHub Actions `verify` 成功確認 | main反映前の品質ゲート |
| P1 | ISSUE-004で413 / 429 live smoke evidenceを取得 | 実環境確認 |
| P2 | TTL cleanupとtransaction化を検討 | 長期運用強化 |

## 次アクション

1. PRを作成し、GitHub Actions `verify` を確認する。
2. CI成功後にGitHub Issue #109をクローズする。
3. ISSUE-004のlive smokeで413 / 429のsafe evidenceを取得する。
4. production platform確定後にupstream guard設定をrelease gateへ追加する。

## 検証結果

- `bundle exec rspec spec/services/github_integration/webhook_request_guard_spec.rb spec/services/github_integration/webhook_signature_verifier_spec.rb spec/requests/api/v1/webhooks_spec.rb`: 24 examples, 0 failures
- `bundle exec rspec`: 399 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK / Redocly valid / schema generated
- `npm run display:check`: Display labels OK
- `npm run frontend:build`: success
- `git diff --check`: success

補足: `npm run api:verify` ではNode.js version警告が出たが、OpenAPI lintと型生成は成功した。

## AIレビュー比較

Codex L1とL2サブエージェントレビューは一致した。

- 一致点: guardは署名検証、JSON parse、DB副作用より前に置く。
- 一致点: ControllerではなくServiceへ分離する。
- 一致点: productionではupstream guardを主防御にする。
- 追加採用: Aquinasの指摘により、重複delivery checkをJSON parse前へ移動した。
- 保留: TTL cleanup、Redis / Rack::Attack、GitHub IP allowlist、transaction化は後続候補とした。

## Rails責務分離

- Controller: `WebhooksController#github` はguard呼び出し、raw body取得、署名検証、processor呼び出し、responseに限定した。
- Service: `WebhookRequestGuard` にpayload size判定を、`WebhookRateLimiter` にrate limit判定を分離した。
- Processor: delivery id digestと重複判定をJSON parse前に移動した。
- Model: `GithubWebhookDelivery` にsize/rate責務は持たせなかった。
- 過剰設計回避: Rack::Attack、Redis、WAF、TTL jobはproduction platform確定前の過剰導入として見送った。
- テスト方針: Service specでguard単体、Request specで副作用なしとHTTP contract、OpenAPI型生成で契約同期を確認した。

## 判定

条件付き合格。

ローカル検証とGitHub Actions `verify` が通れば完了可能である。production upstream guardとlive smoke evidenceはISSUE-004のrelease gateとして継続する。
