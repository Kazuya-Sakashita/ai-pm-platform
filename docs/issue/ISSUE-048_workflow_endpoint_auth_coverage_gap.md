# ISSUE-048: Workflow endpointsのauth coverage gapを解消する

## Issue番号

ISSUE-048

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/48

登録日: 2026-07-06

## 背景

ISSUE-039とISSUE-040でJWT actor identityとProjectMembership管理を導入したが、古いworkflow endpointsには未認証またはproject authorizationが弱いpathが残っている。Backend/Auth Architect Agentは、Meetings、Minutes、Requirements、IssueDrafts、OpenApiDrafts、Integrations、Reviews、Jobs、Operations周辺のauth coverage gapを別Issueとして解消すべきと指摘した。

## 目的

既存workflow endpointsの認証/認可coverageを洗い出し、OpenAPI、request specs、Frontend影響を含めて統一的に解消する。

## 完了条件

- 対象controllerごとのauth coverage matrixがある
- 未認証path、project ownership不明path、role不足pathが分類されている
- OpenAPI security/401/403 contractが実装と一致している
- request specで未認証、非member、role不足、cross-project拒否を検証している
- Frontendの影響と日本語表示が確認されている
- Security/QAレビューが `docs/review/` に保存されている

## スコープ

- Meetings
- Minutes
- Requirements
- IssueDrafts
- OpenApiDrafts
- Integrations
- Reviews
- Jobs
- Operations
- OpenAPI security contract
- request specs

## 非スコープ

- session/revocation/keyring backend implementation
- SSO/SAML
- Organization-wide RBAC
- billing plan制御

## 関連レビュー

- `docs/review/20260706_jwt_revocation_session_key_rotation_design_review.md`

## 関連ADR

- `docs/decisions/ADR-0017_jwt_revocation_session_key_rotation.md`

## レビュー結果

Backend/Auth Architect Agentは、ProjectMembershipで保護済みの新しいDM系APIと比較して、古いworkflow endpointsのauth coverageが不均一であると指摘した。ISSUE-045とは分離し、認証基盤の成熟後に既存API全体のcoverageを揃える。

## 優先度

P1

理由:

- endpointごとのauth差分は権限昇格と情報漏えいの原因になる
- OpenAPIと実装の乖離を放置するとAPI駆動開発の信頼が落ちる
- enterprise SaaSではauth coverage matrixとrequest specが必要である

## 次アクション

1. controllerごとのauth coverage matrixを作成する。
2. OpenAPI security contractをレビューする。
3. request specを先に追加してから実装を修正する。
