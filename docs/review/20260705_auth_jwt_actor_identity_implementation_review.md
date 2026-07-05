# Auth JWT actor identity implementation review

## 評価日時

2026-07-05 17:56:01 JST

## 評価担当

Codex as Review Orchestrator / Security Engineer / QA / CTO / Tech Lead / Backend Architect / Frontend Architect / DevOps

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- DDD
- OpenAPI
- ISO25010

## Issue番号

- ISSUE-039
- GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/39

## 評価対象

- `docs/decisions/ADR-0016_jwt_actor_identity_for_api_audit.md`
- `docs/api/openapi.yaml`
- `backend/app/services/authentication/jwt_verifier.rb`
- `backend/app/controllers/application_controller.rb`
- `backend/app/controllers/api/v1/projects_controller.rb`
- `backend/spec/requests/api/v1/conversation_imports_spec.rb`
- `backend/spec/requests/api/v1/projects_spec.rb`
- `frontend/lib/api/client.ts`
- `frontend/app/workspace-client.tsx`
- `frontend/lib/display-labels.ts`

## 参加Agent

| Agent | Mode | 判定 |
| --- | --- | --- |
| Security Engineer + QA Agent | Codex subagent Ramanujan | 条件付き合格 |
| Backend + Frontend + Tech Lead Agent | Codex subagent Boole | 条件付き合格 |
| Review Orchestrator | Codex primary | 条件付き合格 |

## 良かった点

- `X-Actor-Id` をproduction pathで信頼しない方針をADRに保存し、OpenAPIのproduction contractからDM系ActorId headerを除去した。
- JWT verifierは `HS256` allowlist、署名、`sub`、`iss`、`aud`、`exp`、`nbf`、`iat`、clock skewを検証する。
- DM系APIはBearer tokenのsubjectをPolicy ObjectとAuditLogへ接続し、spoofed `X-Actor-Id` がBearer tokenを上書きできないことをrequest specで固定した。
- Projects APIにも最小限のactor境界を追加し、一覧はactive membershipだけ、更新/archiveはowner/adminだけに制限した。
- Frontend API clientは `NEXT_PUBLIC_AUTH_TOKEN` があればAuthorization headerを送り、local/dev fallbackのみ `X-Actor-Id` を使う構成に移行した。
- 401/403の日本語表示を追加し、再ログイン/権限切れが英語のまま露出しないようにした。

## 改善点

- server-side revocation、session version、`jti`、key rotationはまだ未実装であり、漏えいした短命tokenの即時失効はできない。
- local/dev fallbackとして `X-Actor-Id` を残しているため、production環境変数とRails.envの誤設定をCI/CDで検出する運用が必要である。
- 本格的なユーザー管理、IdP/JWKS、SSO/SAML、SCIMはまだ非スコープである。
- Frontendの再ログイン導線は表示文言レベルであり、実ログイン画面、token refresh、session復旧はまだ未実装である。
- Meetings、IntegrationsなどProject配下の他APIにはまだProject-level authorizationが十分に広がっていない。

## 優先順位

| Priority | 指摘 | 対応 |
| --- | --- | --- |
| P0 | 任意headerによるDM操作のspoofing | ISSUE-039で対応 |
| P0 | AuditLog actor_idがclient入力に依存するリスク | ISSUE-039で対応 |
| P0 | JWT failure modeの未検証 | ISSUE-039で対応 |
| P1 | token revocation/session version/key rotation | 後続Issue化 |
| P1 | 本番IdP/JWKS/SSO接続 | 後続ロードマップ |
| P1 | Project配下API全体のauthorization拡張 | ISSUE-040以降で対応 |

## 次アクション

1. ISSUE-039の台帳を実装完了状態へ更新する。
2. token revocation/session version/key rotationを後続Issueとして切り出す。
3. GitHub Issue #39へ実装結果と検証結果を同期する。
4. CIが通過したらGitHub Issue #39をクローズする。
5. 次はISSUE-040でmembership管理API/UIへ進める。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | DM/Project操作のactor identityを認証済みJWT subjectへ接続する |
| Strategy | ADR、OpenAPI、JWT verifier、request spec、Frontend auth headerを一気通貫で揃える |
| Tactics | HS256 JWT、safe 401/403、Policy Object再利用、AuditLog mapping、local/dev fallback |
| Assessment | P0 spoofingと監査否認は大きく低下。revocationと本格IdPは後続に残る |
| Conclusion | ISSUE-039は条件付きで完了可能。後続IssueとCI確認を必須にする |
| Knowledge | AI PMの監査価値は、AI生成物だけでなく「誰の認証済み権限で実行されたか」を追跡できることにある |

## STRIDE / OWASP観点

| 観点 | 評価 | 対応状況 |
| --- | --- | --- |
| Spoofing | `X-Actor-Id` spoofingはproduction pathで排除 | 対応済み |
| Tampering | `alg=none`、署名不一致、改ざんpayloadを拒否 | 対応済み |
| Repudiation | AuditLog actor_idをJWT subjectへ接続 | 対応済み |
| Information Disclosure | token/claim/DM本文をauth errorへ出さない | 対応済み |
| Elevation of Privilege | Bearer token subjectだけでmembership判定 | 対応済み |
| OWASP A01 | Broken Access Control | DM/Project最小境界は改善、全API展開は後続 |
| OWASP A07 | Identification and Authentication Failures | JWT失敗系をrequest specで固定 | 対応済み |
| OWASP A09 | Security Logging and Monitoring Failures | AuditLog actor mappingを改善 | 対応済み |

## 検証結果

- `bundle exec rspec`: 208 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: success
- `npm run api:verify`: success
- `npm run display:check`: success
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 25 passed

## 判定

条件付き合格。ISSUE-039のP0であるspoofing、JWT failure、AuditLog actor mapping、OpenAPI contract、Frontend auth headerは満たした。revocation/session version/key rotation、本格IdP、全Project配下API authorizationは後続Issueで扱う。

## AIレビュー比較

Codex primary、Codex subagent Ramanujan、Codex subagent Booleの指摘を統合した。RamanujanはSecurity/QA failure mode、BooleはProjects API境界とFrontend auth providerを重視した。衝突はなく、BooleのProjects API指摘を追加scopeとして採用した。Claude、ChatGPTなど外部AIレビューは未実施。
