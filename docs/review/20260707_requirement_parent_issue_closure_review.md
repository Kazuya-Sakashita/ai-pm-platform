# 2026-07-07 Requirement親Issueクローズ判定レビュー

## 評価日時

2026-07-07 12:28:03 JST

## 評価担当

Codex（Product Manager / Product Owner / Tech Lead / AI Architect / Backend Architect / Frontend Architect / QA / Security Engineer）

## 使用フレームワーク

- G-STACK
- MoSCoW
- ISO25010
- HEART
- STRIDE

## 対象Issue

- ISSUE-003
- GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/3
- 関連残課題: ISSUE-052 / GitHub Issue #69

## 評価対象

- `docs/issue/ISSUE-003_minutes_to_requirements_pipeline.md`
- Requirement生成、編集、承認、レビュー、履歴、下流Draft接続に関する既存レビュー
- GitHub Issue #3の進捗コメント

## 評価概要

ISSUE-003の元の完了条件は、議事録から要件定義ドラフトを生成し、未決事項を抽出し、専門家レビューを保存し、人間が編集でき、Issue生成に使える構造へ接続することである。

2026-07-07時点で、deterministic provider、品質評価fixture、Requirement承認ゲート、Review Center連携、承認監査メタデータ、再編集時の承認差し戻し、下流Draft stale化、再生成UX、履歴タイムライン、Review状態遷移監査、判断サマリーUXまで実装、レビュー、CI検証が完了している。

残るISSUE-052 / GitHub #69は、Requirement生成OpenAI providerを実APIで比較評価するP1改善であり、ISSUE-003の親Issue完了条件とは切り分けられる。したがって、ISSUE-003は親Issueとしてクローズ可能と判定する。

## G-STACK

- Goal: 議事録から要件定義ドラフトを生成し、レビューと下流Issue/OpenAPI生成へ進めるMVP導線を完成させる。
- Strategy: deterministic providerを安定基盤とし、AI品質改善は独立Issueへ分離する。
- Tactics: Requirement生成、編集、承認、レビュー、履歴、stale再生成、判断サマリーを段階的に実装し、各段階でレビューとCIを保存した。
- Assessment: 親Issueの完了条件は満たしている。OpenAI live比較は価値が高いが、API key依存のため親Issueの完了をブロックしない。
- Conclusion: ISSUE-003はクローズ可能。ISSUE-052 / #69はopen維持。
- Knowledge: 親Issueを長く開き続けるより、価値提供済みのMVP範囲を閉じ、AI provider改善を独立して追跡する方がロードマップ管理しやすい。

## MoSCoW

| 区分 | 項目 | 判定 |
| --- | --- | --- |
| Must | 要件定義ドラフト生成 | 完了 |
| Must | 未決事項抽出 | 完了 |
| Must | 人間編集 | 完了 |
| Must | 専門家レビュー保存 | 完了 |
| Must | 承認済みRequirementからIssue/OpenAPI Draftへ進める構造 | 完了 |
| Should | 承認メタデータ、履歴、差分、stale再生成UX | 完了 |
| Should | Review状態遷移監査 | 完了 |
| Could | OpenAI provider live比較 | ISSUE-052 / #69で継続 |
| Won't now | 本番常時OpenAI利用、外部AI自動比較基盤 | 非スコープ |

## 良かった点

- Requirement生成だけで終わらず、レビュー、承認、監査、履歴、下流Draft整合性まで接続できている。
- 評価fixtureとdeterministic providerのbaselineがあり、CIに依存しない品質基準を持てている。
- 再編集時に承認状態を戻し、下流Draftをstale化することで、古い承認を使った誤公開リスクを下げている。
- Review状態遷移イベントとRequirement履歴により、監査性が強化されている。
- OpenAI provider比較を独立Issueへ分離しており、API key依存で親Issueが止まり続ける構造を避けられる。

## 改善点

- GitHub Issue #3本文が長く、最新状態を読み取りにくくなっている。
- OpenAI providerのlive評価は未実施で、AI PMとしての生成品質上限はまだ検証途中である。
- Requirement生成の評価fixtureは強いが、実ユーザーの長文会議ログや曖昧なDM相談のデータセットはまだ不足している。
- 親Issueと子Issueの完了条件分離が後半まで曖昧で、クローズ判断が遅れた。
- 外部AIレビュー比較は未実施で、Codex一次レビューに依存している。

## 改善案

- GitHub Issue #3はクローズコメントで「完了範囲」と「継続Issue #69」を明確に分ける。
- #69では実OpenAI API keyを使える環境でmanual smokeを実施し、deterministic providerとの比較結果を `docs/evaluation/` と `docs/review/` へ保存する。
- 実ユーザーに近い長文・曖昧相談fixtureを追加し、Requirement生成評価の現実適合性を高める。
- 今後の親Issueでは、P0完了条件とP1/P2改善を最初から別Issueへ分ける。
- 外部AIレビューが利用可能になった時点で、Requirement生成品質レビューをClaude/ChatGPT等と比較する。

## 優先順位

- P0: Issue #3のクローズ判定をGitHubへ同期し、親Issueを閉じる。
- P1: ISSUE-052 / #69のlive OpenAI fixture評価を実施する。
- P1: 実ユーザーに近いRequirement評価fixtureを追加する。
- P2: 親Issue/子Issueの完了条件分離ルールをIssueテンプレートへ反映する。
- P2: 外部AIレビュー比較を追加する。

## 次アクション

1. 本レビューを含むPRを作成し、CIを確認する。
2. CI成功後、GitHub Issue #3へ完了範囲と継続Issue #69をコメントする。
3. GitHub Issue #3をクローズする。
4. ISSUE-052 / #69はopen維持し、API keyが利用可能になった時点でmanual smokeを実施する。

## Issue番号

- ISSUE-003
- GitHub Issue #3
- 継続Issue: ISSUE-052 / GitHub Issue #69

## 判定

合格。ISSUE-003の元の完了条件は満たしているため、親Issueとしてクローズ可能。OpenAI provider live比較はISSUE-052 / #69で継続し、ISSUE-003のクローズブロッカーにはしない。
