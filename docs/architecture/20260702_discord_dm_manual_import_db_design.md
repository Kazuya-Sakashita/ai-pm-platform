# Discord DM手動インポート DB設計

## 目的

Discord DMの手動貼り付けデータを、同意、redaction、AI整理、レビュー、Issue候補化まで監査できる形で保存する。DMは高センシティブ情報として扱い、raw textとAI送信用text、AI整理結果、レビュー結果を分離する。

## 設計方針

- MVPではDiscord API由来のIDを必須にしない。
- raw textは高センシティブデータとして、保存前編集と保持期間設計を前提にする。
- AIへ送る本文は `redacted_text` を原則にする。
- AI整理結果は承認前にGitHub Issueや要件へ流さない。
- 同意確認、redaction、scan、AI生成、承認をAuditLogへ残す。
- 将来のSlack/Discord channel importと共通化できるよう、`conversation_imports` として抽象化する。

## テーブル案

### conversation_imports

DMやチャット貼り付けの取り込み単位。

| カラム | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| id | uuid | yes | 主キー |
| project_id | uuid | yes | 所属Project |
| source_type | string | yes | MVPは `discord_dm_paste` |
| title | string | yes | インポート名 |
| raw_text | text | yes | ユーザー貼り付け原文。高センシティブ |
| redacted_text | text | no | AI送信用に編集/伏字化した本文 |
| participants | jsonb | no | 表示名、role、任意メモ |
| conversation_started_at | datetime | no | 会話開始日時 |
| conversation_ended_at | datetime | no | 会話終了日時 |
| consent_confirmed | boolean | yes | 同意/権限確認 |
| consent_confirmed_by | uuid | no | 確認ユーザー |
| consent_confirmed_at | datetime | no | 確認日時 |
| consent_statement_version | string | yes | 同意文言version |
| status | string | yes | 下記status |
| safety_flags | jsonb | yes | secret/PII scan結果 |
| blocked_reasons | jsonb | yes | AI生成を止める理由 |
| imported_by | uuid | yes | 作成ユーザー |
| last_scanned_at | datetime | no | 最終scan日時 |
| approved_at | datetime | no | 整理結果承認日時 |
| approved_by | uuid | no | 承認ユーザー |
| retention_expires_at | datetime | no | 保持期限 |
| created_at / updated_at | datetime | yes | 監査用 |

status:

- `draft`
- `blocked`
- `ready_for_ai`
- `summarizing`
- `summary_draft`
- `approved`
- `rejected`
- `archived`

index:

- `project_id, created_at`
- `project_id, status`
- `imported_by, created_at`
- `retention_expires_at`

### conversation_summary_drafts

AI整理結果。

| カラム | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| id | uuid | yes | 主キー |
| conversation_import_id | uuid | yes | 親import |
| provider | string | yes | `openai` / `deterministic` |
| model | string | no | AI model |
| summary | text | yes | 要約 |
| decisions | jsonb | yes | 決定事項 |
| open_questions | jsonb | yes | 未決事項 |
| action_items | jsonb | yes | TODO |
| issue_candidates | jsonb | yes | Issue候補 |
| requirement_candidates | jsonb | yes | 要件候補 |
| risks | jsonb | yes | リスク |
| participants | jsonb | yes | AIが認識した参加者 |
| source_quotes | jsonb | yes | 根拠引用 |
| confidence | decimal | no | 0.0-1.0 |
| status | string | yes | `draft`, `needs_revision`, `approved`, `rejected`, `stale` |
| validation_errors | jsonb | yes | schema/quality validation |
| generated_at | datetime | yes | 生成日時 |
| approved_at | datetime | no | 承認日時 |
| approved_by | uuid | no | 承認者 |
| created_at / updated_at | datetime | yes | 監査用 |

index:

- `conversation_import_id, created_at`
- `status`

### conversation_import_revisions

raw text/redacted textの重要変更履歴。MVPで必須に近いが、初期実装で重い場合はAuditLog metadataで代替し、P1で追加する。

| カラム | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| id | uuid | yes | 主キー |
| conversation_import_id | uuid | yes | 親import |
| changed_by | uuid | yes | 変更者 |
| change_type | string | yes | `raw_text_update`, `redaction_update`, `consent_update` |
| previous_digest | string | no | 本文digest |
| current_digest | string | yes | 本文digest |
| safe_summary | text | no | 安全な変更要約 |
| created_at | datetime | yes | 作成日時 |

本文全文の履歴保存は機密リスクが高いため、MVPではdigest + safe summaryを優先する。

## JSON構造案

### participants

```json
[
  {
    "display_name": "Kazuya",
    "role": "requester",
    "notes": "任意"
  }
]
```

### safety_flags

```json
[
  {
    "type": "secret_like_token",
    "severity": "high",
    "location_hint": "line 12",
    "action": "redaction_required"
  }
]
```

### issue_candidates

```json
[
  {
    "title": "Discord DMインポートで同意確認を必須にする",
    "background": "DM取り込み時の同意証跡が必要",
    "acceptance_criteria": ["同意チェックなしではAI整理できない"],
    "priority": "P0",
    "source_quote_ids": ["q1"]
  }
]
```

## セキュリティ判断

- raw textのDB暗号化はP0候補。既存基盤に暗号化層がない場合、少なくとも本番前にADRが必要。
- AI送信対象は原則 `redacted_text`。`raw_text` を直接送る場合は明示承認とAuditLogが必要。
- AuditLogには本文全文を保存しない。
- GitHub Issue候補生成時もsource quoteは短くし、DM全文を外部公開しない。

## 未決事項

- raw text暗号化の実装方式
- retention policyの初期値
- participant consentをどの粒度で記録するか
- revision tableをMVPで入れるかP1にするか
- GDPR/個人情報削除要求に対するdelete/anonymize方針
