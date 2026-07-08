# Requirement生成評価 safe failure report

## メタデータ

- 生成日時: 2026-07-08T19:50:40Z
- Issue番号: ISSUE-003
- Fixture version: 2026-07-06.requirement-generation.v1
- Provider: openai
- 判定: 基準未判定
- 選択ケース数: 1
- 完了ケース数: 0

## Safe failure

- error_class: RequirementGeneration::ProviderError
- error_code: insufficient_quota
- http_status: too_many_requests
- safe_detail: OpenAI request was rate limited. Retry after the provider limit resets.
- request_id_present: true
- next_case_id: CASE-RQ-001

## 完了済みケース

- なし

## 次アクション

- OpenAI Platform側のusage、billing、rate limit、model accessを確認する。
- 時間を置いてから `--case-id CASE-RQ-001` または `--limit 1` で低負荷に再実行する。
- `--delay-seconds` を指定してcase間隔を空ける。
- 成功後に通常の評価Markdownとreview docを保存する。

## 保存していない情報

- API key
- Authorization header
- raw provider response
- request payload全文
- model output
- PII / credential / token
