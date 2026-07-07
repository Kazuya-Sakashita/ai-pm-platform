# 2026-07-07 GitHub Webhook payload size / rate limit guard 設計レビュー

## 評価日時

2026-07-07 21:20:00 JST

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

- `docs/issue/ISSUE-069_github_webhook_payload_rate_limit_guard.md`
- `backend/app/controllers/api/v1/webhooks_controller.rb`
- `backend/app/services/github_integration/webhook_processor.rb`
- `backend/app/services/github_integration/webhook_signature_verifier.rb`
- `docs/api/openapi.yaml`
- `docs/decisions/ADR-0022_github_webhook_payload_rate_limit_guard.md`

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- ADR

## 評価サマリー

GitHub Webhook endpointは認証済みユーザーAPIではなく、署名検証を認証境界にする公開endpointである。署名検証だけでは巨大payloadや短時間連打への防御として不足するため、payload size guardとrate limit guardを署名検証、JSON parse、DB副作用より前に置く必要がある。

payload sizeはRails applicationで明示的に強制し、rate limitはRails側best-effortとupstream guardの二層にする方針が妥当である。

## G-STACK評価

### Goal

GitHub Webhook endpointで巨大payloadと短時間連打を安全に拒否し、production公開前のDoS耐性を上げる。

### Strategy

Controller前段に小さなguard serviceを追加し、OpenAPI、RSpec、runbookで413 / 429と副作用なしを固定する。rate limitはRails単体を過信せず、productionではreverse proxy / platform側を主防御にする。

### Tactics

- `GITHUB_WEBHOOK_MAX_BYTES` でpayload size上限を設定する。
- `GITHUB_WEBHOOK_RATE_LIMIT_PER_MINUTE` でremote IP単位のbest-effort rate limitを設定する。
- Content-Length超過はbody読み取り前に413で拒否する。
- 実payload bytesize超過も署名検証前に413で拒否する。
- rate limit超過は429と `Retry-After` で返す。
- raw IP、raw delivery id、raw payload、signature、secretは保存しない。

### Assessment

設計は副作用順序を改善し、OWASP A05 Security MisconfigurationとA04 Insecure Designのリスクを下げる。一方でRails cache storeに依存するrate limitは分散環境で厳密ではないため、productionではupstream guardが必須である。

### Conclusion

実装へ進んでよい。完了条件はADR、guard service、OpenAPI 413/429、RSpec、runbook、実装レビューを満たすこと。

### Knowledge

WebhookのDoS対策は署名検証だけでは足りない。署名検証に入る前のbody size、request頻度、safe error、証跡非保存を含めて設計する必要がある。

## STRIDE評価

| 脅威 | リスク | 対策 |
| --- | --- | --- |
| Spoofing | 不正requestが署名検証CPUを消費する | rate limitを署名検証前に配置 |
| Tampering | Content-Length不一致で想定外payloadを通す | raw body取得後にbytesizeを再確認 |
| Repudiation | guard拒否の理由が追えない | safe error codeとHTTP statusを返す。secretやpayloadは保存しない |
| Information Disclosure | payloadやsignatureをエラー証跡へ保存する | raw payload、signature、delivery id生値を保存しない |
| Denial of Service | 巨大payloadや連打でJSON parse / DBに負荷 | 413 / 429で副作用前に拒否 |
| Elevation of Privilege | guard bypassで処理順序が崩れる | Controllerからguardを必ず呼び出す |

## L2サブエージェントレビュー比較

### Aquinas / Security Engineer

判定: 条件付き合格。

主な指摘:

- production公開時はupstream制限なしではP0条件付きリスクである。
- payload sizeはRails到達前のbody size limitとRails内の二重確認が必要である。
- rate limitは署名検証、JSON parse、DB保存より前に置く。
- 重複deliveryはJSON parse前にdelivery digestで確認すると再送時のparse costを抑えられる。
- `IntegrationAccount` 更新とAuditLogは将来transaction化を検討する。

採用:

- Rails guardを最終防衛線、upstream guardをproduction主防御としてADRとrunbookに明記する。
- duplicate delivery checkをJSON parse前へ移動する。
- 413 / 429時にdelivery、AuditLog、IntegrationAccount副作用なしをRSpecで固定する。

保留:

- GitHub IP allowlist、Redis / Rack::Attack、event別schema validation、非同期Job化は後続Issueで扱う。
- DB更新とAuditLogのtransaction化はISSUE-069の主目的外のため、後続改善候補にする。

### Gibbs / Backend Architect / QA

判定: 条件付き合格。

主な指摘:

- Controllerへguardロジックを直書きせず、`GithubIntegration::WebhookRequestGuard` としてService分離する。
- `Content-Length` とraw body bytesizeの二段確認が必要である。
- OpenAPIには413 `PayloadTooLarge` と429 `RateLimited` を追加する。
- RSpecではpayload超過、rate limit超過、上限ちょうど、store注入、設定値不正を確認する。
- `GithubWebhookDelivery` はdelivery記録・status・TTL cleanup程度に留め、rate limit責務を持たせない。

採用:

- `WebhookRequestGuard` と `WebhookRateLimiter` をServiceとして追加する。
- OpenAPIへ413 / 429を追加する。
- Request specとService specを追加する。

保留:

- TTL cleanup jobは保存件数とproduction運用状況を見て後続で判断する。

## 良かった点

- 既存の署名検証とdelivery冪等性を壊さずに前段guardを追加できる。
- OpenAPIに413 / 429を明示できる。
- Rails側とupstream側の責務を分けている。
- raw secret、signature、payloadを保存しない方針と整合している。

## 改善点

- productionのreverse proxy / platform具体設定は未確定である。
- Rails cacheがprocess-localの場合、rate limitは厳密な全体制御にならない。
- GitHub正規deliveryが一時的に増えるケースへの閾値調整手順が必要である。

## 優先順位

| 優先度 | 対応 | 理由 |
| --- | --- | --- |
| P0 | size / rate guardを署名検証・JSON parse・DB副作用より前に置く | DoSと副作用防止 |
| P0 | raw payload / signature / secret非保存 | 情報漏えい防止 |
| P1 | OpenAPIへ413 / 429を追加 | API contract明確化 |
| P1 | RSpecで413 / 429と副作用なしを固定 | 回帰防止 |
| P1 | runbookへupstream guardと証跡方針を追加 | production運用 |

## 次アクション

1. `WebhookRequestGuard` を追加する。
2. `WebhooksController#github` でguardを署名検証前に呼ぶ。
3. OpenAPIへ413 / 429を追加する。
4. Service spec / Request specを追加する。
5. runbookとIssue台帳を更新する。
6. 実装レビューを保存する。

## 判定

条件付き合格。

実装、RSpec、runbook、実装レビューを追加すればISSUE-069は完了可能である。production upstream guardの具体設定はrelease gateとして継続する。
