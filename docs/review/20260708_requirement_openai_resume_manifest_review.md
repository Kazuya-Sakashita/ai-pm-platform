# 2026-07-08 Requirement OpenAI safe resume manifest review

## 評価日時

2026-07-08 19:32:00 JST

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

OpenAI live fixture評価が429やquota制約で途中停止した場合に、次回どこから再開するかを人間の記憶に頼らないよう、`--resume-output` を追加した。

resume manifestはsafe JSONで、fixture issue/version、provider、selected case、completed case、next case、safe error、推奨CLI引数だけを保存する。API key、Authorization header、raw provider response、request payload全文、model output、raw request idは保存しない。

## 良かった点

- 失敗時にMarkdown reportだけでなく、機械処理しやすいresume JSONを残せる。
- `next_case_id` と `recommended_cli_args` により、`CASE-RQ-001` のような再開点を明確にできる。
- 429 / quota / rate limit系では `--delay-seconds 10` を推奨引数に含め、連続再試行を避けやすい。
- raw request idは保存せず、`request_id_present` のbooleanだけに留めた。
- Runbookへ `--resume-output` を追加し、manual smoke手順と実装を同期した。

## 改善点

- resume manifestは作成のみで、自動再実行やGitHub Issue同期は行わない。
- 複数日にまたがる評価のmergeやcase別成果物管理は未実装である。
- JSON schemaとしてのmanifest contractはまだ独立定義していない。

## 優先順位

| 優先度 | 項目 | 理由 |
| --- | --- | --- |
| P0 | `--resume-output` をlive評価手順に使う | 途中停止後の再開点を失わないため |
| P1 | resume manifestのJSON schema化 | 将来の自動化とIssue同期に備えるため |
| P1 | 成功caseごとの成果物分割 | 長いfixture評価のresume精度を上げるため |
| P2 | safe failure / resume manifestのGitHub Issue同期 | 手動転記漏れを減らすため |

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | OpenAI live評価の途中停止から安全に再開できるようにする |
| Strategy | ProviderError時にsafe JSON manifestを保存する |
| Tactics | `--resume-output`、safe fields、RSpec、runbook更新 |
| Assessment | 再開性は改善。ただしlive評価成功は外部quota制約解消待ち |
| Conclusion | 改善は採用。Issue #69はlive評価成功までOPEN |
| Knowledge | 外部AI評価の運用では、人間向けreportと機械向けresume stateを分けると安全性と再現性が上がる |

## STRIDE / OWASP観点

- Spoofing: selected/completed/next caseを保存し、再開対象の取り違えを防ぐ。
- Tampering: fixture issue/versionを保存し、別fixtureで再開してしまうリスクを下げる。
- Repudiation: safe failureのerror codeとhttp statusを保存し、停止理由を追える。
- Information Disclosure: API key、Authorization header、raw provider response、payload全文、model output、raw request idは保存しない。
- Denial of Service: rate/quota系ではdelay付き再実行を推奨し、連続再試行を避ける。
- OWASP A09: upstream失敗詳細をsafe detailに制限する。

## 検証結果

- `backend/spec/scripts/evaluate_requirement_generation_spec.rb` にresume manifest specを追加。
- `--resume-output` がCLI経由でsafe JSONを書き出すことをRSpecで確認。
- manifestに `next_case_id`、`completed_case_ids`、`recommended_cli_args` が入ることを確認。
- manifestにraw error messageとraw request idが入らないことを確認。
- `ruby -c scripts/evaluate-requirement-generation.rb`: Syntax OK
- `bundle exec rspec spec/scripts/evaluate_requirement_generation_spec.rb`: 9 examples, 0 failures
- `bundle exec rspec`: 414 examples, 0 failures
- `npm run display:check`: Display labels OK
- 実secret値パターン確認: 検出なし

保存していない情報:

- OpenAI API key
- Authorization header
- raw provider response
- request payload全文
- model output
- raw request id
- PII / credential / token

## 次アクション

1. OpenAI Platform側のquota / billing / rate limit / model accessを確認する。
2. `--resume-output` を指定して `CASE-RQ-001` から再実行する。
3. 成功時は通常の評価Markdownとlive reviewを保存する。
4. partial successが増えたら、manifest schema化とcase別成果物分割を後続Issue化する。

## 結論

safe resume manifestにより、外部API制約で止まったOpenAI live評価をより安全に再開できる。ただし実OpenAI出力品質はまだ未判定であり、Issue #69は継続OPENとする。
