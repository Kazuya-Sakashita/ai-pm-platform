# ISSUE-045: Auth session/revocation/keyring backend foundationを実装する

## Issue番号

ISSUE-045

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/45

登録日: 2026-07-06

## 背景

ISSUE-042でJWT revocation、session version、key rotationの設計を行い、短命JWTだけでは漏えいtokenの即時失効、device単位失効、logout everywhere、key compromise封じ込めができないと評価した。

## 目的

server-side auth stateとkeyringを実装し、JWTをproduction運用に耐える認証基盤へ進める。

## 完了条件

- `auth_actors`、`auth_sessions`、`auth_token_revocations`、`security_events` のDB migration/modelがある
- JWT header `kid`、claims `sid/sv/jti` を検証できる
- keyringがactive、verify-only、retired、disabled keyを扱える
- session revoked、session version stale、revoked `jti`、unknown/retired keyをsafe 401で拒否する
- raw token、raw `jti`、secretをDB/log/API responseへ保存しない
- request specとservice specで失効、rotation、legacy互換境界を検証している
- Security/Backendレビューが `docs/review/` に保存されている

## スコープ

- DB migration/model
- Authentication keyring
- Session authenticator
- Token revocation lookup
- Security event recorder
- OpenAPIとの整合
- request/service specs

## 非スコープ

- Frontend session management UI
- SSO/SAML/SCIM
- external IdP/JWKS本番接続
- billing plan別session制御

## 関連レビュー

- `docs/review/20260706_jwt_revocation_session_key_rotation_design_review.md`
- `docs/review/20260706_auth_session_keyring_design_review.md`
- `docs/review/20260706_auth_session_keyring_implementation_review.md`

## 関連ADR

- `docs/decisions/ADR-0017_jwt_revocation_session_key_rotation.md`

## レビュー結果

Security/DevOps Agentは、漏えいtokenとkey compromiseの封じ込めをP1として指摘した。Backend/Auth Architect Agentは、`auth_actors`、`auth_sessions`、`auth_token_revocations`、`security_events` を段階導入し、legacy JWT互換をfeature flagで閉じるmigration planを提案した。

2026-07-06に実装前レビューを保存した。既存token発行導線が未整備のため、session claim必須化はfeature flagにし、`sid/sv/jti` 付きtokenではDB-backed validationへ入る段階導入とした。

2026-07-06にSecurity/QA AgentとBackend/Auth Architect Agentの専門家サブエージェントレビューを実施した。Security/QA Agentはinvalid Bearerが `X-Actor-Id` fallbackへ落ちるリスクをP0として指摘した。Backend/Auth Architect Agentは、既存controller contractを維持しつつrich auth contextを追加する実装方針を推奨した。

## 実装結果

- `auth_actors`、`auth_sessions`、`auth_token_revocations`、`security_events` を追加した。
- `Authentication::Keyring` を追加し、`active`、`verify_only`、`retired`、`disabled` keyを扱えるようにした。
- `AUTH_JWT_KEYRING_JSON` で `secret_env` または `secret` を読み込めるようにした。
- `Authentication::SessionAuthenticator` を追加し、`sid/sv/jti`、session status、actor status、session version、revoked `jti` を検証するようにした。
- `Authentication::JwtVerifier` を拡張し、`kid`、keyring、max TTL、session authenticatorを扱えるようにした。
- `JwtVerifier::Result` に `auth_session`、`jti_digest`、`kid` を追加した。
- Authorization headerがある場合、Bearer検証失敗後にlegacy `X-Actor-Id` fallbackへ落ちないようにした。
- `filter_parameter_logging` に `authorization`、`jti`、`jti_digest` を追加した。
- request/service/model specsでkeyring、session revoked、session stale、revoked `jti`、invalid Bearer fallback禁止、raw `jti` 非保存を検証した。

## 検証結果

- `bundle exec rspec spec/services/authentication/jwt_verifier_spec.rb spec/requests/api/v1/authentication_session_spec.rb spec/models/authentication_foundation_spec.rb`: 22 examples, 0 failures
- `bundle exec rspec spec/requests/api/v1/projects_spec.rb spec/requests/api/v1/project_memberships_spec.rb spec/requests/api/v1/conversation_imports_spec.rb spec/requests/api/v1/conversation_summary_drafts_spec.rb spec/services/authentication/jwt_verifier_spec.rb spec/requests/api/v1/authentication_session_spec.rb spec/models/authentication_foundation_spec.rb`: 74 examples, 0 failures
- `bundle exec rspec`: 239 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: success
- `npm run api:verify`: success
- `npm run display:check`: success
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 26 passed

## 優先度

P1

理由:

- token失効とkey rotationはenterprise trustに直結する
- ISSUE-046以降のsession UI/APIの前提になる
- production公開前にauth lifecycleの封じ込めを実装する必要がある

## 次アクション

1. GitHub Issue #45へ実装結果を同期する。
2. PRを作成し、CI成功後にマージする。
3. マージ後にGitHub Issue #45をクローズする。
4. 後続としてISSUE-046、ISSUE-047、ISSUE-048を進める。
