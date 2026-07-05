# ISSUE-039: 実認証/JWT actor identity接続を実装する

## Issue番号

ISSUE-039

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/39

登録日: 2026-07-05
クローズ日: 2026-07-05
クローズPR: https://github.com/Kazuya-Sakashita/ai-pm-platform/pull/43
マージcommit: 5723385910ff1ac27fe7929b942a05bc7cd8ef20

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
- `docs/review/20260705_expert_subagent_pilot_issue_039_review.md`
- `docs/review/20260705_auth_jwt_actor_identity_design_review.md`
- `docs/review/20260705_auth_jwt_actor_identity_implementation_review.md`

## 関連ADR

- `docs/decisions/ADR-0016_jwt_actor_identity_for_api_audit.md`

## レビュー結果

Codex一次レビューでは、ISSUE-030はDM系APIのBroken Access Controlを下げる有効な一歩だが、`X-Actor-Id` は暫定入力であり、production-readyな認証境界とは言えない。JWT/sessionからactorを導出するまでは、なりすましと監査否認がP0残リスクとして残る。

2026-07-05に専門家サブエージェントレビューを実施した。Security/QA Agentは `X-Actor-Id` をproduction pathで信頼しないこと、JWT failure mode、AuditLog actor mapping、safe errorをP0条件にした。Backend/Frontend/Tech Lead AgentはProjects APIの未認証一覧/更新/削除を追加P0として指摘した。

2026-07-05に実装レビューを保存した。JWT verifier、OpenAPI ActorId除去、DM系APIのBearer token subject接続、Projects API最小認可、Frontend auth header、日本語401/403表示、request specを実装し、P0は対応済み。token revocation/session version/key rotationはISSUE-042、本格IdP/JWKS、全Project配下API authorizationは後続Issueへ送る。

## 実装結果

- `docs/decisions/ADR-0016_jwt_actor_identity_for_api_audit.md` を追加した。
- `Authentication::JwtVerifier` を追加し、HS256署名、issuer、audience、expiry、not-before、issued-at、clock skewを検証する。
- `ApplicationController#current_actor_id` をBearer JWT優先にし、productionでは `X-Actor-Id` を使わない。
- DM系APIはOpenAPIから `ActorId` header parameterを除去し、request specでmissing/malformed/bad signature/expired/not-yet-valid/wrong issuer/wrong audience/wrong algorithm/spoofed headerを固定した。
- Projects APIは認証必須にし、一覧はmembership済みprojectに限定し、更新/archiveはowner/adminだけに制限した。
- Frontend API clientは `NEXT_PUBLIC_AUTH_TOKEN` があればAuthorization headerを送信し、local/dev fallbackのみ `X-Actor-Id` を送る。
- 401/403の日本語表示を追加した。

## 検証結果

- `bundle exec rspec`: 208 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: success
- `npm run api:verify`: success
- `npm run display:check`: success
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 25 passed

## 優先度

P0

理由:

- `X-Actor-Id` を信頼するままではSpoofing/Elevation of Privilegeを防げない
- DM削除、承認、AI送信の監査証跡に直結する
- Project membership管理APIより先に実ユーザーidentityを固める必要がある

## 次アクション

1. GitHub Issue #39へ実装結果を同期する。
2. CI確認後にGitHub Issue #39をクローズする。
3. token revocation/session version/key rotationはISSUE-042で継続管理する。
4. 次はISSUE-040でmembership管理API/UIへ進める。
