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
- `docs/review/20260706_workflow_endpoint_auth_coverage_design_review.md`
- `docs/review/20260706_workflow_endpoint_auth_coverage_implementation_review.md`

## 関連ADR

- `docs/decisions/ADR-0017_jwt_revocation_session_key_rotation.md`

## レビュー結果

Backend/Auth Architect Agentは、ProjectMembershipで保護済みの新しいDM系APIと比較して、古いworkflow endpointsのauth coverageが不均一であると指摘した。ISSUE-045とは分離し、認証基盤の成熟後に既存API全体のcoverageを揃える。

2026-07-06 実装レビュー:

- `docs/security/20260706_workflow_endpoint_auth_coverage_matrix.md` にcontroller別のproject boundary、必要role、例外扱いを整理した。
- `ApplicationController` にproject role policyを共通化し、Meetings、Minutes、Requirements、IssueDrafts、OpenApiDrafts、IntegrationAccounts、Reviews、Jobs、Operationsへ適用した。
- GitHub callbackはBearer authではなくone-time signed stateを信頼境界とする例外として維持した。
- Operations queue healthは `project_id` 必須かつowner/admin限定へ変更した。
- Reviewsはtarget resourceからprojectを推定し、project不明のglobal list/createを拒否する方針に変更した。
- OpenAPIへ401/403/404/422と `project_id` query contractを反映し、Frontend schemaを同期した。
- request specsで未認証、非member、role不足、cross-project拒否を追加した。
- Frontendのqueue health呼び出しを選択project context付きに更新し、E2E route stubをquery付きURLに対応させた。

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

## 実装結果

完了。

### 主な変更

- Workflow endpointsをProjectMembership境界で保護した。
- read/write/review/admin相当のrole policyを共通化した。
- 外部副作用のあるGitHub publish/reconciliation、integration connect/disconnect、operations queue healthをowner/adminへ限定した。
- OpenAPI contractとgenerated frontend schemaを更新した。
- Backend request specsとFrontend E2Eを更新した。

### 検証結果

- `bundle exec rspec spec/requests/api/v1/meetings_spec.rb spec/requests/api/v1/minutes_spec.rb spec/requests/api/v1/requirements_spec.rb spec/requests/api/v1/issue_drafts_spec.rb spec/requests/api/v1/open_api_drafts_spec.rb spec/requests/api/v1/reviews_spec.rb spec/requests/api/v1/integration_accounts_spec.rb spec/requests/api/v1/jobs_spec.rb spec/requests/api/v1/operations_spec.rb`: 81 examples, 0 failures
- `bundle exec rspec`: 269 examples, 0 failures
- `npm run api:verify`: success
- `npm run display:check`: success
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 29 passed

### 残リスク

- Claude/ChatGPTなど外部AIレビューは未実施。現時点ではCodex一次レビューとして保存した。
- organization/global admin RBAC、IdP/SSO、billing entitlementは非スコープ。
- Review target対応は現行workflow resource中心であり、将来target type追加時にproject boundary mappingを必須化する必要がある。
