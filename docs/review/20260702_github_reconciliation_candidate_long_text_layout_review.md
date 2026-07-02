# GitHub Reconciliation Candidate Long Text Layout Review

## 評価日時

2026-07-02 11:55:49 JST

## 評価担当

- Codex
- Frontend Architect
- QA
- UI/UX Designer
- Product Manager

外部AIレビュー: Claude/ChatGPT等の外部レビューは未実施。現時点ではCodex一次レビューとして保存し、外部レビュー待ちとする。

## 使用フレームワーク

- G-STACK
- HEART
- WCAG
- ISO25010

## 対象

- Issue番号: #4
- 対象ファイル:
  - `frontend/e2e/meeting-workspace.spec.ts`
  - `docs/issue/ISSUE-004_github_issue_and_openapi_pipeline.md`

## 良かった点

- 狭幅viewportで、長いGitHub Issue titleと長いURLを含む候補表示をE2Eで検証した。
- 候補行、候補リスト、Issue Draftパネルがviewportから水平にはみ出さないことを数値で確認した。
- `documentElement.scrollWidth` と各候補要素の `scrollWidth` / `clientWidth` を比較し、水平スクロール発生をCIで検出できるようにした。
- 2件候補の `review_required` 状態を再現し、実際の候補一覧表示に近い条件で確認した。
- 長文title/URLでも候補選択ボタンが表示され続けることを確認した。

## 改善点

- screenshot snapshotによるピクセル単位の視覚回帰は未導入。
- フォーカスリング表示中の狭幅レイアウト確認は未実施。
- 候補が10件ある場合の密度、スクロール量、選択ミス耐性は未検証。
- スクリーンリーダーでの長文読み上げ品質は未検証。
- live GitHub App credentialで実データの長文候補を使ったsmokeは未実施。

## 優先順位

- P0: live GitHub App credentialでcandidate selectionをsmoke testする。
- P1: GitHub Searchの `total_count` / `incomplete_results` / 10件超過表示のAPI拡張要否を判断する。
- P1: 10件候補時の表示密度と操作性を検証する。
- P1: controlled retryのcooldown、retry count、承認者表示、理由テンプレートを追加する。
- P2: screenshot snapshotの導入可否を検討する。

## 次アクション

- GitHub Searchの `total_count` / `incomplete_results` / 10件超過表示のAPI拡張要否を検討する。
- 10件候補時のUI密度と操作性をE2Eまたは視覚確認で検証する。
- live GitHub App credentialが設定できる環境でsmoke testを実施する。

## Issue番号

- #4

## レビュー結果

E2E改善として合格。長いtitleとURLが候補表示を破壊しないことを、狭幅viewportと水平overflow検出で確認できた。ただし世界レベルのSaaS基準では、ピクセル単位の視覚回帰、フォーカスリング表示、10件候補時の操作性、live smokeが残るためIssue #4はまだクローズ不可。

## 検証結果

- `npm run frontend:e2e`: 12 passed
- `npm run frontend:build`: success
- `git diff --check`: success
