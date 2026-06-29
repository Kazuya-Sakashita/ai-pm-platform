# ISSUE-020: GitHub repositoryとIssue台帳を同期する

## GitHub Issue

登録待ち。

理由: GitHub CLI token invalid。

## 背景

ローカルではAGENTS、docs、OpenAPI、静的プロトタイプ、review、issue台帳が整備されたが、GitHub remoteが未設定で、GitHub CLIのtokenもinvalidである。そのため、リポジトリpushとGitHub Issue登録が止まっている。

## 目的

GitHub repositoryへの初回pushと、`docs/issue/ISSUE-*.md` のGitHub Issue登録を再現可能な手順で実施できる状態にする。

## 完了条件

- GitHub同期ブロッカーが明文化されている
- GitHub Issue同期スクリプトがある
- dry-runで同期対象Issueを確認できる
- 認証復旧後の実行手順が文書化されている
- ローカル初回commitが作成されている
- GitHub remote設定後にpushできる
- GitHub Issue登録後、各IssueファイルへGitHub URLが追記される
- レビューが `docs/review/` に保存されている

## スコープ

- GitHub remote/push準備
- GitHub Issue一括登録準備
- ローカルcommit作成
- 同期状況ドキュメント更新

## 非スコープ

- GitHub App本実装
- Product内のGitHub publish API実装
- CI/CD構築
- GitHub repositoryの権限管理設計

## 関連レビュー

- `docs/review/20260630_github_sync_readiness_review.md`
- `docs/review/20260630_github_remote_push_verification_review.md`

## レビュー結果

同期準備は必須。世界レベルのSaaS開発では、ローカル台帳だけで進めると監査性と共同開発性が落ちる。GitHub Issueを正式な実行台帳にし、ローカルdocsは監査ログとして残す二重管理にする。

## 次アクション

- `gh auth login -h github.com` でGitHub CLIを再認証する
- `npm run github:issues:dry-run` で登録対象を確認する
- `npm run github:issues:sync` でGitHub Issueへ登録する

## 進捗

進行中。GitHub repository remote設定と初回pushは完了。

2026-06-30 07:11 JST確認:

- `origin`: `git@github.com:Kazuya-Sakashita/ai-pm-platform.git`
- `git push -u origin main`: `Everything up-to-date`
- `main` は `origin/main` をtrack
- `gh auth status`: token invalid

残ブロッカーはGitHub CLI再認証のみ。
