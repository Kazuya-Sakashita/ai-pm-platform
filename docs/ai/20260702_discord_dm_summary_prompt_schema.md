# Discord DM整理 AI Prompt/Schema設計

## 目的

Discord DMの手動貼り付けテキストから、要約、決定事項、未決事項、TODO、Issue候補、要件候補、リスク、根拠引用を構造化して生成する。AI出力は下書きであり、レビュー承認なしにIssue化しない。

## 入力

AIへ送る入力は原則 `redacted_text` とする。

入力metadata:

- `project_name`
- `conversation_title`
- `source_type`: `discord_dm_paste`
- `participants`
- `conversation_started_at`
- `conversation_ended_at`
- `redacted_text`
- `safety_flags`
- `language`: `ja`

## System Prompt案

```text
あなたはAI Project Managerです。
Discord DM由来の会話を、開発プロジェクトでレビュー可能な整理ドラフトへ変換してください。

重要:
- 推測を事実として書かない
- 発言者や合意事項を取り違えない
- 根拠がない決定事項は decisions に入れず open_questions に入れる
- 個人情報、秘密情報、token、credentialらしき文字列を出力しない
- GitHub Issue候補は実装可能な単位に分割する
- すべて日本語で出力する
- 出力はJSON schemaに厳密に従う
```

## User Prompt構造

```text
以下のDiscord DM貼り付けテキストを整理してください。

プロジェクト: {project_name}
会話タイトル: {conversation_title}
参加者: {participants}
会話日時: {conversation_started_at} - {conversation_ended_at}
安全フラグ: {safety_flags}

本文:
{redacted_text}
```

## JSON Schema案

```json
{
  "type": "object",
  "required": [
    "summary",
    "decisions",
    "open_questions",
    "action_items",
    "issue_candidates",
    "requirement_candidates",
    "risks",
    "participants",
    "source_quotes",
    "confidence"
  ],
  "properties": {
    "summary": { "type": "string" },
    "decisions": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["text", "source_quote_ids", "confidence"],
        "properties": {
          "text": { "type": "string" },
          "source_quote_ids": { "type": "array", "items": { "type": "string" } },
          "confidence": { "type": "number", "minimum": 0, "maximum": 1 }
        }
      }
    },
    "open_questions": { "type": "array", "items": { "type": "string" } },
    "action_items": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["text", "owner", "due_date", "status"],
        "properties": {
          "text": { "type": "string" },
          "owner": { "type": ["string", "null"] },
          "due_date": { "type": ["string", "null"] },
          "status": { "type": "string", "enum": ["open", "blocked", "done"] }
        }
      }
    },
    "issue_candidates": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["title", "background", "acceptance_criteria", "priority", "source_quote_ids"],
        "properties": {
          "title": { "type": "string" },
          "background": { "type": "string" },
          "acceptance_criteria": { "type": "array", "items": { "type": "string" } },
          "priority": { "type": "string", "enum": ["P0", "P1", "P2", "P3"] },
          "source_quote_ids": { "type": "array", "items": { "type": "string" } }
        }
      }
    },
    "requirement_candidates": { "type": "array", "items": { "type": "string" } },
    "risks": { "type": "array", "items": { "type": "string" } },
    "participants": { "type": "array", "items": { "type": "string" } },
    "source_quotes": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["id", "quote", "reason"],
        "properties": {
          "id": { "type": "string" },
          "quote": { "type": "string" },
          "reason": { "type": "string" }
        }
      }
    },
    "confidence": { "type": "number", "minimum": 0, "maximum": 1 }
  }
}
```

## Safety Rules

- `safety_flags` にhigh severityがある場合、AI生成を実行しない。
- source quoteは短くし、DM全文を再出力しない。
- secret-like contentを検出した場合は `[REDACTED]` として扱う。
- confidenceが0.6未満のIssue候補はReview blocker対象にする。
- 決定事項にsource quoteがない場合はReview blocker対象にする。

## Quality Evaluation

評価観点:

- 発言者取り違えがない
- 決定事項と未決事項が分かれている
- TODOにowner/due date/statusがある
- Issue候補が実装可能な粒度である
- source quoteが根拠として十分である
- 個人情報やsecretが出力されていない

## 未決事項

- 実モデル選定
- 日本語DM特有の省略表現への対応
- 引用最大文字数
- confidenceの算出方針

## 2026-07-05 実装更新

ISSUE-035で `ConversationSummaryGeneration::OpenaiProvider` を追加した。実装schemaはOpenAPIの `ConversationSummaryDraft` 関連schemaへ合わせ、以下を更新済みとする。

- Structured OutputsはResponses APIの `text.format.json_schema`、`strict: true` を使う。
- `issue_candidates` は `title`, `body`, `labels`, `priority`, `source_quote_ids`, `confidence` を返す。
- `requirement_candidates` は文字列ではなく `title`, `requirement`, `acceptance_criteria`, `source_quote_ids`, `confidence` を返す。
- `risks` は文字列ではなく `text`, `severity`, `mitigation`, `source_quote_ids`, `confidence` を返す。
- `participants` は文字列ではなく `display_name`, `handle`, `role`, `notes` を返す。
- `source_quotes` はOpenAPIに合わせ、`id`, `quote`, `speaker`, `message_at` を返す。`reason` は現時点のAPIレスポンスには含めない。
- `action_items.status` はOpenAPIに合わせ `open`, `in_progress`, `done` とする。

詳細は `docs/ai/20260705_discord_dm_structured_outputs_provider.md` を参照する。
