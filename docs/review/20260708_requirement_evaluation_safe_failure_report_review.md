# 2026-07-08 Requirement評価safe failure reportレビュー

## 評価日時

2026-07-08 18:36:00 JST

## 評価担当

Codex / AI Architect / Security Engineer / QA / Tech Lead

## Issue番号

ISSUE-052 / GitHub Issue #69

## 対象

- `scripts/evaluate-requirement-generation.rb`
- `backend/spec/scripts/evaluate_requirement_generation_spec.rb`
- `docs/release/20260708_requirement_openai_live_smoke_runbook.md`
- `docs/issue/ISSUE-052_requirement_openai_provider_comparison.md`

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- QA risk-based testing

## 評価サマリー

OpenAI live fixture評価がHTTP 429で停止した際、従来の評価scriptはstack traceで終了し、safeな失敗レポートを自動保存できなかった。今回、`--failure-output` を追加し、ProviderError発生時にAPI key、raw provider response、request payload全文、model outputを保存せず、safe failure reportだけをMarkdownで残せるようにした。

また、429再発時に負荷を下げて再実行できるよう、`--case-id`、`--limit`、`--delay-seconds` を追加した。

## 良かった点

- ProviderError発生時もsafe failure reportを保存できるようになった。
- `--case-id` と `--limit` により、1ケースずつ低負荷で再実行できる。
- `--delay-seconds` により、case間隔を空けてrate limitを踏みにくくできる。
- 完了済みcase数、next case、safe detail、request_id存在有無を保存できる。
- raw error message、API key、raw response、model outputをreportへ含めない設計にした。

## 改善点

- OpenAI live fixture評価そのものは、Platform側429が解消するまで未完了である。
- safe failure reportはMarkdown保存までで、GitHub Issueへの自動同期は行わない。
- partial success後のresumeは `--case-id` による手動指定であり、自動resume stateはまだない。
- request idは存在有無のみ保存しており、問い合わせ時に必要な場合の扱いは別途運用判断が必要である。

## 改善案

1. Platform側rate/quota制約が解消したら、`--case-id CASE-RQ-001 --delay-seconds 10` で低負荷再実行する。
2. 複数caseを実行する場合は `--failure-output` を必ず指定する。
3. partial successが増えた場合は、resume manifestまたはcaseごとの出力分割を検討する。
4. request idを保存する必要が出た場合は、secretではないことを確認したうえで保存ポリシーをADR化する。

## 優先順位

| 優先度 | 項目 | 理由 |
| --- | --- | --- |
| P0 | `--failure-output` をlive評価手順へ組み込む | 失敗時の証跡を安全に残すため |
| P0 | 低負荷再実行オプションを使う | 429再発を抑えるため |
| P1 | partial resume設計 | 複数case評価の運用性を上げるため |
| P2 | request id保存ポリシー | Provider問い合わせ時の監査性向上 |

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | OpenAI live評価の失敗を安全に証跡化し、再実行しやすくする |
| Strategy | failure output、case selection、delayを評価scriptへ追加する |
| Tactics | safe Markdown、ProviderError mapping、RSpec、runbook更新 |
| Assessment | 429時の運用性は改善。ただしlive評価成功は外部制約解消待ち |
| Conclusion | 改善は採用。Issue #69はlive評価成功までOPEN |
| Knowledge | 外部AI評価では、失敗時のsafe reportと低負荷再実行手段を最初から用意する |

## STRIDE / OWASP観点

- Spoofing: 評価対象caseを明示できるため、実行対象の取り違えを減らせる。
- Tampering: failure reportにfixture versionとnext caseを残し、証跡の追跡性を上げた。
- Repudiation: stack traceではなくsafe Markdownとして保存できる。
- Information Disclosure: raw error message、API key、raw response、payload全文、model outputは保存しない。
- Denial of Service: `--delay-seconds` とcase絞り込みでrate limit再発リスクを下げる。
- OWASP A09: upstream失敗の詳細をsafe detailへ制限する。

## 検証結果

- `ruby -c scripts/evaluate-requirement-generation.rb`: Syntax OK
- `bundle exec rspec spec/scripts/evaluate_requirement_generation_spec.rb spec/scripts/requirement_openai_live_readiness_spec.rb`: 10 examples, 0 failures
- `bundle exec rspec`: 412 examples, 0 failures
- `RAILS_ENV=test bundle exec rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、型生成OK
- `npm run display:check`: Display labels OK
- `npm run frontend:build`: success
- `bundle exec ruby ../scripts/evaluate-requirement-generation.rb --provider deterministic --limit 1 --delay-seconds 0 --output docs/evaluation/20260708_requirement_generation_eval_safe_report_deterministic_check.md --quiet --enforce`: 合格
- `OPENAI_API_KEY` 未設定で `--provider openai --limit 1 --failure-output /private/tmp/requirement-openai-safe-failure.md --quiet`: safe failure report作成

保存していない情報:

- OpenAI API key
- Authorization header
- raw provider response
- raw error message
- request payload全文
- model output
- PII / credential / token

## 次アクション

1. Platform側rate/quota制約解消後に、`--case-id` と `--delay-seconds` を使ってOpenAI live評価を再実行する。
2. 成功時は正式なlive評価Markdownとlive reviewを保存する。
3. 失敗時は `--failure-output` のsafe reportを保存し、Issue #69へ同期する。
4. partial resumeが必要になったら後続Issue化する。

## 結論

HTTP 429を受けた評価運用の弱点は改善された。ただし、実OpenAI出力品質はまだ未判定である。Issue #69は、OpenAI live評価がP0基準を満たすまで継続OPENとする。
