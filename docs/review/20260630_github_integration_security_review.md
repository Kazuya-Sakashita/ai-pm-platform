# 20260630_github_integration_security_review

## 評価日時

2026-06-30 06:34 JST

## 評価担当

Codex as CTO, Security Engineer, Backend Architect, DevOps, QA, Product Manager

## 使用フレームワーク

ADR、STRIDE、OWASP Top 10、MoSCoW、ISO25010

## 評価対象

- `docs/decisions/ADR-0003_github_integration_app_over_oauth.md`
- `docs/security/20260630_github_integration_security_design.md`

## 良かった点

- GitHub Appを採用する判断は、リポジトリ単位の最小権限、短命token、将来拡張の観点で妥当。
- MVP権限をMetadata read-onlyとIssues read/writeに限定しており、過剰権限を避けている。
- publish guardがIssue承認、Review blocker、secret scan、idempotencyを含んでおり、プロダクトのReviewOps思想と一致している。
- Disconnect時に過去Issueを削除しない方針は、監査性とユーザー期待に合う。
- webhook署名検証とsafe_metadata保存が明記され、情報漏洩リスクを抑えている。

## 改善点

- GitHub Appの具体的な作成手順、callback URL、webhook URL、秘密情報の設定手順が未作成。
- installation access tokenのキャッシュ可否と有効期限管理がまだ抽象的。
- GitHub API clientライブラリ、retry/backoff、rate limit handlingの実装方針が未定義。
- App権限変更時にユーザーへ再承認を促すUXが未設計。
- GitHub publishのidempotencyをDB上でどう保証するか、unique constraint設計が必要。

## 優先順位

1. P0: GitHub App作成手順と環境変数一覧を作成
2. P0: installation access token生成、暗号化、キャッシュ方針をBackend設計へ追加
3. P0: GitHub publish idempotencyのDB制約を設計
4. P1: GitHub rate limit/retry/backoff方針を作成
5. P1: GitHub権限変更時の再接続UXを設計

## 次アクション

- ISSUE-012としてGitHub App実装準備を登録する。
- API/DB設計にGitHub installation id、repository owner/name、publish idempotency keyを反映する。
- Backend実装前にGitHub App秘密情報の環境変数とrotation方針を決める。

## Issue番号

ISSUE-010、ISSUE-012

GitHub Issue: 登録待ち。理由: remote未設定、GitHub CLI token invalid。

