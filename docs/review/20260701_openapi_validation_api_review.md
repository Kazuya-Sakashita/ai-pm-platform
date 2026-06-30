# 20260701_openapi_validation_api_review

## 評価日時

2026-07-01 04:32 JST

## 評価担当

Codex as CTO, Tech Lead, Backend Architect, Frontend Architect, Security Engineer, QA

## 使用フレームワーク

G-STACK、DDD、ISO25010、OWASP Top 10、C4 Model

## 評価対象

- ISSUE-004: OpenAPI Draft validation API
- Backend: `OpenApiDraftValidationService`, `/api/v1/openapi-drafts/{id}/validate`
- Frontend: OpenAPI Draft validation UI
- Tests: RSpec service/request specs, Playwright E2E

## 良かった点

- OpenAPI Draftの現在contentを保存してから検証するため、ユーザーが見ているYAMLと検証対象がずれにくい。
- `valid=false` をHTTPエラーではなく検証結果として返しており、APIエラーと成果物エラーを分離できている。
- validation処理を `job_type=validation` のJobとAuditLogへ接続し、監査できる形にした。
- `valid` / `invalid` に応じてDraft statusと `validation_errors` を更新し、Review gateの材料を保存できる。
- Frontendでerrors/warningsを分けて表示し、E2Eでvalid/invalid両方の導線を確認している。

## 改善点

- 現在のvalidatorはRails内の軽量チェックであり、OpenAPI 3.1の完全なschema validationやlintではない。
- `validation_errors` は `string[]`、validateレスポンスは `ValidationIssue[]` で、保存粒度とレスポンス粒度に差がある。
- validation成功はReview承認の代替ではないが、Review blockerやApprove無効化とはまだ連動していない。
- `in_review` / `approved` のDraftはvalid時にstatusを保持するが、content変更後に承認済みstatusをどう扱うかは未決。
- validation endpointのOpenAPI contractに `401/403/422/429/500` が不足している。
- content hashはAuditLogへ保存しているが、artifact versioningがないため差分追跡は弱い。

## 優先順位

1. P0: validation結果をReview gateへ接続し、invalid Draftから実装・公開へ進めないようにする。
2. P0: Backend runtime validatorをRedocly CLI、openapi_parser、または別ライブラリへ強化するADRを作る。
3. P0: content変更時のapproved/in_review status取り扱いをADR化する。
4. P1: `validation_errors` の保存形式を `ValidationIssue[]` 相当へ移行するか決める。
5. P1: validate endpointのエラーレスポンス定義を補強する。
6. P2: Frontendにfirst error jump / copy errorsを追加する。

## 次アクション

- ISSUE-004は継続OPEN。次はGitHub Issue公開APIとReview gate連動を進める。
- ISSUE-005の専門家AIレビュー保存パイプラインと接続し、validation failureをReview Actionに変換する。
- ISSUE-006のセキュリティ設計と接続し、validator実行時のsecret漏洩、raw YAML監査ログ保存禁止、rate limitを明文化する。

## 検証結果

- `bundle exec rspec`: 53 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities

## Issue番号

ISSUE-004

GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/4
