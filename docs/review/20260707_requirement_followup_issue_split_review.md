# Requirement残課題Issue分割レビュー

## 評価日時

2026-07-07 07:05 JST

## 評価担当

Codexレビュー統括 / Product Manager / CTO / Tech Lead / AI Architect / Frontend Architect / Backend Architect / Security Engineer / QA / UI/UX Designer

外部AIレビュー: Claude、ChatGPTレビューは未実施。現時点ではCodex一次レビューとして保存し、外部AIレビュー結果が追加された場合は差分分析を追記する。

## 使用フレームワーク

- G-STACK
- RICE
- MoSCoW
- ISO25010
- STRIDE
- WCAG

## 対象

Issue #3に残っているRequirement関連残課題を、並行実施しやすいGitHub Issueと `docs/issue/` 台帳へ分割する。

## 良かった点

- 下流Draft stale化まで完了したことで、次の残課題を安全に分離できる状態になった。
- OpenAI provider、差分履歴、UX改善、stale後再生成は依存関係が薄く、別Issueとして並行しやすい。
- 差分履歴と再生成UXを分けることで、監査設計とユーザー導線の責務が混ざりにくい。
- UX改善をP2として分離することで、P1のprovider比較や履歴基盤を妨げずに進められる。

## 改善点

- Issue #3が大きくなりすぎており、完了判定が読みにくい。
- OpenAI providerは外部API、secret、費用、失敗契約を伴うため、通常UI改善と同時に実装するとレビュー負荷が上がる。
- 差分履歴はPII/secret保存リスクがあるため、画面実装より先に保存方針レビューが必要である。
- stale後再生成UXはIssue #4とも接続するため、Issue #3だけの文脈で閉じると設計漏れが起きやすい。

## 優先順位

| 優先度 | Issue | 理由 |
| --- | --- | --- |
| P1 | ISSUE-050 Requirement差分履歴とレビュー履歴タイムライン | 監査性と再承認判断の根拠に直結する |
| P1 | ISSUE-051 stale後の下流Draft再生成UX | stale化後に業務を前へ進める導線が必要 |
| P1 | ISSUE-052 Requirement生成OpenAI provider比較 | AI PM価値の上限を上げるが、安全な比較評価が前提 |
| P2 | ISSUE-053 Requirement Workspace未決事項・リスク・差分強調UX | レビュー効率改善として独立して進められる |

## 次アクション

1. ISSUE-050から差分保存方式とPII/secret除外方針を設計する。
2. ISSUE-051でstale後の再生成と再承認のAPI駆動フローを設計する。
3. ISSUE-052は既存provider実装を読んでOpenAI provider設計レビューから始める。
4. ISSUE-053は低リスクな表示改善として、P1作業と衝突しない範囲で進める。

## Issue番号

- GitHub Issue: #67
- GitHub Issue: #68
- GitHub Issue: #69
- GitHub Issue: #70

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | Issue #3の残課題を、並行実行可能でレビューしやすい単位へ分割する |
| Strategy | 監査基盤、再生成UX、AI provider、画面UXを責務別に分離する |
| Tactics | GitHub Issue #67-#70作成、docs/issue台帳追加、優先度明示 |
| Assessment | 分割は妥当。Issue #3は親Issueとして残し、各Issue完了後に閉鎖判断する |
| Conclusion | 4件を並行Issueとして運用してよい |
| Knowledge | 世界レベルSaaS基準では、大きなAI機能ほど履歴、再生成、安全なprovider比較を別々に評価する方が品質が上がる |

## 判定

Issue分割は妥当。ISSUE-050、ISSUE-051、ISSUE-052はP1として優先し、ISSUE-053はP2の独立UX改善として並行可能とする。
