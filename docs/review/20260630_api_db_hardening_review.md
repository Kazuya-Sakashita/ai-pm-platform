# 20260630_api_db_hardening_review

## 評価日時

2026-06-30 06:27 JST

## 評価担当

Codex as CTO, Tech Lead, Backend Architect, Security Engineer, DevOps, QA

## 使用フレームワーク

OpenAPI Review、DDD、STRIDE、OWASP Top 10、ISO25010

## 評価対象

- `docs/api/20260630_api_design_hardening.md`
- `docs/api/openapi.yaml`
- `docs/architecture/20260630_db_design_hardening.md`
- `docs/decisions/ADR-0002_mvp_data_security_and_hardening.md`
- `docs/security/20260630_secret_scan_error_masking_policy.md`

## 良かった点

- Jobs API、GitHub connect/disconnect/callback、OpenAPI validation、paginationが追加され、実運用に近づいた。
- artifact_versions、secret_scan_results、jobs、accepted_risks、organizations、membershipsをMVPから採用する判断は、AI PMの監査性と信頼性に合っている。
- raw_textとAI出力を暗号化対象にしたことで、会議データを扱うSaaSとして最低限の守りが入った。
- `safe_error_detail` と `internal_error_ref` を分け、UI/APIへの情報漏洩を抑える方向になった。
- OpenAPIのYAML構文とschema/parameter/response参照の簡易チェックが通った。

## 改善点

- GitHub AppとOAuth Appの最終判断がまだ未決。
- ActiveRecord Encryptionの具体設定、key rotation、検索制約が未設計。
- secret scan detectorの採用候補と検出精度評価が未定義。
- `accepted_risk` の権限、期限切れ通知、失効フローがまだ薄い。
- OpenAPI lint、contract test、型生成の実行環境が未定義。
- paginationはpage basedのみで、将来の大量audit logにはcursor paginationを検討すべき。

## 優先順位

1. P0: GitHub App vs OAuth AppのADRを作成
2. P0: ActiveRecord Encryptionとkey rotation方針を作成
3. P0: secret scan detector候補を比較
4. P0: OpenAPI lint/型生成/contract test方針を作成
5. P1: accepted_riskの期限切れ通知と失効フローを設計
6. P1: audit log向けcursor pagination移行条件を定義

## 次アクション

- ISSUE-010としてGitHub連携方式とOAuth/App権限設計を進める。
- Backend実装前にOpenAPI lintと型生成のツール選定を行う。
- セキュリティ設計でkey rotation、secret scan、accepted_risk失効を深掘りする。

## Issue番号

ISSUE-008、ISSUE-010

GitHub Issue: 登録待ち。理由: remote未設定、GitHub CLI token invalid。

