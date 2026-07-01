# GitHub Reconciliation Link Issue API Error E2E Review

## 評価日時

2026-07-01 20:36:34 JST

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
- WCAG

## 対象

- Issue番号: #4
- 対象ファイル:
  - `frontend/e2e/meeting-workspace.spec.ts`
  - `frontend/lib/display-labels.ts`

## 良かった点

- `既存Issueに紐付け` がBackend validationで422を返した場合のFrontend表示をE2Eで確認した。
- 別repositoryのGitHub Issue URLを送信した時に、日本語エラーを表示するようにした。
- API失敗時に `github_reconciliation` Jobの失敗状態を表示し、監査対象の失敗として扱えることを確認した。
- API失敗後も公開ブロックと復旧操作が残り、ユーザーが修正して再試行できることを確認した。
- 成功通知やGitHub Issue公開済みパネルへ誤って遷移しないことを確認した。

## 改善点

- API 422の原因がフォーム上のどの項目かをinlineで示すUIは未実装。
- GitHub Issue番号とURL番号の不一致、非GitHub URL、http URLなどの個別E2Eは未追加。
- Backend safe detailの日本語化はFrontend map依存であり、APIレスポンス自体は英語のまま。
- marker検索候補一覧がないため、ユーザーがURLを手入力するリスクが残る。
- 実GitHub App credentialを使ったmanual link smokeは未実施。

## 優先順位

- P0: 実GitHub App credentialでconnect、publish、reconcile、manual link smokeを実施する。
- P1: marker検索候補一覧からIssueを選択できるUIを追加する。
- P1: URL/番号不一致、非GitHub URL、http URLのE2Eを追加する。
- P1: Link Issueフォームのinline errorとaria-describedbyを追加する。
- P2: Backend safe detailの日本語化方針を整理する。

## 次アクション

- marker検索候補一覧と手動選択UIの設計へ進む。
- Link Issueフォームに項目別エラー表示を追加する。
- live GitHub App credentialが設定できる環境でsmoke testを実施する。
- Backend safe detailをAPI側で日本語化するか、Frontend表示変換に寄せるかをADR化する。

## Issue番号

- #4

## レビュー結果

テスト工程として合格。手動リンクの成功、送信前入力エラー、Backend validation失敗までE2Eで確認できたため、重複Issue防止に関わる主要な手動復旧導線の回帰検証は一段強くなった。ただし世界レベルのSaaS基準では、候補Issue選択、inline error、live smoke、GitHub URL種別の網羅が残るためIssue #4はまだクローズ不可。

## 検証結果

- `npm run frontend:e2e`: 10 passed
- `npm run frontend:build`: success
