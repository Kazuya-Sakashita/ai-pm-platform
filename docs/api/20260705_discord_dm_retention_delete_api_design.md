# Discord DM保持期限・匿名化API設計

## 対象Issue

ISSUE-029

## 背景

Discord DM手動インポートMVPは、DM原文、マスキング後テキスト、AI整理ドラフトを扱う。DMは高センシティブデータであり、Backend/Frontend MVPのままproductionへ進めると、DB dump、バックアップ、運用者アクセス、削除要求への対応が弱い。

本設計では、`ADR-0012` に従い、暗号化、保持期限、匿名化、監査証跡をAPI contractへ追加する。

## API方針

- `raw_text` と `redacted_text` はRails Active Record Encryptionで暗号化保存する。
- `raw_text` は作成から30日以内に自動purgeする。
- `redacted_text` とAI整理ドラフトは作成から180日以内に匿名化する。
- ユーザー操作による削除は、監査IDを残すため物理削除ではなく匿名化として扱う。
- 匿名化後はAPIレスポンス、AuditLog、Job logへDM本文を残さない。
- 匿名化後の `ConversationImport` は `archived` とし、下流AI生成へ進めない。

## OpenAPI変更

### DELETE /conversation-imports/{conversation_import_id}

DMインポート単位で本文とAI整理候補を匿名化する。

レスポンス:

- `204 No Content`
- `404 Not Found`

副作用:

- `conversation_import.raw_text` を削除済みプレースホルダーへ置換
- `conversation_import.redacted_text` を `null`
- `participants`、`safety_flags`、`blocked_reasons` を空配列へ置換
- `status` を `archived`
- `raw_text_purged_at` と `anonymized_at` を記録
- 紐づく `conversation_summary_drafts` の本文・候補・引用を削除済みプレースホルダーまたは空配列へ置換
- `AuditLog` に `conversation_import.anonymized` を本文なしmetadataで保存

### ConversationImport schema追加

- `raw_text_retention_expires_at`
- `raw_text_purged_at`
- `retention_expires_at`
- `anonymized_at`

### ConversationSummaryDraft schema追加

- `retention_expires_at`

## Backend方針

- `ConversationImport` に暗号化、保持期限default、purge/anonymize helperを持たせる。
- `ConversationImports::RetentionService` が期限切れraw text purgeとimport匿名化を担当する。
- `ConversationImportRetentionJob` がSolid Queueから定期実行できるようにする。
- `config/recurring.yml` にproduction recurring taskを追加する。

## 非スコープ

- project membership認可の完全実装
- backup削除保証
- enterprise DLP連携
- Discord DM自動取得

## リスク

- Active Record Encryption keyがproductionで未設定の場合、起動を止める必要がある。
- 既存平文データがある環境では移行順序が必要になる。
- 匿名化はDB上の現行レコードを復元不能にするが、既存バックアップ内の過去データまでは削除できない。
