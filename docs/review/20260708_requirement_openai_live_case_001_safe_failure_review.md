# 2026-07-08 Requirement OpenAI live CASE-RQ-001 safe failure review

## 評価日時

2026-07-08 19:05:00 JST

## 評価担当

Codex / AI Architect / Security Engineer / QA / Tech Lead

## Issue番号

ISSUE-052 / GitHub Issue #69

## 対象

- `docs/evaluation/20260708_requirement_generation_openai_live_case_001_failure.md`
- `scripts/evaluate-requirement-generation.rb`
- `docs/issue/ISSUE-052_requirement_openai_provider_comparison.md`

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- QA risk-based testing

## 評価サマリー

OpenAI live fixture評価を1ケース単位で進められる状態になったが、`CASE-RQ-001` はOpenAI API側の `insufficient_quota` / `too_many_requests` により基準未判定で停止した。

safe failure reportには完了ケース数、次に再開すべきcase、safe detail、request id存在有無が保存されている。一方で、API key、Authorization header、raw provider response、request payload全文、model output、PII、credential、tokenは保存されていない。

## 良かった点

- `--failure-output` により、ProviderErrorをstack traceではなくsafe Markdown証跡として残せている。
- `CASE-RQ-001` から再開すべきことが明示され、再実行時の取り違えリスクが低い。
- HTTP 429を合格扱いにせず、OpenAI出力品質を「基準未判定」として扱えている。
- request idは存在有無のみ保存し、raw upstream responseやmodel outputを保存していない。
- Platform側制約の確認、低負荷再実行、delay指定という次アクションが明確である。

## 改善点

- OpenAI live fixture評価はまだ1ケースも完了していない。
- `insufficient_quota` の解消にはOpenAI Platform側のusage、billing、rate limit、model access確認が必要で、このリポジトリ内だけでは完了できない。
- partial resumeは手動の `--case-id` 指定に依存しており、自動resume manifestは未実装である。
- safe failure reportはGitHub Issueへ自動同期されないため、Issue台帳とGitHub Issueへの転記が運用依存である。

## 優先順位

| 優先度 | 項目 | 理由 |
| --- | --- | --- |
| P0 | OpenAI Platform側のquota / billing / rate limit / model access確認 | live評価を再開できないため |
| P0 | `CASE-RQ-001` から低負荷再実行 | 評価の継続性を保つため |
| P1 | safe failure reportをIssue同期対象へ含める | 外部制約で止まった証跡を失わないため |
| P2 | resume manifest設計 | 複数case評価の運用性を上げるため |

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | OpenAI live評価を安全に再開可能な状態へ前進させる |
| Strategy | 1ケース単位のsafe failure reportを証跡化し、次の再実行点を固定する |
| Tactics | `CASE-RQ-001`、safe detail、未保存情報、次アクションを文書化する |
| Assessment | 証跡化は前進。ただし外部quota制約によりlive品質評価は未完了 |
| Conclusion | Issue #69は継続OPEN |
| Knowledge | 外部AI評価は、成功証跡だけでなく再開可能なsafe failure証跡も完成条件に近い価値を持つ |

## STRIDE / OWASP観点

- Spoofing: 再開caseを明示し、評価対象の取り違えを防ぐ。
- Tampering: fixture versionとcase idを証跡に残し、評価対象の追跡性を保つ。
- Repudiation: safe failure reportとreview docで、429停止を監査できる。
- Information Disclosure: API key、Authorization header、raw provider response、request payload全文、model outputは保存していない。
- Denial of Service: 連続再試行せず、Platform側制約確認とdelay付き低負荷再実行を次アクションにした。
- OWASP A09: upstream失敗詳細をsafe detailへ制限している。

## 検証結果

- `docs/evaluation/20260708_requirement_generation_openai_live_case_001_failure.md` を確認。
- 判定: 基準未判定。
- 完了ケース数: 0。
- safe failure: `RequirementGeneration::ProviderError` / `insufficient_quota` / `too_many_requests`。
- next case: `CASE-RQ-001`。

保存していない情報:

- OpenAI API key
- Authorization header
- raw provider response
- request payload全文
- model output
- PII / credential / token

## 次アクション

1. OpenAI Platform側のusage、billing、rate limit、model accessを確認する。
2. 制約解消後に `--case-id CASE-RQ-001 --delay-seconds 10 --failure-output docs/evaluation/20260708_requirement_generation_openai_live_case_001_failure.md` 相当で低負荷再実行する。
3. 成功時は正式なOpenAI live評価Markdownとreview docを保存する。
4. 失敗時はsafe failure reportを更新し、Issue #69へ同期する。

## 結論

safe failure証跡化は有効に機能している。ただしOpenAI出力品質はまだ未判定であり、世界レベルSaaS基準ではIssue #69を完了扱いにしない。外部quota制約の解消後、`CASE-RQ-001` から再実行する。
