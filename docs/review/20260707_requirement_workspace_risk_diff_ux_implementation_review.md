# ISSUE-053 Requirement Workspace未決事項・リスク・差分強調UX 実装レビュー

## 評価日時

2026-07-07 11:35 JST

## 評価担当

Codex（Product Manager / Frontend Architect / UI/UX Designer / QA / Security Engineer）

外部AIレビュー: Claude、ChatGPTレビューは未実施。現時点ではCodex一次レビューとして保存し、外部AIレビュー結果が追加された場合は差分分析を追記する。

## 使用フレームワーク

- G-STACK
- HEART
- WCAG
- ISO25010
- MoSCoW

## 対象

- Issue番号: ISSUE-053 / GitHub #70
- 対象ファイル:
  - `frontend/app/workspace-client.tsx`
  - `frontend/app/globals.css`
  - `frontend/e2e/meeting-workspace.spec.ts`
  - `docs/review/20260707_requirement_workspace_risk_diff_ux_design_review.md`

## 良かった点

- Requirement Workspace上部に「要件判断サマリー」を追加し、未決事項、リスク、レビュー、最新差分、下流Draft状態を一目で確認できるようにした。
- 「要件注目ポイント」を追加し、未決事項とリスクの先頭項目、最新差分の安全プレビューを編集欄までスクロールせずに確認できるようにした。
- 既存のRequirement、Review、履歴APIだけを使い、API変更なしでUX改善を完結させた。
- 色だけに頼らず、件数、状態文言、見出し、アイコンを併用した。
- Playwrightで主要フローと390px幅の横あふれ確認を追加した。

## 改善点

- 最新差分は直近履歴からの短縮表示であり、全履歴のフィルタ、ページング、文字単位diffは未実装。
- 未決事項とリスクは先頭3件のみ表示するため、大量項目がある場合は編集欄または履歴タイムラインで確認する必要がある。
- リスク重要度やowner、期限の構造化はまだなく、今後OpenAI provider導入後の品質評価と合わせて拡張余地がある。
- 外部AIレビュー比較は未実施で、L3レビューとしては未完了。

## 優先順位

| 優先度 | 指摘 | 改善案 |
| --- | --- | --- |
| P0 | 承認可否をFrontendだけで決めない | 既存のBackend gateを正とし、今回のUIは補助表示に限定した |
| P1 | 未決事項、リスク、レビュー、差分が散らばっていた | 要件判断サマリーと注目ポイントで統合した |
| P1 | モバイル幅で判断材料が横あふれするリスク | 390px幅で `#requirements`、判断サマリー、注目ポイントの横あふれを確認した |
| P2 | 全履歴の探索性はまだ弱い | 履歴フィルタ、折りたたみ、ページングを将来Issue化する |

## 次アクション

1. PRを作成し、CI結果を確認する。
2. GitHub Issue #70へ実装内容と検証結果をコメントする。
3. PR CI成功後にGitHub Issue #70をクローズする。
4. Issue #3は残るISSUE-052の完了後に親Issueクローズ可否を判断する。

## Issue番号

- ISSUE-053
- GitHub Issue: #70
- 親Issue: #3

## 検証結果

- `npm run display:check`: 成功。Display labels OK: 86 messages, 53 statuses, 5 targets
- `npm run frontend:build`: 成功
- `NEXT_PUBLIC_API_BASE_URL=http://localhost:3001/api/v1 npm run frontend:e2e -- --grep "creates a project, saves a Discord log, generates minutes, and requests review"`: 1 passed
- `git diff --check`: 成功
- PR #75のmain反映後CI: 成功。`https://github.com/Kazuya-Sakashita/ai-pm-platform/actions/runs/28829769543`

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | レビュー担当者がRequirementの判断材料を短時間で把握できるようにする |
| Strategy | 既存データを再構成し、画面上部に判断サマリーと注目リストを追加する |
| Tactics | 未決事項、リスク、レビュー、最新差分、下流Draft状態のカード化、注目ポイントリスト、モバイルE2E |
| Assessment | ISSUE-053の完了条件は満たした。高度なdiff探索や構造化リスク管理は今後の改善対象 |
| Conclusion | PR化してよい。PR CI成功後にGitHub #70をクローズ可能 |
| Knowledge | AI PMでは、要件全文を読む前に「どこが危険か」を短く示すことでレビュー速度と判断品質が上がる |

## 判定

合格。世界レベルSaaS基準では履歴フィルタや構造化リスク管理の余地は残るが、ISSUE-053のMVP完了条件である未決事項、リスク、差分、承認前注意点の視認性改善は満たしている。
