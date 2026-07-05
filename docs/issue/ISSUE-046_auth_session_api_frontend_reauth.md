# ISSUE-046: Auth session APIsとFrontend再ログイン導線を実装する

## Issue番号

ISSUE-046

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/46

登録日: 2026-07-06

## 背景

ISSUE-042で `token_revoked`、`session_revoked`、`session_version_stale` などのsafe auth error contractを定義した。しかし、Frontendには実session clear、再ログイン、session一覧、device revoke、logout everywhereの導線がない。

## 目的

Auth session APIsとFrontend再ログイン導線を実装し、失効/期限切れ/rotation後にユーザーが安全に復旧できるようにする。

## 完了条件

- current session logout APIがある
- session list APIがある
- device/session revoke APIがある
- logout everywhere APIがある
- admin forced revoke APIの扱いが定義されている
- Frontendがexpired/revoked/stale/retired key時にauth stateをclearし、再ログイン導線を表示する
- 日本語表示が整っている
- Playwrightでrevoked/expired sessionの復旧導線を検証している
- UX/Securityレビューが `docs/review/` に保存されている

## スコープ

- Auth session OpenAPI
- Backend session APIs
- Frontend reauth/reconnect UX
- display labels
- request specs
- Playwright E2E

## 非スコープ

- password auth
- external IdP login画面
- SSO/SAML/SCIM
- full user profile management

## 関連レビュー

- `docs/review/20260706_jwt_revocation_session_key_rotation_design_review.md`

## 関連ADR

- `docs/decisions/ADR-0017_jwt_revocation_session_key_rotation.md`

## レビュー結果

Security/DevOps Agentは、Frontendが失効時にtoken clear、再ログイン、再接続へ誘導できない点をP1/P2リスクとして指摘した。Backend/Auth Architect Agentは、session APIsをbackend foundation後に分離実装することを推奨した。

## 優先度

P1

理由:

- Backendでrevocationを実装しても、Frontend復旧導線がなければUXが破綻する
- session/device revokeはenterprise SaaSで期待される管理機能である
- 失効時の安全な日本語表示とE2E検証が必要である

## 次アクション

1. ISSUE-045完了後にOpenAPI設計レビューを行う。
2. Auth session APIsとFrontend導線を実装する。
3. revoked/expired/stale状態のE2Eを追加する。
