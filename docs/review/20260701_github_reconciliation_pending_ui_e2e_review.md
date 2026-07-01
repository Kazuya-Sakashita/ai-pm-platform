# GitHub Reconciliation Pending UI E2E Review

## 評価日時

2026-07-01 20:03:41 JST

## 評価担当

- Codex
- Tech Lead
- Frontend Architect
- QA
- Security Engineer

## 使用フレームワーク

- G-STACK
- HEART
- WCAG
- ISO25010
- STRIDE

## 対象

- Issue番号: #4
- 対象ファイル:
  - `frontend/e2e/meeting-workspace.spec.ts`

## 良かった点

- pending reconciliation attemptを持つIssue Draftをmockし、UIがmarker検索、手動リンク、controlled retryを表示することをE2Eで検証した。
- `github_reconciliation.github_issue_number` と `github_reconciliation.github_issue_url` がフォームへ事前入力されることを検証した。
- `Approve Retry` 実行時のrequest payloadに `resolution_action: approve_retry` とresolution noteが含まれることを検証した。
- approve retry後にIssue Draftが `approved` へ戻り、復旧操作が画面から消えることを検証した。
- 既存の実API E2Eとは分け、pending=trueの希少状態を安定して再現できるmock E2Eにした。

## 改善点

- marker検索の成功/0件/複数件パターンはまだmock E2Eで検証していない。
- `Link Issue` のpayload検証は未追加。
- GitHub App credentialを使ったlive connect/publish/reconcile/manual resolve smokeは未実施。
- 候補Issue一覧から選択するUIがまだないため、複数match時の実運用UXは弱い。
- retry cooldown、retry count、承認者表示、理由テンプレートは未実装。
- pending=true UIのスクリーンリーダー向け補助文とフォーカス管理は最低限。

## 優先順位

- P0: 実GitHub App credentialでlive smokeを実施する。
- P1: `Link Issue` のmock E2Eを追加する。
- P1: marker検索結果候補一覧と選択UIを実装する。
- P1: controlled retryにcooldown、retry count、承認者表示を追加する。
- P2: エラー要約、フォーカス移動、補助テキストを改善する。

## 次アクション

- GitHub App credentialが設定できる環境でlive smokeを行う。
- 候補Issue一覧のAPI/Frontend設計を進める。
- `Link Issue` のpayload検証E2Eを追加する。
- retry/backoff/cooldown方針をADR化する。

## Issue番号

- #4

## レビュー結果

テスト工程として合格。pending=trueの復旧UIとcontrolled retry送信がE2Eで確認できるようになり、前回レビューで残したテストギャップを一つ埋めた。ただし世界レベルのSaaS基準では、live smoke、候補Issue選択、retry制御、権限分離が残るためIssue #4はまだクローズ不可。

## 検証結果

- `npm run frontend:e2e`: 7 passed
- `npm run frontend:build`: success
