# ワークフローエンドポイント認可カバレッジ設計レビュー

## 評価日時

2026-07-06 07:43:24 JST

## 評価担当

- Codex
- Security Engineer
- Backend Architect
- QA
- Tech Lead

外部AIレビュー: Claude/ChatGPTレビューは未実施。現時点ではCodex一次レビューとして保存し、外部AIレビュー結果が追加された場合は差分分析を追記する。

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010

## 対象

- Issue: ISSUE-048 / GitHub #48
- `backend/app/controllers/api/v1/meetings_controller.rb`
- `backend/app/controllers/api/v1/minutes_controller.rb`
- `backend/app/controllers/api/v1/requirements_controller.rb`
- `backend/app/controllers/api/v1/issue_drafts_controller.rb`
- `backend/app/controllers/api/v1/open_api_drafts_controller.rb`
- `backend/app/controllers/api/v1/integration_accounts_controller.rb`
- `backend/app/controllers/api/v1/reviews_controller.rb`
- `backend/app/controllers/api/v1/jobs_controller.rb`
- `backend/app/controllers/api/v1/operations_controller.rb`

## G-STACK

### Goal

古いワークフローエンドポイントの認証/認可差分をなくし、ProjectMembershipを一貫したproject authorization境界にする。

### Strategy

既存の `authorize_project!` を拡張し、read/write/review/admin相当のproject role policyを共通化する。controllerごとにprojectを辿り、未認証、非member、role不足、cross-projectをrequest specで検証する。

### Tactics

- 認可カバレッジ表を `docs/security/` に保存する。
- specを先に追加し、未認証/非member/role不足/cross-project拒否を固定する。
- OpenAPIに401/403とsecurity contractを反映する。
- callbackなどBearer authではない正当な例外はstate trustとして明記する。

### Assessment

現状はProjects/DM系と古いworkflow系で成熟度に差がある。Meetings、Minutes、Requirements、IssueDrafts、OpenApiDrafts、Reviews、Jobs、Operationsは未認証で重要情報の読み書きや外部副作用を起こせるため、世界レベルSaaS基準ではP0相当のsecurity gapである。

### Conclusion

ISSUE-048は実装に進める。ただし、単に `require_actor!` を足すだけでは不十分であり、project membership role、resourceのproject所属、OpenAPI契約、request spec、Frontend影響まで揃えなければ完了扱いにしない。

### Knowledge

- GitHub callbackはユーザーBearer authではなく、one-time stateとinstallation verificationが信頼境界である。
- Operations queue healthはglobal運用情報なので、project admin以上へ限定し、project contextを要求する。
- Review targetはresourceからprojectを推定できるものだけを自動許可し、project不明targetは `project_id` を必須にする。

## 良かった点

- ProjectMembership、JWT actor identity、session revoke/keyringが既に実装されている。
- DM系APIでは未認証、invalid token、spoofed `X-Actor-Id`、role不足のspecが先行しており、流用できる。
- OpenAPIにはBearer authとsafe auth error codeの基礎が存在する。

## 改善点

- 古いworkflow endpointsは未認証でも成功するspecが残っている。
- GitHub publish/reconciliation、OpenAPI validation、AI generationなど副作用の強い操作にrole gateがない。
- Reviewsがglobalにlist/create可能で、target project境界がない。
- Jobsがproject boundaryなしで閲覧できる。
- Operations queue healthが未認証で運用情報を返す。
- OpenAPIの401/403 contractが実装予定と完全には揃っていない。

## 優先順位

- P1: project role policyを共通化し、ワークフローエンドポイントへ適用する。
- P1: request specで未認証、非member、role不足、cross-project拒否を追加する。
- P1: OpenAPI security/401/403を更新し、`api:verify` を通す。
- P2: Review target project推定の対応targetを増やす。
- P2: Frontendでoperations queue healthのproject contextを明示する。

## 次アクション

1. 認可helperを追加する。
2. workflow controllersへproject role gateを適用する。
3. request specsを更新する。
4. OpenAPIを更新する。
5. Security/QA実装レビューを保存する。

## Issue番号

ISSUE-048 / GitHub #48
