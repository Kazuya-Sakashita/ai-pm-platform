# GitHub Reconciliation Link Issue Number Mismatch E2E Review

## 評価日時

2026-07-04 05:48 JST

## 評価担当

Codex / Tech Lead / Security Engineer / QA / Frontend Architect

外部AIレビュー: 未実施。Claude、ChatGPT等の外部レビューは環境から直接実行できないため、Codex一次レビューとして保存する。

## 使用フレームワーク

- G-STACK
- STRIDE
- ISO25010
- WCAG

## 良かった点

- GitHub Issue番号 `42` とURL `/issues/43` の不一致をFrontend E2Eで固定し、ユーザー操作の送信前ガードを明文化した。
- Backend request specでも同じ不一致を422で拒否することを確認し、Frontendだけに依存しない防御にした。
- アプリ本体の責務やUIを増やさず、既存のURL検証ロジックとAPI検証の回帰テストを追加する小さな変更に留めた。
- Link Issueの誤紐付けによる監査不整合、誤ったGitHub Issueへの紐付け、二重作成判断ミスを減らせる。

## 改善点

- URL/番号不一致のFrontendエラーは日本語文言で固定できたが、Backendのsafe detailは汎用の `github_reconciliation_issue_url_invalid` のままで詳細分類はない。
- E2Eはmock workflowであり、実GitHub App credentialを使ったlive reconciliationでは未確認。
- URL validation helperはFrontend内関数として閉じており、将来的な他画面再利用や単体テストは未整備。
- Playwrightではalert表示を確認したが、スクリーンリーダー読み上げ順は未確認。

## 改善案

- Backend error detailsに `issue_number_mismatch` などの安全なreasonを追加し、Frontend表示をより精密にする。
- GitHub App live smokeで、手動リンク候補のURL/番号確認も検証項目へ含める。
- URL validation helperを共有可能な小さな関数へ分離し、境界値の単体テストを追加する。
- error alertが支援技術へ適切に通知されるかVoiceOver等で確認する。

## 優先順位

- P0: 実GitHub App credentialでのconnect/publish/reconcile smokeを行う。
- P1: Backend error reasonの細分化を検討する。
- P1: URL validation helperの単体テスト化を検討する。
- P2: スクリーンリーダー確認を実施する。

## 次アクション

- ISSUE-004へ本レビューと検証結果を追記する。
- GitHub Issue #4へ進捗を同期する。
- 次の実装候補は、live GitHub App smoke、またはreconciliation履歴/failed job運用UI。

## Issue番号

- ISSUE-004
- GitHub Issue: #4

## 結論

URL/番号不一致はLink Issueの小さな入力ミスに見えるが、AI PMの監査台帳では誤った外部Issueとの紐付けにつながる重大なリスクである。今回の追加でFrontendとBackendの両方に回帰テストが入り、MVPの安全性は一段上がった。ただしlive GitHub連携と運用UIは未完了のため、ISSUE-004は継続する。

## 検証

- `bundle exec rspec spec/requests/api/v1/issue_drafts_spec.rb`: 24 examples, 0 failures
- `FRONTEND_URL=http://localhost:3002 NEXT_PUBLIC_API_BASE_URL=http://localhost:3003/api/v1 npm run frontend:e2e`: 14 passed
