# ISSUE-040: Project membership管理API/UIを実装する

## Issue番号

ISSUE-040

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/40

登録日: 2026-07-05

## 背景

ISSUE-030で `project_memberships` とDM系Policy Objectを実装したが、membershipの追加、一覧、role変更、失効を管理するAPI/UIはまだない。現状ではseedやテストデータに近い形でmembershipを作れるだけで、プロダクト上の運用フローとして成立していない。

AI PM Platformは会議、DM、Issue、レビュー、リリースなど複数の高センシティブ情報を扱うため、誰がプロジェクトに参加し、どの権限を持つかを監査可能に管理できる必要がある。

## 目的

Project membershipを管理するAPI/UIを追加し、owner/adminが安全にメンバー追加、role変更、失効、監査確認を行えるようにする。

## 完了条件

- Project membership管理APIのOpenAPI契約がある
- owner/adminのみがmembershipを作成、更新、失効できる
- 自分自身の最後のowner権限を失効できないなどのガードがある
- request specでviewer/editor/reviewer/auditorの拒否、admin/owner許可、他project越境拒否を検証している
- AuditLogにmembership作成、role変更、失効がsafe metadataで記録される
- Frontendでメンバー一覧、role表示、追加/変更/失効の最低限UIがある
- Security/UXレビューが `docs/review/` に保存されている

## スコープ

- Project membership OpenAPI
- Backend controller/service/policy
- request spec
- AuditLog
- Frontend管理UI
- 日本語表示
- レビュー文書

## 非スコープ

- SSO/SAML
- 招待メール送信
- SCIM
- 組織管理
- 請求プラン別制限

## 関連レビュー

- `docs/review/20260705_discord_dm_project_membership_policy_design_review.md`
- `docs/review/20260705_discord_dm_project_membership_policy_implementation_review.md`
- `docs/review/20260705_auth_membership_followup_issue_split_review.md`
- `docs/review/20260705_project_membership_management_design_review.md`
- `docs/review/20260706_project_membership_management_implementation_review.md`

## レビュー結果

Codex一次レビューでは、Policy Objectの実装だけでは運用導線が不足している。管理API/UIがない状態では、production運用で権限付与/剥奪が手作業になり、監査漏れや過剰権限が発生しやすい。

2026-07-05に専門家サブエージェント設計レビューを実施した。Security/QA AgentはAuditLog API未認可、last owner protection、project-scoped target lookup、safe metadataをP0条件として指摘した。Backend/Frontend/UX AgentはProjectMemberships API、Frontend最小UI、owner-only owner role操作、scope膨張回避を提案した。

2026-07-06に実装レビューを保存した。OpenAPI、Backend管理API、last owner 409、owner-only owner role操作、AuditLog API認可、safe AuditLog metadata、Frontendメンバー管理UI、E2Eを実装し、P0条件は対応済み。

## 実装結果

- `GET /projects/{project_id}/memberships` を追加し、owner/adminがmembership一覧を確認できるようにした。
- `POST /projects/{project_id}/memberships` を追加し、owner/adminが非owner membershipを追加できるようにした。
- `PATCH /projects/{project_id}/memberships/{membership_id}` を追加し、role変更を行えるようにした。
- `DELETE /projects/{project_id}/memberships/{membership_id}` を論理失効として実装した。
- owner roleの付与、owner降格、owner失効はownerのみに制限した。
- 最後のactive ownerの降格/失効を409 `last_owner_required` で拒否した。
- target membershipはproject scopeで取得し、cross-project操作を防いだ。
- membership作成、role変更、失効をAuditLogへsafe metadataで記録した。
- AuditLog APIにProject read認可を追加した。
- Frontendにメンバー管理パネル、role表示、追加、変更、失効導線を追加した。

## 検証結果

- `bundle exec rspec`: 222 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: success
- `npm run api:verify`: success
- `npm run display:check`: success
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 26 passed

## 優先度

P1

理由:

- 実認証/JWT接続後に必要となる管理導線である
- 過剰権限と退職/異動時の権限残存を防ぐ
- DM以外のプロジェクト情報にも横展開できる基盤になる

## 次アクション

1. GitHub Issue #40へ実装結果を同期する。
2. PRを作成し、CI成功後にマージする。
3. マージ後にGitHub Issue #40をクローズする。
