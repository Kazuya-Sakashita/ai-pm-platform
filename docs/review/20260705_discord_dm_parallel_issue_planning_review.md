# Discord DM並行Issue分割レビュー

## 評価日時

2026-07-05 19:20 JST

## 評価担当

Codex / Product Owner / CTO / Tech Lead / AI Architect / Backend Architect / Frontend Architect / Security Engineer / QA / UI/UX Designer / Product Manager

外部AIレビュー: Claude / ChatGPTレビューは未実施。Codex一次レビューとして保存し、外部レビュー結果が追加された場合は差分分析を追記する。

## 使用フレームワーク

- G-STACK
- RICE
- MoSCoW
- STRIDE
- ISO25010

## Issue番号

- ISSUE-035
- ISSUE-036
- ISSUE-037
- ISSUE-038
- GitHub Issue #35: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/35
- GitHub Issue #36: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/36
- GitHub Issue #37: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/37
- GitHub Issue #38: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/38

## 良かった点

- ISSUE-022の残タスクを、AI provider、編集UI、Review Center、PII/マスキングの4系統に分けた。
- #29/#30/#32のP0セキュリティ系と競合しにくい、並行実装しやすい単位にした。
- それぞれOpenAPI、Backend、Frontend、ReviewOps、Securityの責務境界を明確にした。
- 「実装したいこと」だけでなく、完了条件、非スコープ、レビュー保存条件をIssueごとに明記した。

## 改善点

- #35 Structured Outputs providerは実API smokeやmodel選定が未確定で、外部API依存を通常CIに混ぜない設計が必要。
- #36編集UIはworkspace-client肥大化をさらに進める可能性があるため、component分割と合わせて検討すべき。
- #37 Review Center連動は認証/認可未実装の影響を受けるため、MVPでは擬似レビュー担当者に留める必要がある。
- #38 PII検出はfalse positive/false negativeが避けられないため、検出強化だけで安全と判定してはならない。

## 優先順位

| 優先度 | Issue | 理由 |
| --- | --- | --- |
| P1 | ISSUE-038 | AI送信前安全性に関わり、#35の前提品質を上げる |
| P1 | ISSUE-035 | AI PMの中核価値であるDM整理品質に直結 |
| P1 | ISSUE-036 | AI誤要約修正と人間レビュー品質に直結 |
| P1 | ISSUE-037 | ReviewOps/AI PMの統制体験に直結 |

## 次アクション

1. GitHub Issue #35〜#38として登録する。（完了）
2. 登録URLを各ローカルIssue台帳へ反映する。（完了）
3. ISSUE-022へ並行Issue分割結果をコメントする。（完了）
4. 次の実装候補は、P0 security blockerがなければISSUE-038またはISSUE-035から選ぶ。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | Discord DM整理MVPをproduction qualityへ近づける |
| Strategy | P0セキュリティ系とP1価値向上系を分離し、並行可能なIssue単位にする |
| Tactics | AI provider、編集UI、Review Center、PII redactionを独立Issue化 |
| Assessment | 分割粒度は妥当。ただしworkspace-client肥大化と認証未実装の制約に注意 |
| Conclusion | #35〜#38は並行着手可能。ただし#29/#30/#32のP0 blockerは優先監視する |
| Knowledge | DM整理はAI品質と安全性が同時に必要で、単一Issueに詰めるとレビューが甘くなる |

## 判定

条件付き合格。

ISSUE-035〜ISSUE-038を作成してよい。ただし、production release判定では#29/#30/#32のセキュリティ系P0を優先し、#35以降は通常CIで外部AIや本番credentialを使わないことを条件に進める。
