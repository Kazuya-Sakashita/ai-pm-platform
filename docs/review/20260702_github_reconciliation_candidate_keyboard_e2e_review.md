# GitHub Reconciliation Candidate Keyboard E2E Review

## 評価日時

2026-07-02 07:36:24 JST

## 評価担当

- Codex
- Frontend Architect
- QA
- UI/UX Designer
- Product Manager

外部AIレビュー: Claude/ChatGPT等の外部レビューは未実施。現時点ではCodex一次レビューとして保存し、外部レビュー待ちとする。

## 使用フレームワーク

- G-STACK
- WCAG
- HEART
- ISO25010

## 対象

- Issue番号: #4
- 対象ファイル:
  - `frontend/e2e/meeting-workspace.spec.ts`
  - `docs/issue/ISSUE-004_github_issue_and_openapi_pipeline.md`

## 良かった点

- 候補Issue選択をマウスクリックではなく、フォーカス移動とEnterで検証するようにした。
- `Shift+Tab` で候補ボタンへ戻り、`toBeFocused` で実際のフォーカス到達を確認した。
- 選択後の `aria-current`、`aria-pressed`、選択中chip、入力反映、既存Issue紐付けまで同じE2Eで維持した。
- Candidate selection UIのアクセシビリティ属性が、実際のキーボード操作導線でも機能することを確認した。

## 改善点

- 会議ワークスペース起動から候補選択、紐付け完了までを完全にTab/Enterだけで進めるE2Eではない。
- スクリーンリーダーでの読み上げ順や状態変化通知は未検証。
- フォーカスリングの視覚品質はscreenshotで確認していない。
- long title/URLの狭幅viewport視覚回帰は未実施。
- live GitHub App credentialでのcandidate selection smokeは未実施。

## 優先順位

- P0: live GitHub App credentialでcandidate selectionをsmoke testする。
- P1: long title/URLの狭幅viewport視覚回帰E2Eを追加する。
- P1: フォーカスリングを含むcandidate selection screenshot確認を追加する。
- P2: スクリーンリーダー読み上げの手動QA観点をdocsへ追加する。

## 次アクション

- long title/URLの視覚回帰E2Eを追加する。
- フォーカスリングを含むcandidate selectionの狭幅表示を確認する。
- live GitHub App credentialが設定できる環境でsmoke testを実施する。

## Issue番号

- #4

## レビュー結果

E2E改善として合格。候補選択UIは、マウス前提から一段進み、フォーカス移動とEnterで選択できることを検証できた。ただし世界レベルのSaaS基準では、完全キーボードのみの一連操作、スクリーンリーダー確認、フォーカスリングの視覚品質、live smokeが残るためIssue #4はまだクローズ不可。

## 検証結果

- `npm run frontend:e2e`: 11 passed
- `git diff --check`: success
