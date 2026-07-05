# ADR-0014: Conversation Summary Draftの暗号化payload保存

## Status

Accepted

## Date

2026-07-05

## Context

ISSUE-029でDiscord DM原文の `raw_text` / `redacted_text` はActive Record Encryptionで暗号化した。一方、`conversation_summary_drafts` はAI整理結果として要約、決定事項、Issue候補、要件候補、引用をJSONB列へ保存していた。

AI生成物は原文から加工されていても、個人情報、未公開意思決定、顧客情報、秘密情報を含み得る。原文だけを暗号化しても、派生データがDB dumpに平文で残る場合、削除要求、incident response、エンタープライズ監査に耐えない。

## Decision

`conversation_summary_drafts` に `protected_payload` text列を追加し、Active Record Encryptionの非決定性暗号化で以下を保存する。

- `summary`
- `decisions`
- `open_questions`
- `action_items`
- `issue_candidates`
- `requirement_candidates`
- `risks`
- `participants`
- `source_quotes`
- `validation_errors`

既存のAPIレスポンスは変えない。Modelのgetter/setterで暗号化payloadを読み書きし、旧 `summary` / JSONB列には `暗号化済み` または空配列だけを保存する。

## Rationale

- DB dump単体でDM由来の整理本文を読めない。
- OpenAPI契約を変えずにFrontend/Backend互換を保てる。
- JSONBへ直接暗号文を入れるより、型変換、検索、rollbackの複雑性が低い。
- 既存のActive Record Encryption key管理、rotation、backup方針をADR-0013と共有できる。

## Alternatives Considered

### JSONB列へ直接 `encrypts` を指定する

不採用。

理由:

- 暗号化後の値とJSONB型の扱いが実装依存になりやすい。
- JSONB検索要件がない現時点で、型の利点を保ったまま安全に使う価値が小さい。
- migration/rollback時に暗号文と構造化JSONが混在し、運用リスクが上がる。

### 保持期限短縮だけで対応する

不採用。

理由:

- 保持期間中のDB dump漏えいには効かない。
- 世界レベルSaaS基準では、派生機密データもat-rest保護が必要。

### summary draftを保存しない

現時点では不採用。

理由:

- Human review、Issue化、要件化、監査説明のために短期保存の価値がある。
- 将来の高セキュリティプランでは保存しない/即時破棄モードを検討する。

## Consequences

良い影響:

- DB dump、support artifact、誤ったSQL出力に対する漏えい耐性が上がる。
- API契約を維持したまま保存層の保護を強化できる。

トレードオフ:

- JSONB列での本文検索はできない。
- 一覧APIでlatest summary draftを返す場合、復号回数が増える。
- 暗号鍵を持つアプリケーション層の認可、監査、ログ統制がより重要になる。

## Follow-up

- ISSUE-030でproject membership認可を実装する。
- summary draft本文検索が必要になった場合は、本文そのものではなく安全な派生index/embedding保持方針を別ADRで決める。
- production restore時はADR-0013に従い、backup由来の削除済みデータ復活を防ぐ。
