# ワークフローエンドポイント認可カバレッジ実装レビュー

## 評価日時

2026-07-06 08:05:56 JST

## 評価担当

Codexレビュー統括 / Security Engineer / Backend Architect / Frontend Architect / QA / Tech Lead

外部AIレビュー: Claude/ChatGPTレビューは未実施。現時点ではCodex一次レビューとして保存し、外部AIレビュー結果が追加された場合は差分分析を追記する。

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- DDD

## Issue番号

ISSUE-048 / GitHub #48

## 評価対象

- `docs/security/20260706_workflow_endpoint_auth_coverage_matrix.md`
- `docs/api/openapi.yaml`
- `backend/app/controllers/application_controller.rb`
- `backend/app/controllers/api/v1/meetings_controller.rb`
- `backend/app/controllers/api/v1/minutes_controller.rb`
- `backend/app/controllers/api/v1/requirements_controller.rb`
- `backend/app/controllers/api/v1/issue_drafts_controller.rb`
- `backend/app/controllers/api/v1/open_api_drafts_controller.rb`
- `backend/app/controllers/api/v1/integration_accounts_controller.rb`
- `backend/app/controllers/api/v1/reviews_controller.rb`
- `backend/app/controllers/api/v1/jobs_controller.rb`
- `backend/app/controllers/api/v1/operations_controller.rb`
- `backend/spec/requests/api/v1/*_spec.rb`
- `frontend/app/workspace-client.tsx`
- `frontend/e2e/auth-session.spec.ts`
- `frontend/e2e/meeting-workspace.spec.ts`
- `frontend/e2e/queue-health.spec.ts`
- `frontend/lib/api/schema.d.ts`

## 良かった点

- ProjectMembershipをワークフローエンドポイントの共通authorization境界として採用し、read/write/review/admin相当のrole policyを `ApplicationController` に集約した。
- Meetings、Minutes、Requirements、IssueDrafts、OpenApiDrafts、IntegrationAccounts、Reviews、Jobs、Operationsの未認証/非member/cross-project/role不足をrequest specで固定した。
- GitHub publish/reconciliation、integration connect/disconnect、operations queue healthなど外部副作用または運用情報を伴う操作をowner/adminへ限定した。
- Reviewsはtarget resourceからprojectを推定し、globalなlist/createを避ける実装に変えた。
- GitHub callbackはBearer authではなくone-time signed stateを信頼境界にする例外として、matrixとreviewに明記した。
- OpenAPIへ401/403/404/422とoperations queue healthの `project_id` queryを反映し、generated schemaを同期した。
- Frontendは選択project context付きでqueue healthを取得し、E2E route stubもquery付きURLに対応した。

## 改善点

- role policyはcontroller helperに集約した段階であり、将来Organization、Team、Billing entitlementが入るとpolicy objectまたはauthorization libraryへの分離が必要になる。
- Review targetのproject boundary mappingは現行workflow resource中心で、target type追加時に漏れが起きやすい。
- Operations queue healthはproject admin限定にしたが、platform-wide運用者やbreak-glass adminの権限モデルはまだない。
- GitHub callbackはstate trustのまま妥当だが、live GitHub App smokeとcallback failure AuditLogの完全検証は別Issueの継続課題である。
- OpenAPIにauth error responseは増えたが、roleごとの許可表を機械検証するcontract testはまだない。
- Claude/ChatGPTなど外部AIレビュー比較は未実施である。

## 優先順位

| Priority | 指摘 | 対応 |
| --- | --- | --- |
| P1 | Review target追加時のproject boundary漏れ | target mapping table/specを追加し、unknown targetをfail closedに維持する |
| P1 | platform/global admin権限モデル未定義 | Organization RBAC/Platform Admin ADRとIssueへ分離する |
| P2 | role policyの成長余地 | policy object化またはPundit等の導入判断をADR化する |
| P2 | auth contractの機械検証不足 | OpenAPI securityとrequest spec coverageの差分checkを追加する |
| P2 | 外部AIレビュー未実施 | Claude/ChatGPTレビュー結果を取得でき次第、差分分析を追記する |

## 次アクション

1. PRを作成し、CI成功後にマージする。
2. GitHub Issue #48をクローズする。
3. 次はlive GitHub App smoke、callback failure AuditLog、Frontend再接続導線、staging/production worker smokeの残課題から、GitHub App不要で進められるものを優先する。
4. Organization RBAC / platform admin modelを後続Issue化する。

## 検証結果

- `bundle exec rspec spec/requests/api/v1/meetings_spec.rb spec/requests/api/v1/minutes_spec.rb spec/requests/api/v1/requirements_spec.rb spec/requests/api/v1/issue_drafts_spec.rb spec/requests/api/v1/open_api_drafts_spec.rb spec/requests/api/v1/reviews_spec.rb spec/requests/api/v1/integration_accounts_spec.rb spec/requests/api/v1/jobs_spec.rb spec/requests/api/v1/operations_spec.rb`: 81 examples, 0 failures
- `bundle exec rspec`: 269 examples, 0 failures
- `npm run api:verify`: success
- `npm run display:check`: success
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 29 passed

補足:

- `npm run frontend:e2e` はRails API未起動時に一度失敗したが、`RAILS_ENV=test` のRails APIを `http://127.0.0.1:3001` で起動して再実行し、29 passedを確認した。
- E2Eサーバーがtest DBにJobを残したため、直後の全RSpecは汚染データ由来で一度失敗した。`RAILS_ENV=test bundle exec rails db:reset` 後に再実行し、269 examples, 0 failuresを確認した。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | ワークフローエンドポイントの認可カバレッジ不足を閉じ、project boundaryを統一する |
| Strategy | ProjectMembership role policyを共通化し、controllerごとにresourceからprojectを辿って認可する |
| Tactics | 認可カバレッジ表、OpenAPI更新、request spec、Frontend queue health更新、E2E検証 |
| Assessment | ISSUE-048のMVPは満たした。global/organization RBAC、external AI review、policy object化は後続課題 |
| Conclusion | PR化してよい |
| Knowledge | 古いAPIを保護する時は認証追加だけでは不十分で、resourceのproject所属と副作用の強さに応じたrole gateが必要 |

## STRIDE

| Threat | 実装対応 |
| --- | --- |
| Spoofing | 保護対象のワークフローエンドポイントはactor authを必須化した |
| Tampering | create/update/generate/publish/reconcileをwrite/admin roleで制限した |
| Repudiation | 主要な生成/承認/外部連携操作でactor_idをaudit logに渡すようにした |
| Information Disclosure | read endpointsをproject member限定にし、Jobs/Operations/Reviewsのglobal exposureを閉じた |
| Denial of Service | AI generationやexternal side effectはmember role以上に限定し、operationsはadmin限定にした |
| Elevation of Privilege | cross-project accessとviewer/editorによる承認/公開操作をrequest specで拒否した |

## AIレビュー比較

Codex一次レビューでは、未認証pathの閉鎖だけでなく、project boundary、role不足、cross-project拒否、OpenAPI contract、Frontend project contextを同時に揃える必要があると判断した。

Claude/ChatGPTレビューは未実施のため、比較差分は未確定である。外部レビューが追加された場合は、重大度、採用判断、棄却理由を本ファイルに追記する。

## 判定

合格。

ISSUE-048は完了可能。ただし、世界レベルSaaS基準ではOrganization RBAC、platform admin、auth coverageの機械検証、外部AIレビュー比較を後続で進める必要がある。
