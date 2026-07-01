# GitHub Reconciliation Link Issue Validation E2E Review

## 評価日時

2026-07-01 20:22:46 JST

## 評価担当

- Codex
- Tech Lead
- Frontend Architect
- QA
- Security Engineer

## 使用フレームワーク

- G-STACK
- ISO25010
- HEART
- STRIDE

## 対象

- Issue番号: #4
- 対象ファイル:
  - `frontend/e2e/meeting-workspace.spec.ts`

## 良かった点

- `既存Issueに紐付け` の送信前validationをPlaywright E2Eで確認した。
- GitHub Issue番号が1以上の整数でない場合に、日本語エラーを表示してAPI送信へ進まないことを確認した。
- GitHub Issue URL未入力時に、日本語エラーを表示して公開ブロック状態を維持することを確認した。
- 成功ケースと同じpending reconciliation mockを使い、手動リンク導線の正常系と入力エラー系を近い条件で検証できるようにした。
- live GitHub credentialなしで、重複Issue防止に関わる入力防御を高速に回帰確認できる。

## 改善点

- API 422を返すBackend validation失敗時の画面表示E2Eは未追加。
- GitHub Issue URLが別repositoryを指す場合のE2Eは未追加。
- 入力欄のinline errorやaria-describedbyは未実装で、現状はグローバルalert依存。
- marker検索結果から候補Issueを選ぶUIがないため、ユーザーが番号とURLを手入力する必要がある。
- 実GitHub App credentialを使ったmanual link smokeは未実施。

## 優先順位

- P0: 実GitHub App credentialでconnect、publish、reconcile、manual link smokeを実施する。
- P1: API 422時のLink Issueエラー表示E2Eを追加する。
- P1: 別repository URL拒否のE2Eを追加する。
- P1: marker検索候補一覧からIssueを選択できるUIを追加する。
- P2: 入力欄単位のエラー表示とアクセシビリティ属性を追加する。

## 次アクション

- Backend validation失敗をmockしたLink Issue API error E2Eを追加する。
- marker検索候補一覧と手動選択UIの設計へ進む。
- Link Issueフォームのinline validationとアクセシビリティ改善を検討する。
- live GitHub App credentialが設定できる環境でsmoke testを実施する。

## Issue番号

- #4

## レビュー結果

テスト工程として合格。手動リンクの正常系に加えて、GitHub Issue番号とURLの基本的な入力エラーを画面上で検出できることを確認できた。ただし世界レベルのSaaS基準では、API validation失敗、別repository URL拒否、候補Issue選択、inline error、live smokeが残るためIssue #4はまだクローズ不可。

## 検証結果

- `npm run frontend:e2e`: 9 passed
- `npm run frontend:build`: success
