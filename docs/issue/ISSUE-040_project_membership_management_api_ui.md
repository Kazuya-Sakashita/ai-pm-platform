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

## レビュー結果

Codex一次レビューでは、Policy Objectの実装だけでは運用導線が不足している。管理API/UIがない状態では、production運用で権限付与/剥奪が手作業になり、監査漏れや過剰権限が発生しやすい。

## 優先度

P1

理由:

- 実認証/JWT接続後に必要となる管理導線である
- 過剰権限と退職/異動時の権限残存を防ぐ
- DM以外のプロジェクト情報にも横展開できる基盤になる

## 次アクション

1. OpenAPIでmembership管理APIを設計する。
2. role別操作権限とlast owner protectionをレビューする。
3. Backend request specを先に追加する。
4. Frontendの最小管理UIを実装する。
