# Discord DMデータ保護 親Issueクローズ判定レビュー

## 評価日時

2026-07-06 12:24:55 JST

## 評価担当

Codex / Security Engineer / CTO / Backend Architect / DevOps / QA / Product Manager

外部AIレビュー: Claude/ChatGPTレビューは未実施。現時点ではCodex一次レビューとして保存し、外部AIレビュー結果が追加された場合は差分分析を追記する。

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- DORA Metrics

## Issue番号

ISSUE-029 / GitHub #29

## 対象

- `docs/issue/ISSUE-029_discord_dm_text_encryption_retention_delete.md`
- `docs/issue/ISSUE-030_discord_dm_project_membership_policy.md`
- `docs/issue/ISSUE-031_dm_key_rotation_kms_backup_policy.md`
- `docs/issue/ISSUE-032_conversation_summary_draft_data_protection.md`
- `docs/issue/ISSUE-033_retention_worker_staging_production_smoke.md`
- `docs/issue/ISSUE-034_discord_dm_frontend_failure_path_e2e.md`
- `docs/issue/ISSUE-035_discord_dm_structured_outputs_provider.md`
- `docs/issue/ISSUE-038_discord_dm_pii_redaction_suggestions.md`
- `docs/review/20260705_discord_dm_retention_delete_implementation_review.md`
- `docs/review/20260705_discord_dm_project_membership_policy_implementation_review.md`
- `docs/review/20260705_dm_key_rotation_kms_backup_policy_review.md`
- `docs/review/20260705_discord_dm_pii_redaction_implementation_review.md`

## 判定対象の子Issue状態

| Issue | 内容 | GitHub状態 |
| --- | --- | --- |
| #30 | DM系API project membership / Policy Object | CLOSED |
| #31 | 鍵rotation / KMS / backup削除方針ADR | CLOSED |
| #32 | Conversation Summary Draft JSON本文保護 | CLOSED |
| #33 | retention worker staging/production smoke runbook | CLOSED |
| #34 | Frontend匿名化失敗/キャンセル/権限エラーE2E | CLOSED |
| #35 | DM整理Structured Outputs provider | CLOSED |
| #38 | PII検出とマスキング提案 | CLOSED |

## 良かった点

- DM raw text / redacted textはActive Record Encryptionで保護され、DB dump単体で本文を読みづらくなった。
- productionで暗号鍵未設定の場合にboot blockerとなる方針を入れ、本番での平文運用リスクを下げた。
- raw text 30日、redacted text / AI整理draft 180日の保持期限と匿名化APIを整備した。
- 手動匿名化とretention jobが同じServiceを使い、AuditLogには本文やsecret値を残さない設計になっている。
- Project membership / Policy Objectにより、DM閲覧、更新、AI整理、承認、匿名化のBroken Access Controlリスクを下げた。
- Conversation Summary Draftの派生JSON本文も保護対象へ移し、AI整理結果の二次漏えいリスクを下げた。
- PII検出とマスキング提案を追加し、AI送信前の安全確認がsecret検出だけに依存しなくなった。
- 失敗系Frontend E2Eと日本語safe errorにより、匿名化失敗、権限不足、入力不備時のUXを検証できている。

## 改善点

- KMS providerの実接続、staging rotation smoke、backup provider retention設定は、方針とrunbook止まりで実環境証跡は未取得である。
- retention workerのstaging/production smokeはrunbook化済みだが、実環境のworker heartbeat、recurring schedule、削除再現証跡は未取得である。
- GitHub App live smoke、実OpenAI smoke、staging/production worker smokeなどは、環境情報とcredentialが必要なためリリースゲート側で継続管理する必要がある。
- Project membershipはDM系APIを中心に実装済みだが、全Project配下APIの認可網羅は別Issueで継続している。
- 外部AI複数レビューは未実施で、Codex一次レビューに留まっている。

## 優先順位

| Priority | 指摘 | 対応 |
| --- | --- | --- |
| P0 | DM本文暗号化、retention、匿名化、Policy Object、safe AuditLog | 今回完了済みとして親Issueをクローズ可能 |
| P1 | 実staging/production smoke証跡不足 | ISSUE-004、release gate、runbook evidence templateで継続 |
| P1 | KMS provider実接続とbackup retention実設定 | release前のSecurity/DevOps gateへ残す |
| P2 | 外部AIレビュー比較未実施 | 外部レビュー結果が取れた時点で差分追記 |

## 次アクション

1. GitHub Issue #29へ子Issue完了状況と残リスク切り分けをコメントする。
2. GitHub Issue #29をクローズする。
3. `docs/issue/ISSUE-029_discord_dm_text_encryption_retention_delete.md` にクローズ状態を記録する。
4. 実staging/production証跡はISSUE-004またはrelease gate側で継続追跡する。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | Discord DM由来テキストをproduction前提で扱える最低限の保護基盤を整える |
| Strategy | 暗号化、retention、匿名化、Policy Object、safe AuditLog、PII検出を子Issueへ分割して完了させる |
| Tactics | #30〜#35、#38の実装完了、レビュー保存、CI確認、親Issueへの同期 |
| Assessment | ISSUE-029の実装完了条件は満たした。実環境smokeはrelease gateの残リスクとして分離する |
| Conclusion | GitHub Issue #29はクローズ可能 |
| Knowledge | センシティブデータIssueは、実装完了とproduction証跡の未取得を分けて管理しないと親Issueが無期限に肥大化する |

## 判定

合格。

ISSUE-029は親Issueとしてクローズ可能。ただし、実staging/production worker smoke、KMS実接続、backup retention provider設定、外部AIレビュー比較は、release gateまたは個別Issueで継続する。
