# Discord DM保持期限・匿名化API設計レビュー

## 評価日時

2026-07-05 18:55 JST

## 評価担当

Codex / CTO / Tech Lead / Backend Architect / Security Engineer / QA / Product Manager

## Issue番号

ISSUE-029

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- ADR

## 対象

- `docs/api/20260705_discord_dm_retention_delete_api_design.md`
- `docs/decisions/ADR-0012_discord_dm_text_encryption_retention.md`
- `docs/api/openapi.yaml` 反映予定範囲

## 良かった点

- 物理削除ではなく匿名化をAPIの意味として明確にし、AuditLogの追跡可能性と本文削除を両立した。
- raw text 30日、redacted text / AI整理ドラフト180日の二段保持期限に分け、DM原文のプライバシー負債を先に下げる設計にした。
- `DELETE /conversation-imports/{id}` を本文復元不能化操作として定義し、ユーザー操作とretention jobの責務を揃えた。
- APIレスポンス、AuditLog、Job logへ本文を残さない条件を明記した。
- productionで暗号化key未設定なら起動を止める方針を含めた。

## 改善点

- project membership認可はまだ未実装であり、削除/匿名化を誰が実行できるかのPolicy Objectは次工程で必要。
- 既存バックアップ内の過去平文データ削除は、このAPIだけでは保証できない。
- Active Record Encryptionのkey rotation手順は今回のAPI設計だけでは不足している。
- 匿名化後もプレースホルダー文字列は残るため、UIは「削除済み」と明確に表示する必要がある。
- summary draftのJSON候補は暗号化ではなく匿名化対象として扱うため、180日より前の漏洩リスクは残る。

## 優先順位

- P0: raw/redacted textの暗号化保存。
- P0: raw text 30日purge、import/draft 180日匿名化。
- P0: `DELETE /conversation-imports/{id}` のOpenAPI/Backend実装。
- P0: AuditLog safe metadataのspec固定。
- P1: Frontendの匿名化導線と保持期限表示。
- P1: key rotationとbackup削除方針の追加ADR。
- P1: project membership導入後のPolicy Object。

## 次アクション

1. OpenAPIへDELETE endpointとretention fieldsを追加する。
2. Rails Active Record Encryptionを設定し、production key未設定をboot blockerにする。
3. `ConversationImports::RetentionService` と `ConversationImportRetentionJob` を実装する。
4. request specで暗号化、匿名化、retention job、AuditLog safe metadataを検証する。
5. Frontendへ匿名化ボタンと保持期限表示を追加する。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | DM由来テキストをproductionで扱える最低限の保護境界へ近づける |
| Strategy | 暗号化、保持期限、匿名化、監査をAPI contractとBackend serviceで一体化する |
| Tactics | DELETE endpoint、retention timestamps、encryption config、retention job、request spec |
| Assessment | 設計はP0 blockerへ正しく向いているが、認可とbackup削除方針は残る |
| Conclusion | API設計として条件付き合格。OpenAPI反映とBackend実装へ進んでよい |
| Knowledge | DM機能は「便利さ」よりも「保存しない/消せる/監査できる」ことが信頼の前提になる |

## STRIDE / OWASP

| 観点 | 評価 |
| --- | --- |
| Spoofing | actorはまだsystem中心。実ユーザー紐付けは未完了 |
| Tampering | 匿名化操作をAuditLogへ残す設計は妥当 |
| Repudiation | 承認理由と匿名化ログは残るが、削除実行者の実ユーザー化が必要 |
| Information Disclosure | 暗号化とretentionで改善。ただしbackupとdraft暗号化は残課題 |
| Denial of Service | retention jobはbatch size制御が必要 |
| Elevation of Privilege | project membership未実装はP0/P1境界のリスク |

## AIレビュー比較

Codex一次レビューのみ。Claude、ChatGPTなど外部AIレビューは未実施。外部レビュー結果が追加された場合は、暗号化key管理、backup削除、認可境界の相違点を追記する。
