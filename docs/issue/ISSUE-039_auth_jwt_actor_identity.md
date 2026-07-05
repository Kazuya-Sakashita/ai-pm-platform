# ISSUE-039: 実認証/JWT actor identity接続を実装する

## Issue番号

ISSUE-039

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/39

登録日: 2026-07-05

## 背景

ISSUE-030でDM系APIにproject membershipとPolicy Objectを導入し、`X-Actor-Id` による暫定actor識別を実装した。ただしproductionではクライアントが送信する任意ヘッダーを信頼できないため、実ユーザー認証済みのJWT/sessionからactor identityを導出する必要がある。

世界レベルSaaS基準では、DM本文、AI整理draft、削除/承認操作の監査ログが「認証済みユーザー」に結び付いていなければ、なりすまし、否認、権限昇格のリスクが残る。

## 目的

APIのactor identityをJWTまたは同等の認証済みコンテキストから導出し、`X-Actor-Id` 依存をproduction blockerとして解消する。

## 完了条件

- 認証方式のADRが `docs/decisions/` に保存されている
- OpenAPIのsecurity schemeがJWT/session前提へ更新されている
- Backendが認証済みユーザーからactor idを導出し、任意の `X-Actor-Id` をproduction pathで信頼しない
- DM系APIで未認証、期限切れtoken、不正token、project非memberをsafe errorで拒否するrequest specがある
- AuditLogのactor_idが認証済みuser idに接続される
- Frontend API clientが認証ヘッダーを扱い、権限切れ時の日本語再ログイン導線を表示する
- STRIDE/OWASP Top 10レビューが `docs/review/` に保存されている

## スコープ

- 認証方式ADR
- Backend認証middleware/controller helper
- OpenAPI security scheme更新
- DM系APIのactor identity置換
- request spec
- Frontend API clientの認証ヘッダー対応
- safe error response
- 監査ログ検証

## 非スコープ

- SSO/SAML
- SCIM
- 課金プラン別権限
- Organization横断RBAC
- 外部IdP本番設定

## 関連レビュー

- `docs/review/20260705_discord_dm_project_membership_policy_design_review.md`
- `docs/review/20260705_discord_dm_project_membership_policy_implementation_review.md`
- `docs/review/20260705_auth_membership_followup_issue_split_review.md`

## レビュー結果

Codex一次レビューでは、ISSUE-030はDM系APIのBroken Access Controlを下げる有効な一歩だが、`X-Actor-Id` は暫定入力であり、production-readyな認証境界とは言えない。JWT/sessionからactorを導出するまでは、なりすましと監査否認がP0残リスクとして残る。

## 優先度

P0

理由:

- `X-Actor-Id` を信頼するままではSpoofing/Elevation of Privilegeを防げない
- DM削除、承認、AI送信の監査証跡に直結する
- Project membership管理APIより先に実ユーザーidentityを固める必要がある

## 次アクション

1. 認証方式ADRを作成する。
2. OpenAPI security schemeをJWT/session前提へ更新する。
3. Backend request specで未認証/不正token/project非memberを先に定義する。
4. 実装後、Frontendの再ログイン導線とAuditLog接続を検証する。
