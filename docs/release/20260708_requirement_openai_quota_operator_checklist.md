# Requirement OpenAI quota運用チェックリスト

## 目的

Requirement生成OpenAI providerのlive評価が `insufficient_quota` / `too_many_requests` で停止した場合に、運用担当者がOpenAI Platform側の設定を安全に切り分け、`CASE-RQ-001` から再実行できるようにする。

このチェックリストは、Issue #69をクローズする前の外部条件確認に使う。

関連:

- `docs/release/20260708_requirement_openai_live_smoke_runbook.md`
- `docs/review/20260708_requirement_openai_live_case_001_safe_failure_review.md`
- `docs/review/20260708_requirement_openai_resume_manifest_review.md`
- OpenAI rate limits: `https://platform.openai.com/docs/guides/rate-limits`
- OpenAI models: `https://platform.openai.com/docs/models`

## 現在のブロッカー

2026-07-08時点の結果:

- `.env` 読込条件では `OPENAI_API_KEY` と `OPENAI_REQUIREMENT_MODEL` のreadinessは合格
- `CASE-RQ-001` の低負荷live評価は `insufficient_quota` / `too_many_requests` で停止
- OpenAI出力品質は基準未判定
- 成功評価Markdownは未生成
- safe failure reportとresume manifest対応は追加済み

## 完了条件

- OpenAI Platform側でbilling、usage、limits、model access、API key所属projectを確認済み
- `.env` 読込条件で `npm run requirements:openai:readiness` の `safe_failures` が空
- `CASE-RQ-001` のlive評価が成功する、または失敗時にsafe failure report / safe resume JSONが保存される
- API key、Authorization header、raw provider response、request payload全文、model output、PIIを保存していない
- deterministic providerとの差分評価へ進める状態になっている
- 結果レビューを `docs/review/` に保存し、GitHub Issue #69へ同期している

## 手順1: local readinessを正しい環境で確認する

`npm run requirements:openai:readiness` は `.env` を自動読込しない。必ず `.env` をsourceしてから実行する。

```sh
set -a
source .env
set +a
npm run requirements:openai:readiness
```

期待値:

- `openai_api_key_configured`: true
- `openai_requirement_model_configured`: true
- `openai_responses_url_https`: true
- `fixture_present`: true
- `output_directory_writable`: true
- `safe_failures`: 空

失敗した場合:

- `openai_api_key_missing`: runtimeまたは `.env` へ `OPENAI_API_KEY` を設定する
- `openai_requirement_model_missing`: `OPENAI_REQUIREMENT_MODEL` を設定する
- `openai_responses_url_not_https`: `OPENAI_RESPONSES_URL` をHTTPS endpointへ戻す

## 手順2: API keyの所属project / organizationを確認する

OpenAI Platformで、設定したAPI keyが意図したproject / organizationに属していることを確認する。

確認観点:

- API keyが削除、無効化、rotation済みではない
- live評価に使うprojectのkeyである
- billing / usage / limitsを確認しているprojectとAPI keyのprojectが一致している
- secret storeとローカル `.env` のどちらを使っているかが明確である

禁止:

- API key値をdocs、Issue、PR、AIチャット、スクリーンショットへ貼る
- 複数projectのkeyを混在させる
- 古いkeyのままquota確認だけ別projectで行う

## 手順3: billing / usage / limitsを確認する

OpenAI Platformで、billing、usage、limitsを確認する。

確認観点:

- billingが有効である
- projectまたはorganizationのusage上限に達していない
- monthly budget / hard limitに達していない
- 対象modelのrate limit、request limit、token limitに達していない
- 一時的なrate limitの場合は、連続再試行せず時間を置く

対応:

- usage上限に達している場合は、上限調整またはbilling設定を見直す
- rate limitの場合は、`--case-id`、`--delay-seconds`、`--limit` を使って低負荷に再実行する
- quota不足が継続する場合は、OpenAI Platform側のproject / billing / limits設定を見直す

## 手順4: model accessを確認する

`OPENAI_REQUIREMENT_MODEL` に設定したmodelが、対象projectで利用可能か確認する。

確認観点:

- model名のtypoがない
- 対象projectで利用可能なmodelである
- Responses APIで利用する前提に合っている
- 評価中にmodel名を変える場合は、Issue #69へ理由を残す

運用方針:

- live評価中にmodelを変更した場合、deterministic providerとの比較条件が変わるため、評価Markdownとreview docへ必ず記録する
- model変更は「quota回避」だけを目的に雑に行わない
- 低コストmodelへ一時変更する場合も、目的、リスク、差分をレビューへ残す

## 手順5: CASE-RQ-001から低負荷再実行する

billing / usage / limits / model accessを確認した後、同じcaseから再実行する。

```sh
cd backend
set -a
source ../.env
set +a
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

成功時:

- 評価Markdownを保存する
- P0未達とCritical failureを確認する
- deterministic providerとの差分評価へ進む

失敗時:

- safe failure reportを保存する
- safe resume JSONを保存する
- raw provider response、request payload全文、model outputは保存しない
- 失敗理由をIssue #69へ同期する

## safe failure対応表

| safe failure / error code | 対応 |
| --- | --- |
| `openai_api_key_missing` | `OPENAI_API_KEY` をsecret storeまたは `.env` へ設定する |
| `openai_requirement_model_missing` | `OPENAI_REQUIREMENT_MODEL` を設定する |
| `insufficient_quota` | billing、usage上限、project budget、API key所属projectを確認する |
| `rate_limit_exceeded` | `--case-id`、`--limit 1`、`--delay-seconds 10` で低負荷再実行する |
| `too_many_requests` | usage / rate limitを確認し、連続再試行せず時間を置く |
| `model_not_found` | model名、project access、Responses API対応を確認する |
| `invalid_api_key` | keyの有効性、project所属、rotation状態を確認する |

## 保存するレビュー項目

`docs/review/YYYYMMDD_requirement_openai_live_gate_evidence_review.md` として保存する。

- 評価日時
- 評価担当
- 使用フレームワーク
- commit SHA
- provider
- model名
- case id
- readiness結果
- billing / usage / limits / model access確認結果の要約
- 評価Markdownまたはsafe failure report
- safe resume JSONの有無
- P0未達件数
- Critical failure件数
- 良かった点
- 改善点
- 優先順位
- 次アクション
- Issue番号: ISSUE-052 / GitHub Issue #69

## クローズ判定

Issue #69は、以下がすべて揃った場合だけクローズ候補にする。

- OpenAI live評価がP0基準を満たしている
- Critical failureが0件
- deterministic providerとの差分評価が保存されている
- API key、raw response、payload全文、model output、PIIを保存していない
- review docとGitHub Issue commentへ証跡が同期されている
- 残リスクがない、または明示的にリスク受容されている

`insufficient_quota` / `too_many_requests` のままでは、OpenAI出力品質が未判定のためIssue #69はOPENを継続する。
