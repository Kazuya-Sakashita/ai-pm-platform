# ISSUE-053: Requirement Workspaceの未決事項・リスク・差分強調UXを改善する

## Issue番号

ISSUE-053

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/70

登録日: 2026-07-07
状態: 実装完了、PR CI確認待ち

## 背景

Requirement Workspaceは生成、編集、承認ブロッカー表示まで進んだが、要件量が増えた場合に未決事項、リスク、変更差分を素早く把握するUXがまだ弱い。

## 目的

Requirement Workspaceで未決事項、リスク、差分、承認前の注意点を視覚的にスキャンしやすくし、レビュー担当者が迷わず判断できるようにする。

## 完了条件

- 未決事項とリスクがRequirement Workspace上で明確に強調される
- 長文Requirementでも主要判断材料をスキャンできる
- 差分履歴Issueと矛盾しない表示設計になっている
- WCAG観点で色だけに依存しない
- Playwrightで主要表示とモバイル幅を確認する
- 設計レビュー、実装レビューを保存する

## スコープ

- Requirement Workspaceの情報設計
- 未決事項とリスクの強調表示
- 既存承認ブロッカーパネルとの統合
- モバイル幅での可読性

## 非スコープ

- Requirement差分履歴の永続化
- OpenAI provider導入
- 下流Draft再生成API

## 関連レビュー

- `docs/review/20260630_requirements_generation_mvp_review.md`
- `docs/review/20260630_requirement_approval_gate_review.md`
- `docs/review/20260707_requirement_blocker_details_implementation_review.md`
- `docs/review/20260707_requirement_followup_issue_split_review.md`
- `docs/review/20260707_requirement_workspace_risk_diff_ux_design_review.md`
- `docs/review/20260707_requirement_workspace_risk_diff_ux_implementation_review.md`

## レビュー結果

UX改善としてはP2だが、世界レベルSaaSではレビュー担当者が未決事項とリスクを即座に把握できることが重要である。差分履歴とOpenAI provider導入から独立して進められる。

2026-07-07 11:35 JST追加:

- Requirement Workspaceに `要件判断サマリー` を追加し、未決事項、リスク、レビュー、最新差分、下流Draft状態をカードで確認できるようにした
- `要件注目ポイント` を追加し、未決事項、リスク、最新差分の先頭項目を編集欄までスクロールせず確認できるようにした
- 色だけに依存せず、件数、状態文言、見出し、アイコンで状態を識別できるようにした
- 390px幅のPlaywright検証で `#requirements`、判断サマリー、注目ポイントの横あふれがないことを確認した
- `npm run display:check`: 成功
- `npm run frontend:build`: 成功
- `NEXT_PUBLIC_API_BASE_URL=http://localhost:3001/api/v1 npm run frontend:e2e -- --grep "creates a project, saves a Discord log, generates minutes, and requests review"`: 1 passed
- 判定: ISSUE-053のMVP要件は完了。PR CI成功後にGitHub #70をクローズ可能

## 優先度

P2

## 次アクション

1. PRを作成し、CI結果を確認する。
2. GitHub Issue #70へ実装内容と検証結果をコメントする。
3. PR CI成功後にGitHub Issue #70をクローズする。
4. 残るISSUE-052の完了後に親Issue #3のクローズ可否を判断する。
