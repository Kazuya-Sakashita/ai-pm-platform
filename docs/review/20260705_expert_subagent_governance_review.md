# Expert subagent governance review

## 評価日時

2026-07-05 17:25:00 JST

## 評価担当

Codex as Review Orchestrator / Product Owner / CTO / Tech Lead / AI Architect / Security Engineer / QA / DevOps / UI/UX Designer / Business Consultant

## 使用フレームワーク

- G-STACK
- RICE
- MoSCoW
- STRIDE
- OWASP Top 10
- ISO25010
- ADR

## Issue番号

- ISSUE-041
- GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/41

## 評価対象

- `docs/ai/expert_subagents.md`
- `docs/evaluation/expert_review_schema.md`
- `docs/decisions/ADR-0015_expert_subagent_review_operations.md`
- `AGENTS.md` 専門家サブエージェント運用ルール

## 参加Agent

| Agent | Mode | 役割 |
| --- | --- | --- |
| Review Orchestrator | Codex primary | 統合、衝突分析、優先順位、Issue化 |
| Security Engineer + QA Agent | Codex subagent Avicenna | 監査性、セキュリティレビュー完全性、再現性、failure mode |
| Product Owner + CTO + AI Architect Agent | Codex subagent Dewey | プロダクト価値、アーキテクチャ、AI Agent governance、差別化 |
| Codex role-separated experts | Codex primary | Backend、Frontend、DevOps、UX、Business観点の補完 |

## 良かった点

- 専門家レビューをL1 role-separated、L2 Codex subagent、L3 external AI comparisonへ分け、現実的に導入できる段階設計にした。
- Agentごとの責務、対象外、推奨フレームワーク、必須/任意Agentを定義し、全Issueで全Agentを呼ぶ過剰運用を避けた。
- Review Orchestratorを最終統合役とし、単純な多数決ではなくP0セキュリティ、データ保護、監査、後戻りコストを優先するルールにした。
- 共通schemaにverdict、confidence、severity、evidence、recommendation、blocking、limitationsを入れ、根拠のない高評価を抑制した。
- 外部AIを実行できない場合の扱いを明記し、Codex一次レビューと外部AIレビュー待ちを混同しない設計にした。
- 初回パイロット対象をISSUE-039にし、認証/JWT actor identityというP0領域で運用価値を検証できるようにした。
- subagent指摘を反映し、schema_version、target artifact、target version/commit、reproducibility、invalid-review条件、Security/QA blockerを明記した。

## 改善点

- 現時点ではレビュー結果をMarkdownに保存するだけで、DB保存、Review Center表示、検索、横断集計は未実装である。
- Agentごとの評価品質を測るメトリクスがまだ弱い。将来的には指摘採用率、P0見逃し、手戻り削減、レビュー所要時間を測る必要がある。
- L3 external AI comparisonは運用方針だけで、実API連携や外部レビュー取り込みschemaは未実装である。
- Agent出力が長文化した場合の要約、重複排除、重要度正規化はOrchestratorの手作業に依存する。
- サブエージェントを使える環境と使えない環境の差分を、将来の開発者向けにもう少し自動判定できるとよい。

## 優先順位

| Priority | 課題 | 対応 |
| --- | --- | --- |
| P0 | ISSUE-039の認証/JWT actor identityを専門家サブエージェントでパイロットする | 同一Issue内で実施 |
| P1 | Agent別レビューschemaを実運用で調整する | パイロット後にdocs更新 |
| P1 | Review CenterへのAgent別レビュー表示 | 後続Issue候補 |
| P2 | Agent品質メトリクスを定義する | 後続Issue候補 |
| P2 | 外部AIレビュー取り込みschemaを追加する | 後続Issue候補 |

## 次アクション

1. ISSUE-039実装時に、今回定義した専門家サブエージェントレビューを再実行する。
2. Review CenterへのAgent別レビュー表示を後続Issue候補として扱う。
3. 外部AIレビュー取り込みschemaを後続Issue候補として扱う。
4. GitHub Issue #41へ実装結果を同期し、CI成功後にcloseする。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | 専門家レビューをサブエージェント化し、AI PM Platformの評価品質を上げる |
| Strategy | まずMarkdown/ADR/AGENTSで運用を固定し、ISSUE-039で実運用を試す |
| Tactics | L1/L2/L3、Agent責務、共通schema、Orchestrator統合、衝突分析、保存ルール |
| Assessment | 設計として合格。ただしReview Center連動と外部AI比較は後続課題 |
| Conclusion | ISSUE-041はAGENTS追記、パイロットレビュー、GitHub同期後にclose可能 |
| Knowledge | 専門家サブエージェント化は、実装自動化より先に「レビュー判断の監査性」を整えるとAI PMの基盤になる |

## STRIDE / OWASP観点

| 観点 | 評価 | 残リスク |
| --- | --- | --- |
| Spoofing | Agent identityはレビュー文書上のroleであり、production identityではないと明記した | 将来DB保存時は実行主体の署名/監査が必要 |
| Tampering | Review Orchestratorの採用/保留/却下理由を保存する | Markdown改ざん検知はGit履歴に依存 |
| Repudiation | Agent名、mode、対象Issue、判断根拠を保存する | 外部AIレビューの原本保存方式は未定 |
| Information Disclosure | raw chain-of-thoughtを保存せず、監査に必要な入出力要約だけ保存する | 外部AIへ渡す情報のDLP gateは未実装 |
| OWASP A04 | 設計レビューの手順とschemaを固定した | 運用徹底はAGENTSとレビュー文化に依存 |

## 判定

合格。専門家サブエージェントレビューの運用基盤として、設計、schema、ADR、AGENTS追記、ISSUE-039パイロットは妥当。ただし、Review Center連動、外部AI比較、Agent品質メトリクスは後続課題として扱う。

## AIレビュー比較

Codex primaryによるOrchestratorレビューに加え、Codex subagentとしてSecurity/QA観点、Product/CTO/AI観点の並行レビューを実施した。Claude、ChatGPTなど外部AIレビューは未実施。外部AIレビューが追加された場合は、Agent責務、schema、衝突分析、外部AI未実施時の扱いを比較する。
