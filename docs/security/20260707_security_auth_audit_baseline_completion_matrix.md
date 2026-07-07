# セキュリティ・認証・監査・データ保護 初期設計完了マトリクス

## 作成日

2026-07-07

## 対象Issue

- ISSUE-006
- GitHub Issue: #6

## 完了条件マトリクス

| 完了条件 | 判定 | 証跡 | 残リスク |
| --- | --- | --- | --- |
| GitHub連携の最小権限が定義されている | 完了 | `docs/decisions/ADR-0003_github_integration_app_over_oauth.md`、`docs/security/20260630_github_integration_security_design.md` | 実GitHub App live smokeは別Issueで継続 |
| Discord連携の権限が定義されている | 完了 | `docs/decisions/ADR-0009_discord_dm_manual_import_first.md`、`docs/security/20260707_discord_integration_permission_boundary.md` | 公式Discord Bot/OAuth連携は将来Issueで再ADR |
| 外部連携トークン保存方針が定義されている | 完了 | `docs/decisions/ADR-0003_github_integration_app_over_oauth.md`、`docs/security/20260707_discord_integration_permission_boundary.md` | 将来Discord token保存時はKMS/rotation smokeが必要 |
| AuditLogモデルが設計されている | 完了 | `docs/architecture/20260630_db_design.md`、`docs/decisions/ADR-0002_mvp_data_security_and_hardening.md` | global security eventとの責務はISSUE-042/045で拡張済み |
| データ保持と削除方針が定義されている | 完了 | `docs/decisions/ADR-0012_discord_dm_text_encryption_retention.md`、`docs/api/20260705_discord_dm_retention_delete_api_design.md`、`docs/security/20260705_dm_key_rotation_kms_backup_checklist.md` | staging/production smokeとbackup削除保証はrelease gate |
| STRIDEレビューが保存されている | 完了 | `docs/security/20260629_security_baseline.md`、`docs/security/20260702_discord_dm_manual_import_security.md`、`docs/security/20260707_discord_integration_permission_boundary.md` | 外部AI/法務レビューは未実施 |

## 関連して完了済みの後続Issue

| Issue | 内容 | 状態 |
| --- | --- | --- |
| ISSUE-010 / ISSUE-012 | GitHub App方式、最小権限、callback、provider実装準備 | 完了済み |
| ISSUE-029 | Discord DM暗号化、保持期限、匿名化API | 完了済み |
| ISSUE-030 | Discord DM project membership / Policy Object | 完了済み |
| ISSUE-031 | DM key rotation / KMS / backup方針 | 完了済み |
| ISSUE-039 | JWT actor identity | 完了済み |
| ISSUE-042 / ISSUE-045 | JWT revocation、session、keyring、security events | 完了済み |
| ISSUE-048 | workflow endpoint認証/認可カバレッジ | 完了済み |

## クローズ後に残すべきRelease Gate

ISSUE-006は初期設計Issueとしてクローズ可能。ただし、以下はリリース判定で引き続きP0/P1として扱う。

- 実GitHub App credentialによるconnect/publish/reconcile live smoke
- OpenAI providerやDiscord由来データの実API smoke
- staging/production worker smoke
- KMS provider選定、key rotation smoke、backup削除保証
- 外部AIレビュー、法務/同意文言レビュー
- 支援技術レビュー、スクリーンリーダー確認
- Node.js 20 deprecated annotationのCI基盤更新

## 統合判断

ISSUE-006の目的は「OAuth、認証、権限、監査ログ、秘密情報検出、データ保持の初期方針を定義すること」であり、上記証跡で初期方針は成立している。

未完了の項目は本番運用・live smoke・外部レビュー・release gateであり、初期設計Issueのスコープを超えるため、親Issue #6はクローズ可能と判断する。
