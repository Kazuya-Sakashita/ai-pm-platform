# GitHub Reconciliation Candidate A11y Review

## 評価日時

2026-07-02 07:12:01 JST

## 評価担当

- Codex
- Product Manager
- Tech Lead
- Frontend Architect
- QA
- Security Engineer
- UI/UX Designer

外部AIレビュー: Claude/ChatGPT等の外部レビューは未実施。現時点ではCodex一次レビューとして保存し、外部レビュー待ちとする。

## 使用フレームワーク

- G-STACK
- HEART
- WCAG
- ISO25010

## 対象

- Issue番号: #4
- 対象ファイル:
  - `frontend/app/workspace-client.tsx`
  - `frontend/app/globals.css`
  - `frontend/e2e/meeting-workspace.spec.ts`
  - `docs/issue/ISSUE-004_github_issue_and_openapi_pipeline.md`

## 良かった点

- 候補Issue選択後に、該当候補行が視覚的に選択中と分かるようになった。
- 選択ボタンに `aria-pressed` を追加し、支援技術でも選択状態を判別しやすくした。
- 候補行に `aria-current` を追加し、現在選択中の候補をDOM上でも表現した。
- 選択中chipとprimary buttonを使い、誤って別候補を選ぶリスクを下げた。
- 長いtitleでも候補行が崩れにくいように `overflow-wrap` を追加した。
- Playwright E2Eで選択前後の `aria-pressed`、`aria-current`、選択中chipを確認した。

## 改善点

- キーボード操作のみで候補選択から紐付けまで完了できるかのE2Eは未追加。
- スクリーンリーダーでの読み上げ順や冗長さは未検証。
- long title/URLの狭幅viewport screenshot検証は未実施。
- 候補が10件近い場合の視覚密度と選択ミス耐性は未検証。
- live GitHub App credentialでの候補選択UI smokeは未実施。

## 優先順位

- P0: live GitHub App credentialでcandidate selectionをsmoke testする。
- P1: キーボード操作のみのcandidate selection E2Eを追加する。
- P1: long title/URLの狭幅viewport screenshotまたはlayout assertionを追加する。
- P1: 候補10件時の表示密度と選択ミス耐性を確認する。
- P2: スクリーンリーダー向けのラベル文言を必要に応じて調整する。

## 次アクション

- long title/URLの視覚回帰E2Eを追加する。
- キーボード操作のみで候補選択と既存Issue紐付けを行うE2Eを追加する。
- GitHub Searchの `total_count` / `incomplete_results` / 10件超過表示のAPI拡張要否を検討する。
- live GitHub App credentialが設定できる環境でsmoke testを実施する。

## Issue番号

- #4

## レビュー結果

UI/a11y改善として合格。候補選択後の状態が視覚、DOM、E2Eで確認できるようになり、複数候補時の誤選択リスクを下げた。ただし世界レベルのSaaS基準では、キーボード操作、スクリーンリーダー確認、狭幅viewportでの長文表示、live smokeが不足しているためIssue #4はまだクローズ不可。

## 検証結果

- `npm run frontend:build`: success
- `npm run frontend:e2e`: 11 passed
- `git diff --check`: success
