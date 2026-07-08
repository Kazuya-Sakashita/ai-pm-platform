# Requirement OpenAI Live Smoke Runbook

## Purpose

Requirement生成OpenAI providerを、通常CIへ外部API依存を持ち込まずにlive評価する。Issue #69を閉じる前に、実OpenAI出力が既存fixtureのP0基準とCritical failure基準を満たすか確認する。

## Scope

- Requirement生成評価fixtureのOpenAI provider実行
- `OPENAI_API_KEY` と `OPENAI_REQUIREMENT_MODEL` の設定確認
- safe failure、P0未達、Critical failureの証跡保存
- deterministic baselineとの比較

Out of scope:

- 本番常時OpenAI利用への切替
- prompt最適化の長期実験
- 実ユーザー議事録やPIIを含むデータでの評価

## Secret Handling

API key、raw provider response、raw request body、OpenAI request payload全文、個人情報をdocs、Issue、PR、AI chatへ保存しない。

設定はsecret storeまたはローカル `.env` で行う。

```sh
OPENAI_API_KEY=...
OPENAI_REQUIREMENT_MODEL=...
OPENAI_RESPONSES_URL=https://api.openai.com/v1/responses
```

`OPENAI_RESPONSES_URL` は通常設定不要。変更する場合もHTTPS endpointだけを使う。

## Readiness

まずsecret値を出力しないreadiness scriptを実行する。

```sh
set -a
source .env
set +a
npm run requirements:openai:readiness
```

Expected:

- `openai_api_key_configured` が `true`
- `openai_requirement_model_configured` が `true`
- `openai_responses_url_https` が `true`
- `fixture_present` が `true`
- `output_directory_writable` が `true`
- `safe_failures` が空

`safe_failures` が空でない場合は、`next_actions` に従って設定を修正してから再実行する。

## Live Evaluation

readiness合格後にだけ実行する。

```sh
cd backend
set -a
source ../.env
set +a
bundle exec ruby ../scripts/evaluate-requirement-generation.rb \
  --provider openai \
  --fixtures docs/evaluation/fixtures/requirement_generation/cases.json \
  --output docs/evaluation/20260708_requirement_generation_openai_live.md \
  --failure-output docs/evaluation/20260708_requirement_generation_openai_live_failure.md \
  --resume-output docs/evaluation/20260708_requirement_generation_openai_live_resume.json \
  --enforce \
  --quiet
```

Expected:

- 平均点がfixture閾値以上
- P0未達が0件
- Critical failureが0件
- 出力MarkdownにAPI key、raw response、秘密情報、PIIが含まれない

429などのprovider失敗が出た場合は、`--failure-output` のsafe reportを保存し、通常のlive評価完了とは扱わない。
再開点を機械的に残したい場合は、`--resume-output` のsafe JSONも保存する。resume JSONにはcase id、provider、safe error、推奨CLI引数だけを含め、API key、raw response、request payload、model outputは含めない。

低負荷で再実行する場合:

```sh
bundle exec ruby ../scripts/evaluate-requirement-generation.rb \
  --provider openai \
  --fixtures docs/evaluation/fixtures/requirement_generation/cases.json \
  --case-id CASE-RQ-001 \
  --delay-seconds 10 \
  --output docs/evaluation/20260708_requirement_generation_openai_live_case_001.md \
  --failure-output docs/evaluation/20260708_requirement_generation_openai_live_case_001_failure.md \
  --resume-output docs/evaluation/20260708_requirement_generation_openai_live_case_001_resume.json \
  --enforce \
  --quiet
```

複数caseを続ける場合も `--delay-seconds` を指定し、429時は連続再試行しない。

## Evidence

保存してよい証跡:

- readiness scriptのsafe JSON
- 評価Markdown
- provider名
- model名
- 実行日時
- P0未達件数
- Critical failure件数
- safe error code
- safe failure report
- safe resume JSON

保存してはいけない証跡:

- `OPENAI_API_KEY`
- Authorization header
- raw provider response全文
- request payload全文
- 実ユーザーの議事録本文
- PII、credential、token

## Review Gate

live評価後、`docs/review/YYYYMMDD_requirement_openai_live_smoke_review.md` を作成し、以下を記録する。

- 評価日時
- 評価担当
- 使用フレームワーク
- 良かった点
- 改善点
- 優先順位
- 次アクション
- Issue番号
- P0未達とCritical failureの有無
- Issue #69を閉じるか、OPEN維持するか

## Completion

Issue #69を閉じられるのは、live評価がP0基準を満たし、レビュー文書と評価結果が保存され、残リスクがない、または残リスクを明示受容した場合だけである。
