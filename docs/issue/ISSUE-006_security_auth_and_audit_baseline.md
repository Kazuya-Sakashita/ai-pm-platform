# ISSUE-006: OAuth、認証、監査、データ保護の初期設計を作る

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/6

登録日: 2026-06-30
同期方法: `scripts/sync-github-issues.rb --apply`

## 背景

会議内容、要件、Issue、API設計には機密情報が含まれる。外部連携も多いため、MVP段階からセキュリティを設計する必要がある。

## 目的

OAuth、認証、権限、監査ログ、秘密情報検出、データ保持の初期方針を定義する。

## 完了条件

- GitHub連携の最小権限が定義されている
- Discord連携の権限が定義されている
- 外部連携トークン保存方針が定義されている
- AuditLogモデルが設計されている
- データ保持と削除方針が定義されている
- STRIDEレビューが保存されている

## スコープ

- OAuth設計
- 監査ログ
- 秘密情報検出
- データ保持
- OWASP/STRIDEレビュー

## 非スコープ

- Enterprise SSO
- SOC2正式対応
- 高度なDLP

## 関連レビュー

- `docs/review/20260629_mvp_review.md`
- `docs/review/20260629_requirements_review.md`
- `docs/review/20260630_screen_design_review.md`
- `docs/review/20260630_api_design_review.md`
- `docs/review/20260630_db_design_review.md`
- `docs/review/20260707_security_auth_audit_baseline_closure_review.md`

## レビュー結果

P0として必須。セキュリティを後から足すとプロダクト価値と信頼を損なう。

2026-07-05にISSUE-030でDiscord DM系APIへproject membership/Policy Objectを導入した。`project_memberships`、`ConversationImportPolicy`、safe 401/403、AuditLog actor接続により、DM閲覧/作成/更新/安全チェック/AI整理/承認/匿名化のBroken Access Controlリスクを下げた。GitHub #30はクローズ済み。同期コメント: `https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/6#issuecomment-4885166479`。`X-Actor-Id` は暫定actorであり、productionでは認証済みuser idへ置き換える必要がある。

2026-07-07にクローズ判定レビューを実施した。GitHub最小権限、Discord連携権限、外部連携トークン保存、AuditLog、データ保持/削除、STRIDEレビューの初期設計は完了条件を満たしている。DiscordはMVPでAPI自動取得を行わず、手動DM貼り付けを採用し、将来Bot/OAuth連携ではscope追加ADRを必須にする。完了マトリクスは `docs/security/20260707_security_auth_audit_baseline_completion_matrix.md`、Discord権限境界は `docs/security/20260707_discord_integration_permission_boundary.md` に保存した。

## 次アクション

- GitHub Issue #6へクローズ判定コメントを追加する
- PRのCI通過後、GitHub Issue #6をクローズする
- live smoke、KMS、外部AI/法務レビュー、支援技術レビューはrelease gateまたは個別Issueで継続する
