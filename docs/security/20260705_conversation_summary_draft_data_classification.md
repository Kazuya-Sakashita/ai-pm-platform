# Conversation Summary Draft データ分類と保護方針

## 作成日

2026-07-05

## 対象Issue

- GitHub Issue: #32
- ローカルIssue: `docs/issue/ISSUE-032_conversation_summary_draft_data_protection.md`

## データ分類

`conversation_summary_drafts` はDM原文そのものではないが、DM由来のAI整理結果である。要約、決定事項、未決事項、対応候補、Issue候補、要件候補、リスク、参加者、引用は、個人名、連絡先、認証情報の伏字前後、顧客名、未公開ロードマップ、契約前情報を含み得る。

分類は **Confidential / Derived Sensitive Data** とする。原文より低リスクに見える加工データでも、漏えい時の説明責任は原文に近い。

## 保護対象

以下を暗号化payloadに保存し、旧列には無害な互換値だけを残す。

| フィールド | 分類 | 理由 |
| --- | --- | --- |
| `summary` | Confidential | DM本文の要約であり、機密情報を再構成できる |
| `decisions` | Confidential | 未公開意思決定、担当者、顧客情報を含み得る |
| `open_questions` | Confidential | 未解決論点から機密計画が推測される |
| `action_items` | Confidential | 担当者、期日、内部作業を含み得る |
| `issue_candidates` | Confidential | GitHub Issue化前の背景や本文を含む |
| `requirement_candidates` | Confidential | 要件、受入条件、顧客要望を含む |
| `risks` | Confidential | セキュリティ/事業リスク情報を含む |
| `participants` | Confidential | 個人識別情報を含み得る |
| `source_quotes` | Highly Confidential | DM本文の抜粋であり原文に最も近い |
| `validation_errors` | Internal Sensitive | AI/検証エラーが本文断片を含む可能性がある |

## 採用方針

Active Record Encryption の非決定性暗号化を使い、上記フィールドを `conversation_summary_drafts.protected_payload` にJSONとして集約する。既存OpenAPIのレスポンス形は維持し、Modelが復号済みpayloadから従来フィールドを返す。

旧 `summary` / JSONB列は互換性と段階移行のため残すが、保存値は `暗号化済み` または空配列にする。DB dump単体ではDM由来の整理本文を読めない状態を目標にする。

## 検証結果

| 観点 | 結果 |
| --- | --- |
| 暗号化可否 | 既存 `ConversationImport.raw_text` と同じActive Record Encryption設定で実装可能 |
| JSONB直接暗号化 | 採用しない。暗号文とJSONB型の相性、検索性、将来migrationの複雑化が大きい |
| 検索要件 | 現時点ではsummary draft本文検索を非要件とする。検索が必要な場合は安全な派生indexを別Issueで設計する |
| schema互換性 | API responseは既存OpenAPI互換。DB列は追加のみで後方互換を確保する |
| パフォーマンス | 1 draft単位のpayload復号でありMVP規模では許容。大量一覧では最新draftを含める既存APIのN+1/復号回数を別Issueで監視する |
| 匿名化 | anonymize時は暗号化payload内も `削除済み` と空配列に更新し、復号後レスポンスにも本文を残さない |

## 残リスク

- アプリケーション権限と暗号鍵の両方を取得された場合は復号可能。
- APIレスポンスは権限を持つ利用者へ復号済み本文を返すため、認可境界はISSUE-030で継続強化する。
- 旧backupにmigration前の平文summary draftが含まれる可能性があるため、復元時はADR-0013のretention/anonymization再適用を必須にする。

## 次アクション

1. `protected_payload` migration/model/specを実装する。
2. DB dump単体にセンシティブ本文が残らないrequest specを追加する。
3. ISSUE-029へsummary draft派生データも暗号化対象になったことを追記する。
