# ISSUE-010: GitHub連携方式と権限設計を決定する

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/10

登録日: 2026-06-30
同期方法: `scripts/sync-github-issues.rb --apply`

## 背景

ISSUE-008でGitHub connect/disconnect/callback APIを追加したが、GitHub AppとOAuth Appのどちらを採用するかは未決である。Issue公開、repo選択、権限、監査、token保管に大きく影響するため、実装前にADR化する必要がある。

## 目的

GitHub AppとOAuth Appを比較し、MVPで採用する連携方式、必要権限、token保管、監査、disconnect時の挙動を決定する。

## 完了条件

- GitHub App vs OAuth AppのADRがある
- MVPに必要なGitHub権限が定義されている
- Issue publishの権限境界が定義されている
- token/installation情報の保存先が定義されている
- disconnect時の削除/失効/監査方針が定義されている
- セキュリティレビューが `docs/review/` に保存されている

## スコープ

- GitHub連携方式の比較
- 権限設計
- token/installation保存設計
- disconnectと監査

## 非スコープ

- GitHub App作成
- OAuth実装
- UI実装

## 関連レビュー

- `docs/review/20260630_api_db_hardening_review.md`
- `docs/review/20260630_github_integration_security_review.md`

## レビュー結果

API/DB設計強化レビューでは、GitHub連携方式が未決のままだとBackend実装へ進むリスクが高いと評価した。

## 次アクション

- GitHub App vs OAuth App ADRは `docs/decisions/ADR-0003_github_integration_app_over_oauth.md` に作成済み
- 必要権限はMetadata read-onlyとIssues read/writeに限定済み
- GitHub publishの失敗/再試行/監査方針は `docs/security/20260630_github_integration_security_design.md` に作成済み
- ISSUE-012としてGitHub App実装準備へ進める

## 進捗

完了。GitHub Issue同期済み。
