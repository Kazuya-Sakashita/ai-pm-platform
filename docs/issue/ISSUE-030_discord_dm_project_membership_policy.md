# ISSUE-030: Discord DMインポートのproject membership/Policy Objectを設計・実装する

## Issue番号

ISSUE-030

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/30

登録日: 2026-07-05

## 背景

ISSUE-029でDiscord DM由来テキストの暗号化、保持期限、匿名化API、retention jobは実装された。一方で、現時点のAPIは認証/認可基盤とproject membershipに接続されておらず、誰がDMインポートを閲覧、更新、承認、匿名化できるかがPolicy Objectとして定義されていない。

Discord DMは高センシティブデータであり、世界レベルSaaS基準では暗号化だけでは不十分である。Broken Access Controlを防ぐため、プロジェクト参加者、管理者、承認者、監査者の権限境界を明確にする必要がある。

## 目的

DMインポート関連APIの閲覧、更新、安全チェック、AI整理、承認、匿名化をproject membershipとPolicy Objectで制御し、production-readyな権限境界を作る。

## 完了条件

- DMインポート操作別の権限表が `docs/security/` または `docs/product/` に保存されている
- Policy Object設計がレビューされ、`docs/review/` に保存されている
- OpenAPIまたはBackendで認可失敗時のsafe error responseが定義されている
- Backend request specで他プロジェクト、非member、readonly member、承認権限なしの拒否を検証している
- AuditLogのactorが将来の実ユーザーIDへ接続できる形になっている
- Frontendで権限不足時の日本語表示と再接続/戻り導線が破綻しない
- ISSUE-029、ISSUE-006へ同期コメントを残している

## スコープ

- DMインポート操作の権限表
- Policy Object設計
- Backend認可ガード
- request spec
- safe error response
- Frontend権限エラー表示
- レビュー、Issue同期

## 非スコープ

- SSO/SAML
- 請求プラン別権限
- Organization全体の高度なRBAC
- Discord Botの権限設計
- Slack対応

## 関連レビュー

- `docs/review/20260705_discord_dm_frontend_mvp_review.md`
- `docs/review/20260705_discord_dm_retention_delete_api_design_review.md`
- `docs/review/20260705_discord_dm_retention_delete_implementation_review.md`
- `docs/review/20260705_discord_dm_project_membership_policy_design_review.md`
- `docs/review/20260705_discord_dm_project_membership_policy_implementation_review.md`

## 関連Security Doc

- `docs/security/20260705_discord_dm_project_membership_policy.md`

## レビュー結果

ISSUE-029の実装レビューでは、DM本文の暗号化、匿名化、retention jobはMVPとして条件付き合格。ただし、project membership認可と実ユーザーactorが未実装であり、production-ready判定ではP0 blockerとして扱う。

2026-07-05に設計レビューを実施。`owner/admin/editor/reviewer/viewer/auditor` の操作別権限表を作成し、DM系APIへ限定してPolicy Objectを導入する方針にした。実認証が未接続のため、`X-Actor-Id` は暫定actor identityとして扱い、productionではJWT/session等の認証済みuser idへ置き換える前提を明記した。

2026-07-05に実装完了。`project_memberships`、`ProjectMembership`、`ConversationImportPolicy`、DM系controller guard、safe 401/403、AuditLog actor接続、OpenAPI `X-Actor-Id`、Frontend API client headerを追加した。Project作成時は `X-Actor-Id` があればowner membershipを自動作成する。

検証結果:

- `bundle exec rails db:migrate`: success
- `bundle exec rspec spec/requests/api/v1/conversation_imports_spec.rb spec/requests/api/v1/conversation_summary_drafts_spec.rb spec/requests/api/v1/projects_spec.rb`: 25 examples, 0 failures
- `bundle exec rspec`: 175 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: success
- `npm run display:check`: success
- `npm run frontend:build`: success

補足: `npm run api:verify` では Node `v22.7.0` が期待範囲より古い警告とRedocly CLI更新通知が出たが、OpenAPI lint/type生成は成功した。

## 優先度

P0

理由:

- DM閲覧/削除のBroken Access Controlは重大な情報漏えいに直結する
- 暗号化済みでもAPI経由の不正閲覧は防げない
- 監査可能なAI PM Platformの信頼性に直結する

## 次アクション

1. GitHub Issue #30へ実装結果とCI結果を同期し、クローズする。
2. ISSUE-029、ISSUE-006へ完了結果を同期する。
3. 次の推奨順としてProject membership管理APIまたは実認証/JWT接続をIssue化する。
