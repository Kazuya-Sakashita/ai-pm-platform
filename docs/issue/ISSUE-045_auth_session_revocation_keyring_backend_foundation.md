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

## 関連ADR

- `docs/decisions/ADR-0017_jwt_revocation_session_key_rotation.md`

## レビュー結果

Security/DevOps Agentは、漏えいtokenとkey compromiseの封じ込めをP1として指摘した。Backend/Auth Architect Agentは、`auth_actors`、`auth_sessions`、`auth_token_revocations`、`security_events` を段階導入し、legacy JWT互換をfeature flagで閉じるmigration planを提案した。

## 優先度

P1

理由:

- token失効とkey rotationはenterprise trustに直結する
- ISSUE-046以降のsession UI/APIの前提になる
- production公開前にauth lifecycleの封じ込めを実装する必要がある

## 次アクション

1. OpenAPI contractに沿ってDB/API設計レビューを実施する。
2. migration/model/serviceを実装する。
3. request/service specでsafe failureを固定する。
