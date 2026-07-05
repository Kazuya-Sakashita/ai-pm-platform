# Conversation Summary Draft データ保護設計レビュー

## 評価日時

2026-07-05 09:59:26 JST

## 評価担当

Codex / Security Engineer / CTO / Backend Architect / Tech Lead / Product Manager / QA

## 使用フレームワーク

- G-STACK
- STRIDE
- ISO25010
- ADR

## 対象

- GitHub Issue: #32
- `docs/security/20260705_conversation_summary_draft_data_classification.md`
- `docs/decisions/ADR-0014_conversation_summary_draft_protected_payload.md`

## 良かった点

- DM原文だけでなくAI生成の派生データも機密扱いに引き上げた。
- OpenAPIレスポンス互換を維持しながら、保存層の平文露出を下げる設計にした。
- JSONB直接暗号化ではなく、暗号化payload集約を採用し、型変換とmigrationリスクを抑えた。
- `source_quotes` を原文に最も近いデータとして明示的に高リスク分類した。

## 改善点

- 本文検索や分析要件が出た場合、暗号化payloadだけでは対応できない。
- 一覧APIがlatest summary draftを含むため、件数増加時に復号コストが見えにくい。
- DB backupにmigration前の平文データが残る可能性があり、restore手順の実施証跡が必要。
- Project membership認可が未完了のため、復号後APIレスポンスのアクセス境界はまだ弱い。

## 優先順位

| 優先度 | 内容 | 理由 |
| --- | --- | --- |
| P0 | `protected_payload` 暗号化保存を実装する | DB dump単体の漏えいリスクを下げる |
| P0 | request specでDB保存値に本文が残らないことを検証する | 回帰防止の最低条件 |
| P1 | ISSUE-029へ派生データ保護結果を同期する | retention/delete設計との整合性を保つ |
| P1 | ISSUE-030で認可境界を実装する | 復号後レスポンスのアクセス制御が必要 |
| P2 | summary draft検索要件を別Issueで評価する | 暗号化後の検索方式を先に固定しない |

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | DM由来のAI整理結果をDB dump単体で読めない状態にする |
| Strategy | API契約を維持し、保存層だけ暗号化payloadへ移す |
| Tactics | migration、model accessor、request spec、ADR、security docを追加する |
| Assessment | 世界レベルSaaSでは派生データ暗号化は妥当。ただし認可とbackup証跡が残課題 |
| Conclusion | P0で実装へ進める |
| Knowledge | Active Record Encryption、STRIDE、ADR-0013 key/backup方針 |

## STRIDE

| 脅威 | 評価 | 対応 |
| --- | --- | --- |
| Spoofing | API利用者認可が未完了 | ISSUE-030でmembership policyを実装 |
| Tampering | migration中のpayload欠損 | request specとrollback可能migrationで検証 |
| Repudiation | 誰が復号済み本文へアクセスしたか未記録 | 将来の閲覧AuditLogを検討 |
| Information Disclosure | 平文JSONB列が最大リスク | `protected_payload` 暗号化と旧列無害化で対応 |
| Denial of Service | 復号回数増加 | 一覧性能を監視し、必要ならinclude制御 |
| Elevation of Privilege | アプリkey取得時は復号可能 | ADR-0013のkey管理、rotation、KMS方針を適用 |

## ISO25010

| 品質特性 | 評価 |
| --- | --- |
| Security | 改善。保存層の機密性が上がる |
| Compatibility | 良好。API responseは維持 |
| Maintainability | 中。accessor層が増えるためspecで守る |
| Performance | MVPでは許容。大規模一覧は再評価 |
| Reliability | migrationとrollbackの検証が必要 |

## 次アクション

1. `protected_payload` migration/modelを実装する。
2. `conversation_summary_drafts` request specにDB dump保護と匿名化後レスポンス保護を追加する。
3. RSpecを実行し、結果を実装レビューへ保存する。
4. ISSUE-029 / ISSUE-032 / GitHub Issue #32へ結果を同期する。

## Issue番号

- #32
