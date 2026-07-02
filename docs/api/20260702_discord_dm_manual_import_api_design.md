# Discord DM手動インポート API設計メモ

## 方針

MVPではDiscord APIからDMを取得しない。ユーザーが明示的に貼り付けた会話テキストだけを `conversation_imports` として保存し、AI整理ドラフトを生成する。

## リソース案

### ConversationImport

DMやチャット由来の生テキスト取り込み単位。

主な属性:

- `id`
- `project_id`
- `source_type`: `discord_dm_paste`
- `title`
- `raw_text`
- `redacted_text`
- `participants`
- `conversation_started_at`
- `conversation_ended_at`
- `consent_confirmed`
- `consent_confirmed_by`
- `consent_confirmed_at`
- `consent_statement_version`
- `status`: `draft`, `blocked`, `ready_for_ai`, `summarizing`, `summary_draft`, `approved`, `rejected`
- `safety_flags`
- `created_at`
- `updated_at`

### ConversationSummaryDraft

AI整理結果。

主な属性:

- `id`
- `conversation_import_id`
- `summary`
- `decisions`
- `open_questions`
- `action_items`
- `issue_candidates`
- `requirement_candidates`
- `risks`
- `participants`
- `source_quotes`
- `confidence`
- `status`: `draft`, `needs_revision`, `approved`, `rejected`

## API案

### POST `/api/v1/projects/{project_id}/conversation-imports`

手動貼り付けDMを作成する。

必須:

- `source_type`
- `title`
- `raw_text`
- `consent_confirmed`
- `consent_statement_version`

レスポンス:

- `conversation_import`
- `safety_flags`
- `next_action`

ルール:

- `source_type` はMVPでは `discord_dm_paste` のみ
- `consent_confirmed=false` の場合は保存してもAI整理不可
- secret/PII検出時は `status=blocked`

### PATCH `/api/v1/conversation-imports/{conversation_import_id}`

raw text編集、redaction、title、participantsを更新する。

ルール:

- AI整理実行後にraw textを変更した場合、既存summary draftをstaleにする
- 承認後のraw text編集は新しいrevisionとして扱う

### POST `/api/v1/conversation-imports/{conversation_import_id}/scan`

secret/PII scanを実行する。

レスポンス:

- `valid`
- `safety_flags`
- `blocked_reasons`
- `redaction_suggestions`

### POST `/api/v1/conversation-imports/{conversation_import_id}/generate-summary`

AI整理ドラフトを生成する。

前提:

- consent confirmed
- secret/PII blocker resolved
- project member permission

レスポンス:

- `job`
- `conversation_summary_draft`

エラー:

- `422`: consent missing, raw text invalid, safety blocker
- `424`: AI provider not configured
- `429`: provider rate limited
- `502`: AI provider failure

### GET `/api/v1/conversation-imports/{conversation_import_id}`

取り込み内容、safety状態、AI整理結果を取得する。

### PATCH `/api/v1/conversation-summary-drafts/{draft_id}`

AI整理ドラフトを編集する。

### POST `/api/v1/conversation-summary-drafts/{draft_id}/approve`

AI整理ドラフトを承認し、要件/Issue候補へ進める。

## OpenAPI反映時の注意

- enumは英語のまま、UI表示は日本語へ変換する
- raw textの最大長を定義する
- `safety_flags` は構造化する
- AI送信前のblocker状態をレスポンスへ含める
- AuditLogに残すmetadataとAPIレスポンスmetadataを分ける

## レビュー観点

- APIだけで同意確認を迂回できないか
- blocked状態でもAI生成を実行できないか
- raw textとredacted textの使い分けが明確か
- Issue生成へ進む前にreview gateがあるか
- 削除、保持期間、exportの方針が後続で扱えるか
