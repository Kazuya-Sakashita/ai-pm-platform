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
- `docs/review/20260706_auth_session_api_frontend_reauth_design_review.md`
- `docs/review/20260706_auth_session_api_frontend_reauth_implementation_review.md`

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

1. PRを作成し、CI成功後にマージする。
2. GitHub Issue #46をクローズする。
3. 次はISSUE-047でJWT key rotation staging smoke / production runbook gateを進める。

## 実装結果

実装日: 2026-07-06

- OpenAPIへAuth session contractを追加した。
- `GET /auth/sessions` でcurrent actorのsafe session listを返すようにした。
- `DELETE /auth/sessions/current` でcurrent session logoutを実装した。
- `DELETE /auth/sessions/{auth_session_id}` で本人所有sessionのdevice revokeを実装した。
- `POST /auth/logout-everywhere` で本人scopeのactive sessions revokeとsession version incrementを実装した。
- Auth session APIsはsession-backed JWT必須とし、legacy `X-Actor-Id` やsession claimsなしJWTでは `invalid_token` で拒否する。
- `security_events` にsession revoke / logout everywhereをsafe metadataで記録する。
- Frontend API client middlewareでauth terminal error codeを検知し、local auth state clearと再ログインイベントを発火する。
- Frontendはauth lock時にserver由来/入力中stateをclearし、通常ワークスペースを描画しない。
- Playwrightで初回401、background401、session list、other session revoke、current logout、mobile overflowを検証した。

## 検証結果

- `bundle exec rspec spec/requests/api/v1/auth_sessions_spec.rb spec/requests/api/v1/authentication_session_spec.rb`: 8 examples, 0 failures
- `bundle exec rspec spec/requests/api/v1/auth_sessions_spec.rb spec/requests/api/v1/authentication_session_spec.rb spec/services/authentication/jwt_verifier_spec.rb spec/models/authentication_foundation_spec.rb`: 27 examples, 0 failures
- `bundle exec rspec`: 244 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: success
- `npm run api:verify`: success
- `npm run display:check`: success
- `npm run frontend:build`: success
- `npm run frontend:e2e -- e2e/auth-session.spec.ts`: 3 passed
- `npm run frontend:e2e`: 29 passed

## 未完了・後続

- admin forced revokeはglobal admin/organization role modelがないため、ISSUE-046ではpublic API化しない。
- refresh token / external IdP login画面は非スコープであり、後続Issueで扱う。
- device labelは未実装。raw User-Agentを保存せずに粗いdevice labelを扱う設計が必要である。

## クローズ記録

- GitHub Issue状態: CLOSED
- GitHub Issue URL: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/46
- PR: https://github.com/Kazuya-Sakashita/ai-pm-platform/pull/51
- Merge commit: `04ccaa4`
- クローズ確認日時: 2026-07-06 07:22:35 JST
- クローズ理由: Auth session APIs、Frontend再ログイン導線、session revoke/logout everywhere、safe auth lock E2E、レビュー保存が完了したため。
