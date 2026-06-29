# 2026-06-30 API設計強化

## 対象Issue

- ISSUE-008: 実装前にAPI/DB設計を強化する

## 目的

API初稿で不足していた、非同期job、GitHub連携、OpenAPI validation、pagination、accepted_riskを実装前に補強する。

## 変更対象

- `docs/api/openapi.yaml`

## 追加したAPI

### Jobs API

AI生成、GitHub公開、GitHub接続、OpenAPI validationなど、時間のかかる処理をjobとして追跡する。

追加endpoint:

- `GET /jobs/{job_id}`

job status:

- queued
- running
- succeeded
- failed
- cancelled

job type:

- ai_generation
- github_publish
- github_connect
- validation

### GitHub Integration API

GitHub接続、callback、disconnectをAPIとして明示した。

追加endpoint:

- `POST /projects/{project_id}/integrations/github/connect`
- `POST /projects/{project_id}/integrations/github/disconnect`
- `POST /integrations/github/callback`

MVPではGitHub App/OAuthの最終選定はADRで扱う。API contract上は、接続開始URL、state、callback、disconnectを表現できるようにした。

### OpenAPI Validation API

OpenAPI Draftをレビュー前に検証するAPIを追加した。

追加endpoint:

- `POST /openapi-drafts/{openapi_draft_id}/validate`

validation result:

- valid
- errors
- warnings

### Review accepted risk API

レビュー指摘を未解決のまま進める場合の例外承認をAPI化した。

追加endpoint:

- `POST /reviews/{review_id}/accept-risk`

必須項目:

- reason
- residual_risk
- expires_at
- linked_issue_number

Security P0 blockerはaccepted_risk不可とする。この制約は実装時にdomain policyとして強制する。

### Pagination標準

list APIに `page` と `per_page` を導入した。

対象:

- `GET /projects`
- `GET /projects/{project_id}/meetings`
- `GET /reviews`
- `GET /projects/{project_id}/audit-logs`

レスポンスは `meta.page`, `meta.per_page`, `meta.total_count`, `meta.total_pages` を返す。

## エラー詳細マスキング

`Job` schemaに `safe_error_detail` を追加した。developer detailをそのまま返すのではなく、token、secret、raw transcript、prompt全文を含まない安全なエラー詳細だけを返す。

## 実装時ポリシー

- GitHub publish、disconnect、callback処理は `Idempotency-Key` を使う。
- AI生成jobは再試行時に前回input hash、prompt version、modelを記録する。
- `safe_error_detail` はUI表示用であり、内部ログとは分ける。
- `accepted_risk` は監査ログ必須。
- P0 security blockerはaccepted_risk不可。

## 未解決

- GitHub AppとOAuth Appの最終選定
- `/jobs/{job_id}/cancel` の要否
- list APIのfilter/sort標準
- cursor paginationへ移行する条件
- OpenAPI validationライブラリの選定

