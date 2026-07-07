# 2026-07-07 セキュリティ・認証・監査・データ保護初期設計クローズ判定レビュー

## 評価日時

2026-07-07 12:25:00 JST

## 評価担当

Codex as Security Engineer / CTO / Backend Architect / DevOps / QA / Product Manager

外部AIレビュー: 未実施。Claude / ChatGPT等の外部AIレビューは追加待ち。

## Issue番号

- ISSUE-006
- GitHub Issue #6

## 対象成果物

- `docs/security/20260629_security_baseline.md`
- `docs/security/20260630_github_integration_security_design.md`
- `docs/security/20260630_secret_scan_error_masking_policy.md`
- `docs/security/20260702_discord_dm_manual_import_security.md`
- `docs/security/20260705_discord_dm_project_membership_policy.md`
- `docs/security/20260705_dm_key_rotation_kms_backup_checklist.md`
- `docs/security/20260706_jwt_revocation_session_key_rotation_design.md`
- `docs/security/20260706_workflow_endpoint_auth_coverage_matrix.md`
- `docs/security/20260707_discord_integration_permission_boundary.md`
- `docs/security/20260707_security_auth_audit_baseline_completion_matrix.md`
- `docs/decisions/ADR-0002_mvp_data_security_and_hardening.md`
- `docs/decisions/ADR-0003_github_integration_app_over_oauth.md`
- `docs/decisions/ADR-0009_discord_dm_manual_import_first.md`
- `docs/decisions/ADR-0012_discord_dm_text_encryption_retention.md`
- `docs/decisions/ADR-0016_jwt_actor_identity_for_api_audit.md`
- `docs/decisions/ADR-0017_jwt_revocation_session_key_rotation.md`

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- MoSCoW

## 評価サマリー

ISSUE-006は、OAuth、認証、権限、監査ログ、秘密情報検出、データ保持の初期方針を定義する親Issueである。初期作成時はGitHub App/OAuth判断、Discord権限、AuditLog、secret scan、データ保持が未整理だったが、後続IssueでGitHub App採用、Discord DM手動インポート、暗号化/retention、project membership、JWT actor identity、session/revocation/keyring、workflow endpoint認可まで整備された。

世界レベルSaaS基準では、live smoke、KMS実環境、法務レビュー、外部AIレビュー、支援技術レビューはまだ不足している。ただし、それらは初期設計Issueではなくrelease gateまたは後続Issueで扱うべき項目である。ISSUE-006の完了条件は、文書とADRとして満たされたため、クローズ可能と判断する。

## G-STACK

### Goal

AI PM PlatformのMVPが、機密情報、外部連携token、AI送信、GitHub公開、監査、保持削除を後付けではなく初期方針として持つ状態にする。

### Strategy

GitHub、Discord、AI、認証、監査、データ保持を単一文書に詰め込まず、ADR、security design、API design、Issue台帳、レビュー文書へ分解して統制する。

### Tactics

- GitHubはGitHub Appを採用し、Issues read/writeとMetadata read-onlyへ限定する。
- Discord DMはMVPで自動取得せず、手動貼り付け、同意、redaction、secret scan、review gateへ限定する。
- DM本文は暗号化、保持期限、匿名化、KMS/backup方針を持たせる。
- 認証はJWT actor identity、session、revocation、keyring、security eventsへ段階拡張する。
- workflow endpointsはproject membershipで認可する。

### Assessment

初期設計としては合格。特に、GitHub/Discordの外部権限を最小化し、AI送信前のsecret/PII gate、AuditLog、review gate、retentionを文書化できている点は強い。一方、実環境smokeや外部レビューが残っているため、release判定では引き続き厳しく扱う必要がある。

### Conclusion

ISSUE-006はクローズ可能。クローズ後も、live smoke、KMS、Discord公式連携、法務レビュー、アクセシビリティレビューはrelease gateまたは個別Issueで継続する。

### Knowledge

セキュリティ初期設計の完了は「リスクがゼロになった」ではなく、「どのリスクをMVP範囲で閉じ、どのリスクをrelease gateへ送るかが監査可能になった」状態で判断する。

## 良かった点

- GitHub Appを採用し、OAuth AppやPATより最小権限と監査性を優先した。
- Discord DM自動取得をMVP非スコープにし、プライバシーとAPI制約を正しく回避した。
- secret scan、safe error、redaction、review gate、AuditLogが複数工程に横展開されている。
- DM暗号化、retention、匿名化、KMS/backup方針まで初期設計に含めた。
- JWT actor identity、session失効、key rotation、workflow endpoint認可へ後続実装が進んでいる。

## 改善点

- 外部AIレビューと法務レビューが未実施で、同意文言やDiscord連携の規約面はまだ一次判断である。
- GitHub App live smokeとstaging/production worker smokeは残っている。
- KMS provider選定、key rotation smoke、backup削除保証はrelease gateのままである。
- Discord Bot/OAuth公式連携を追加する場合の具体API設計は未着手である。
- Node.js 20 deprecated annotationがCIに残っており、基盤更新の別Issue化が必要である。

## 優先順位

| 優先度 | 対応 | 理由 |
| --- | --- | --- |
| P0 | 実GitHub App live smokeをrelease gateへ残す | 外部連携の実疎通と権限確認が未完了 |
| P0 | KMS/key rotation/backup削除のstaging smoke | DMデータ保護の本番信頼性に直結 |
| P1 | Discord公式連携を追加する場合は新ADRを必須化 | scope追加と規約リスクを再評価するため |
| P1 | 外部AI/法務レビューを追加 | 同意文言、AI送信、DM扱いの妥当性を高めるため |
| P2 | CI Node.js annotation解消Issueを追加 | CI基盤の将来互換性を維持するため |

## 次アクション

1. GitHub Issue #6へクローズ判定コメントを追加する。
2. 本レビューと完了マトリクスをPR化する。
3. PRのCI通過後、Issue #6をクローズする。
4. release gate項目は既存Issueまたは後続Issueへ残し、親Issue #6へ再混入させない。

## 判定

合格。

ISSUE-006は初期設計Issueとしてクローズ可能。残課題はrelease gateまたは個別Issueとして継続する。
