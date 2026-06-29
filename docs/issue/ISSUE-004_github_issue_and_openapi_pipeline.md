# ISSUE-004: 要件からGitHub IssueとOpenAPIドラフトを生成する

## GitHub Issue

登録待ち。

理由: `gh auth status` で GitHub token invalid。初期時点でremote未設定。

登録試行: ISSUE-001登録時に `no git remotes found` が確認されたため、remote設定と再認証後に登録する。

## 背景

AI実装エージェントの成功率は、IssueとAPI仕様の品質に大きく依存する。議事録からIssueだけでなくOpenAPIまで落とし込むことで、実装前の曖昧さを減らす。

## 目的

承認済み要件から、GitHub IssueドラフトとOpenAPIドラフトを生成し、レビュー後にGitHubへ登録する。

## 完了条件

- Issueタイトル、本文、完了条件、ラベル案を生成できる
- OpenAPI path、method、request、response、errorを生成できる
- APIレビューを保存できる
- GitHub Issue作成後にIssue番号とローカル台帳が紐づく
- レビュー未通過なら実装へ進めない

## スコープ

- GitHub Issueドラフト
- GitHub Issue作成
- OpenAPIドラフト
- APIレビュー

## 非スコープ

- Pull Request自動作成
- 自動マージ
- Jira/Linear同期

## 関連レビュー

- `docs/review/20260629_winning_strategy_review.md`
- `docs/review/20260629_mvp_review.md`
- `docs/review/20260629_requirements_review.md`
- `docs/review/20260630_api_design_review.md`
- `docs/review/20260630_db_design_review.md`

## レビュー結果

差別化に直結するP0。GitHub権限、OpenAPI品質、再生成時の差分管理を慎重に設計する必要がある。

## 次アクション

- GitHub App/OAuthの権限設計を作る
- OpenAPI初稿は `docs/api/openapi.yaml` に作成済み
- Issue同期の冪等性方針をADR化する
- ISSUE-008としてJobs API、GitHub連携API、OpenAPI validation APIを追加する
