# 2026-07-08 Requirement OpenAI live 429 review

## 評価日時

2026-07-08 12:30:04 JST

## 評価担当

Codex / AI Architect / Security Engineer / QA / Tech Lead

## Issue番号

ISSUE-052 / GitHub Issue #69

## 対象

- `npm run requirements:openai:readiness`
- `scripts/evaluate-requirement-generation.rb --provider openai --enforce --quiet`
- `docs/evaluation/fixtures/requirement_generation/cases.json`

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- QA risk-based testing

## 評価サマリー

`OPENAI_API_KEY` と `OPENAI_REQUIREMENT_MODEL` の設定後、Requirement OpenAI live readinessは `safe_failures` なしで合格した。その後、OpenAI providerでlive fixture評価を実行したが、OpenAI APIがHTTP 429を返したため評価は停止した。

HTTP 429はrate limit、quota、billing、model access制約などの外部API側制約で発生し得る。現時点ではOpenAI出力品質を採点できていないため、Issue #69はクローズ不可である。

## 良かった点

- readiness scriptにより、API keyとmodel設定、fixture、出力先は安全に確認できた。
- API key値、raw response、model outputを表示、保存せずに停止できた。
- `--enforce` 付き評価で、未判定状態を合格扱いにしなかった。
- 429をIssue #69の完了判定blockerとして文書化できた。

## 改善点

- OpenAI live fixture評価は未完了で、実AI出力品質は未確認である。
- 429の詳細原因はOpenAI Platform側のusage、billing、rate limit、model accessを確認しないと切り分けられない。
- 現在の評価scriptはProviderError発生時にsafeなMarkdown reportを自動保存しない。
- 成功時のrequest id保存方針はあるが、今回の429ではrequest idを証跡化していない。

## 改善案

1. OpenAI Platformでusage、billing、rate limit、model accessを確認する。
2. 時間を置く、または利用上限を調整してからlive評価を再実行する。
3. ProviderError発生時もsafe failure reportを保存できるよう、評価scriptの改善を検討する。
4. live評価が成功したら、P0未達、Critical failure、model名、実行日時、外部AIレビュー待ち有無をreview docへ保存する。

## 優先順位

| 優先度 | 項目 | 理由 |
| --- | --- | --- |
| P0 | Platform側rate/quota/billing/model access確認 | 429解消なしにlive評価できない |
| P0 | live評価再実行 | Issue #69の完了条件 |
| P1 | ProviderError時のsafe report自動保存 | 次回の失敗証跡を安定化する |
| P2 | semantic評価の検討 | OpenAIの自然な言い換えを適切に評価するため |

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | Requirement OpenAI live評価を完了し、Issue #69のクローズ可否を判断する |
| Strategy | readiness合格後にfixture評価を実行し、P0基準で判定する |
| Tactics | secret非出力、`--enforce`、safe failure記録、review保存 |
| Assessment | readinessは合格したが、HTTP 429によりlive評価は未完了 |
| Conclusion | Issue #69は継続OPEN。Platform側制約解消後に再実行する |
| Knowledge | 外部AI live評価は、設定完了とAPI利用可能性を分けて判定する必要がある |

## STRIDE / OWASP観点

- Spoofing: model設定済みは確認したが、model access可否はPlatform側確認が必要。
- Tampering: fixtureと出力先は固定されており、評価対象の改ざんは検出しやすい。
- Repudiation: 429停止結果をevaluation/review/Issueへ保存する。
- Information Disclosure: API key、raw response、payload全文、model outputは保存していない。
- Denial of Service: 429時に連続再試行しない判断は妥当。
- OWASP A09: provider失敗時にraw upstream responseを保存しない方針を維持した。

## 検証結果

- `npm run requirements:openai:readiness`: safe failuresなし
- `bundle exec ruby ../scripts/evaluate-requirement-generation.rb --provider openai --fixtures docs/evaluation/fixtures/requirement_generation/cases.json --output docs/evaluation/20260708_requirement_generation_openai_live.md --enforce --quiet`: HTTP 429で停止
- `docs/evaluation/20260708_requirement_generation_openai_live.md`: 未作成

保存していない情報:

- OpenAI API key
- Authorization header
- raw provider response
- request payload全文
- model output
- PII / credential / token

## 次アクション

1. OpenAI Platform側でusage、billing、rate limit、model accessを確認する。
2. 制約解消後にOpenAI live fixture評価を再実行する。
3. 成功した場合は `docs/evaluation/20260708_requirement_generation_openai_live.md` とlive reviewを保存する。
4. P0未達またはCritical failureがある場合は、prompt/schema/rubric改善Issueへ分割する。

## 結論

設定確認は完了したが、OpenAI APIのHTTP 429によりlive評価は未完了である。世界レベルSaaS基準では、429停止を合格扱いにせず、Platform側制約を解消して再実行する必要がある。Issue #69は継続OPENとする。
