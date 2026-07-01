# GitHub Reconciliation Link Issue E2E Review

## 評価日時

2026-07-01 20:17:28 JST

## 評価担当

- Codex
- Tech Lead
- Frontend Architect
- QA
- Security Engineer

## 使用フレームワーク

- G-STACK
- ISO25010
- STRIDE
- HEART

## 対象

- Issue番号: #4
- 対象ファイル:
  - `frontend/e2e/meeting-workspace.spec.ts`

## 良かった点

- pending reconciliation attempt付きIssue Draftのmock workflowを汎用化し、controlled retryと手動リンクの両方を検証できるようにした。
- `既存Issueに紐付け` 実行時に `resolution_action: link_existing_issue`、resolution note、GitHub Issue番号、GitHub Issue URLが送信されることをE2Eで検証した。
- 手動リンク後にIssue Draftがpublished状態へ遷移し、GitHub Issue URLが表示されることを確認した。
- 手動リンク後に公開ブロックと復旧操作が消えることを確認し、二重操作リスクを下げた。
- 既存のcontrolled retry E2Eと同じmock基盤を使うことで、GitHub credentialなしでも希少状態を安定して検証できる。

## 改善点

- 実GitHub App credentialを使ったconnect、publish、reconcile、manual link smokeは未実施。
- marker検索結果の0件/複数件候補一覧から選ぶUIはまだない。
- Link IssueのGitHub URL validationはBackend specで検証済みだが、Frontend上の入力エラー表示E2Eは未追加。
- controlled retryのcooldown、retry count、承認者表示、理由テンプレートは未実装。
- mock E2EはUI contract検証であり、GitHub search index delayやrate limitの実挙動は検証できない。

## 優先順位

- P0: 実GitHub App credentialでlive smokeを実施する。
- P1: marker検索候補一覧と手動選択UIを追加する。
- P1: Link Issueの入力エラー表示E2Eを追加する。
- P1: controlled retryにcooldown、retry count、承認者表示を追加する。
- P2: GitHub search retry/backoff方針をADR化する。

## 次アクション

- GitHub App credentialが設定できる環境でlive smokeを行う。
- marker検索候補一覧のAPI/Frontend設計を進める。
- Link Issue入力エラーと候補選択のE2Eを追加する。
- retry/backoff/cooldown方針をADR化する。

## Issue番号

- #4

## レビュー結果

テスト工程として合格。手動リンクのpayloadと成功後UI遷移をE2Eで確認できたため、Frontend reconciliation導線の主要な手動解決操作は一通り回帰検証できる状態になった。ただし世界レベルのSaaS基準では、実GitHub App credential smoke、候補Issue選択、retry制御、rate limit/backoff設計が残るためIssue #4はまだクローズ不可。

## 検証結果

- `npm run frontend:e2e`: 8 passed
- `npm run frontend:build`: success
