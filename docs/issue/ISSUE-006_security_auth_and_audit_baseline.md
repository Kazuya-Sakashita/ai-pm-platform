# ISSUE-006: OAuth、認証、監査、データ保護の初期設計を作る

## GitHub Issue

登録待ち。

理由: `gh auth status` で GitHub token invalid。初期時点でremote未設定。

登録試行: ISSUE-001登録時に `no git remotes found` が確認されたため、remote設定と再認証後に登録する。

## 背景

会議内容、要件、Issue、API設計には機密情報が含まれる。外部連携も多いため、MVP段階からセキュリティを設計する必要がある。

## 目的

OAuth、認証、権限、監査ログ、秘密情報検出、データ保持の初期方針を定義する。

## 完了条件

- GitHub連携の最小権限が定義されている
- Discord連携の権限が定義されている
- 外部連携トークン保存方針が定義されている
- AuditLogモデルが設計されている
- データ保持と削除方針が定義されている
- STRIDEレビューが保存されている

## スコープ

- OAuth設計
- 監査ログ
- 秘密情報検出
- データ保持
- OWASP/STRIDEレビュー

## 非スコープ

- Enterprise SSO
- SOC2正式対応
- 高度なDLP

## 関連レビュー

- `docs/review/20260629_mvp_review.md`
- `docs/review/20260629_requirements_review.md`
- `docs/review/20260630_screen_design_review.md`
- `docs/review/20260630_api_design_review.md`
- `docs/review/20260630_db_design_review.md`

## レビュー結果

P0として必須。セキュリティを後から足すとプロダクト価値と信頼を損なう。

## 次アクション

- GitHub OAuth/App比較ADRを作成する
- Discord Bot権限表を作る
- AuditLog ERD初稿は `docs/architecture/20260630_db_design.md` に作成済み
- ISSUE-008としてsecret_scan_results、暗号化方針、integration APIを詳細化する
