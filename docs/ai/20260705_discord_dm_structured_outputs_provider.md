# Discord DM Structured Outputs provider

## 目的

ISSUE-035で、Discord DM整理をOpenAI Responses API + Structured Outputs providerへ接続する。ただし通常CIとローカル検証は外部OpenAI通信に依存させず、実API疎通は明示的なmanual smokeに限定する。

## 参照したOpenAI公式docs

- https://developers.openai.com/api/docs/guides/structured-outputs
- https://developers.openai.com/api/docs/api-reference/responses/create
- https://developers.openai.com/api/docs/guides/latest-model

Structured Outputsは `text.format` に `type: json_schema`、`strict: true`、`schema` を指定する方式へ揃える。既存のMinutes providerと同じResponses API経路を使う。

## Provider切り替え

| ENV | 値 | 挙動 |
| --- | --- | --- |
| `CONVERSATION_SUMMARY_GENERATION_PROVIDER` | 未設定 / `deterministic` | deterministic providerを使う |
| `CONVERSATION_SUMMARY_GENERATION_PROVIDER` | `openai` | OpenAI providerを強制する |
| `CONVERSATION_SUMMARY_GENERATION_PROVIDER` | `auto` | `OPENAI_API_KEY` があればOpenAI、なければdeterministic |
| `OPENAI_CONVERSATION_SUMMARY_MODEL` | 未設定 | `gpt-5.5` |
| `OPENAI_RESPONSES_URL` | 未設定 | `https://api.openai.com/v1/responses` |
| `OPENAI_TIMEOUT_SECONDS` | 未設定 | `30` |

通常CIでは `CONVERSATION_SUMMARY_GENERATION_PROVIDER` を未設定または `deterministic` にする。

## 送信前gate

`ConversationSummaryGenerationService` は以下の順で処理する。

1. `conversation_import.status` が `ready_for_ai` または `summary_draft` であることを確認する。
2. gate通過後にproviderを遅延構築する。
3. `summarizing` へ更新する。
4. providerが生成した属性で `ConversationSummaryDraft` を作成する。
5. 成功時は `summary_draft` へ更新する。
6. provider失敗時は `ready_for_ai` へ戻し、retry可能にする。

blocked/draft/archived importではOpenAI providerを構築しない。PII/credential検出はISSUE-038のscan gateで先に処理する。

## Structured Outputs schema

実装schemaは `ConversationSummaryGeneration::OpenaiProvider#response_schema` に定義する。OpenAPIの以下schemaへ合わせる。

- `ConversationDecision`
- `ConversationActionItem`
- `ConversationIssueCandidate`
- `ConversationRequirementCandidate`
- `ConversationRisk`
- `ConversationParticipant`
- `ConversationSourceQuote`

主な方針:

- `additionalProperties: false`
- `strict: true`
- `confidence` は0から1
- `action_items.status` は `open`, `in_progress`, `done`
- `risks.severity` は `low`, `medium`, `high`
- `participants.role` は `requester`, `responder`, `reviewer`, `unknown`
- `source_quotes.quote` は正規化時に500文字へ制限
- `issue_candidates.title` と `requirement_candidates.title` は正規化時に160文字へ制限

## Safe failure contract

| 条件 | code | HTTP | safe_detail |
| --- | --- | --- | --- |
| API key未設定 | `integration_not_connected` | 424 | `OpenAI API key is not configured.` |
| rate limit | provider code | 429 | `OpenAI request was rate limited. Retry after the provider limit resets.` |
| upstream failure | provider code | 502 | `OpenAI request failed. Retry later or check integration settings.` |
| transport failure | `openai_transport_error` | 502 | `OpenAI request failed before a response was received.` |
| invalid response | `invalid_ai_response` | 502 | `AI response did not match the expected DM summary schema.` |

`request_id` がOpenAI responseから得られた場合は、API error details、failed Job、AuditLog metadataへ保存する。raw provider responseやDM本文は保存しない。

## Manual smoke手順

実API smokeは通常CIでは実施しない。実施時は専用の検証データを使い、DM本文に実PII/credentialを入れない。

1. `.env` またはshellで以下を設定する。

```bash
export CONVERSATION_SUMMARY_GENERATION_PROVIDER=openai
export OPENAI_API_KEY=...
export OPENAI_CONVERSATION_SUMMARY_MODEL=gpt-5.5
```

2. Rails APIとFrontendを起動する。

```bash
bundle exec rails server -p 3001
npm run frontend:dev
```

3. Frontendで安全なDMサンプルを作成する。

```text
依頼者: 決定: DM整理をStructured Outputs providerへ接続する。
PM: 対応: invalid responseとrate limitのrequest specを追加する。
Tech Lead: 未決: live smokeの実施タイミングをリリース前に決める。
```

4. DMインポート保存、同意確認、安全チェックを実行する。
5. `ready_for_ai` になったことを確認して整理ドラフト生成を実行する。
6. 生成結果で以下を確認する。

- `provider=openai`
- `generated_by_model` が `OPENAI_CONVERSATION_SUMMARY_MODEL`
- decisions/action_items/open_questionsがschema通り
- source_quotesが短く、本文全文を再出力していない
- Jobが `succeeded`
- AuditLogにraw DM本文が入っていない

7. smoke結果は `docs/review/` または `docs/release/` に日時、モデル、request id、成功/失敗、改善点を追記する。

## 残課題

- 実OpenAI API smokeの実行証跡は未実施。
- 実認証/JWT actor identityはISSUE-039で対応する。
- schema品質は実データ評価と外部AIレビューで継続改善する。
