# 2026-07-08 Requirement OpenAI live readiness review

## 評価日時

2026-07-08 12:12:00 JST

## 評価担当

Codex / AI Architect / Security Engineer / QA / Tech Lead

## Issue番号

ISSUE-052 / GitHub Issue #69

## 対象

- `scripts/requirement-openai-live-readiness.rb`
- `backend/spec/scripts/requirement_openai_live_readiness_spec.rb`
- `docs/release/20260708_requirement_openai_live_smoke_runbook.md`
- `docs/evaluation/20260707_requirement_generation_openai_provider_comparison.md`

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- QA risk-based testing

## 評価サマリー

Requirement生成OpenAI providerのlive評価は、`OPENAI_API_KEY` と `OPENAI_REQUIREMENT_MODEL` が未設定のため未実施である。今回、live評価へ進む前に設定・fixture・出力先をsecret非出力で確認できるreadiness scriptを追加した。

scriptはOpenAI APIを呼ばず、API key値、raw response、model outputを保存しない。現在のsafe failureは `openai_api_key_missing` と `openai_requirement_model_missing` であり、fixtureと出力先は準備済みである。

## 良かった点

- live評価未実施の理由を機械判定できるようになった。
- `OPENAI_API_KEY` の値を出力せず、設定有無だけを証跡化できる。
- model未設定を明示的なblockerにし、暗黙defaultでlive評価してしまうリスクを下げた。
- fixture存在と出力先書き込み可否を先に確認できる。
- `npm run requirements:openai:readiness` で実行できるようにし、operatorの実行手順を短くした。
- `--enforce` 付きの実行手順をrunbookへ明文化できた。

## 改善点

- OpenAI live fixture評価そのものはまだ未実施で、実AI出力品質は未確定である。
- `OPENAI_REQUIREMENT_MODEL` が未設定で、評価対象モデルを固定できていない。
- live評価後のrequest idやsafe errorを評価レポートへどう残すかは、実行結果に応じて追加判断が必要である。
- fixture評価は期待語一致が中心で、自然な言い換えを過小評価する可能性がある。

## 改善案

1. 安全な検証環境で `OPENAI_API_KEY` と `OPENAI_REQUIREMENT_MODEL` を設定する。
2. `scripts/requirement-openai-live-readiness.rb` を再実行し、`safe_failures` が空であることを確認する。
3. `evaluate-requirement-generation.rb --provider openai --enforce` を実行し、結果を `docs/evaluation/` へ保存する。
4. live結果レビューを `docs/review/` へ保存する。
5. P0未達またはCritical failureがある場合はIssue #69をOPEN維持し、prompt/schema/評価rubricの改善Issueへ分割する。

## 優先順位

| 優先度 | 項目 | 理由 |
| --- | --- | --- |
| P0 | `OPENAI_API_KEY` を安全に設定 | live評価実行の前提 |
| P0 | `OPENAI_REQUIREMENT_MODEL` を設定 | 評価対象を監査可能にするため |
| P0 | `safe_failures` 空のreadiness証跡 | 誤実行とsecret漏えいを防ぐ |
| P1 | live評価Markdown保存 | Issue #69の完了判定に必要 |
| P2 | semantic評価の追加検討 | OpenAIの言い換えを適切に評価するため |

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | Requirement OpenAI live評価を安全かつ再現可能にする |
| Strategy | 実API呼び出し前にsecret非出力のreadiness gateを置く |
| Tactics | safe JSON、failure別next action、runbook、RSpec |
| Assessment | live評価の準備は前進したが、API key/model未設定のため未完了 |
| Conclusion | readiness scriptは採用。Issue #69はlive評価までOPEN |
| Knowledge | 外部AI評価は、キーの有無だけでなくmodel名と出力証跡を固定してから行う |

## STRIDE / OWASP観点

- Spoofing: model名未設定のまま評価すると対象が曖昧になるためblockerにした。
- Tampering: fixture pathとoutput pathを明示し、評価対象を固定した。
- Repudiation: readiness JSON、評価Markdown、レビュー文書を保存する運用へ接続した。
- Information Disclosure: API key、raw response、request payload全文を出力しない。
- Denial of Service: live評価は手動実行に限定し、通常CIへ外部API依存を入れない。
- OWASP A09: provider失敗時もsafe error codeで扱い、raw upstream responseを保存しない。

## 検証結果

- `ruby -c scripts/requirement-openai-live-readiness.rb`: Syntax OK
- `bundle exec rspec spec/scripts/requirement_openai_live_readiness_spec.rb`: 3 examples, 0 failures
- `.env` 読込後の `ruby scripts/requirement-openai-live-readiness.rb`: exit 1
- `npm run requirements:openai:readiness`: exit 1
  - safe failures: `openai_api_key_missing`, `openai_requirement_model_missing`
- `OPENAI_API_KEY=dummy-openai-key OPENAI_REQUIREMENT_MODEL=gpt-test npm run requirements:openai:readiness`: exit 0
  - safe failures: なし
- `bundle exec rspec`: 408 examples, 0 failures
- `RAILS_ENV=test bundle exec rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、型生成OK
- `npm run display:check`: Display labels OK
- `npm run frontend:build`: success
- `git diff --check`: 問題なし
  - safe failures: `openai_api_key_missing`, `openai_requirement_model_missing`
  - next actions: `OPENAI_API_KEY` 設定、`OPENAI_REQUIREMENT_MODEL` 設定
  - fixture_present: true
  - output_directory_writable: true

保存していない情報:

- OpenAI API key
- Authorization header
- raw provider response
- request payload全文
- model output
- PII / credential / token

## 次アクション

1. `OPENAI_API_KEY` と `OPENAI_REQUIREMENT_MODEL` を安全な検証環境へ設定する。
2. readiness scriptを再実行し、`safe_failures` 空の証跡を保存する。
3. OpenAI live評価を実行し、`docs/evaluation/20260708_requirement_generation_openai_live.md` を保存する。
4. live評価レビューを作成し、Issue #69のクローズ可否を判断する。

## 結論

Requirement OpenAI live評価へ進むための安全な準備は改善された。ただし、世界レベルSaaS基準ではreadiness script追加だけでは完了ではない。実OpenAI APIを使ったfixture評価とレビュー結果が保存されるまで、Issue #69は継続OPENとする。
