# 20260630_api_design_review

## 評価日時

2026-06-30 04:25 JST

## 評価担当

Codex as CTO, Tech Lead, Backend Architect, AI Architect, Security Engineer, QA

## 使用フレームワーク

OpenAPIレビュー、DDD、OWASP Top 10、ISO25010

## 評価対象

- `docs/api/20260630_api_design.md`
- `docs/api/openapi.yaml`

## 良かった点

- Projects、Meetings、Minutes、Requirements、Issue Drafts、OpenAPI Drafts、Reviews、Integrations、Audit Logsの境界が明確。
- レビュー未通過時の `review_required` がAPIエラーとして定義されている。
- GitHub公開など外部連携に `Idempotency-Key` を考慮している。
- AI生成を同期レスポンスではなくjobとして扱う設計になっている。
- エラー形式が統一され、Frontendが扱いやすい。

## 改善点

- Job取得APIが未定義。`GenerationJobResponse` を返すなら `/jobs/{id}` が必要。
- 認証、ユーザー、セッション、チーム管理APIが未定義。
- GitHub OAuth/App接続開始、callback、disconnect APIが未定義。
- OpenAPI validation APIが未定義。
- レビュー承認APIが対象ごとに分散しており、汎用approval設計を検討すべき。
- Pagination、sorting、filteringの標準が未定義。

## 優先順位

1. P0: Jobs APIを追加
2. P0: GitHub integration connect/disconnect APIを追加
3. P0: OpenAPI validation APIを追加
4. P0: Pagination標準を追加
5. P1: 汎用approval APIの採否をADR化
6. P1: Auth/User APIをMVP範囲に含めるか決定

## 次アクション

- `docs/api/openapi.yaml` にJobs、GitHub integration、OpenAPI validationを追加する。
- API設計レビューの指摘をISSUE-004とISSUE-006へ反映する。
- Backend実装前にOpenAPI lintと型生成の方針を決める。

## Issue番号

ISSUE-004、ISSUE-005、ISSUE-006、ISSUE-008

GitHub Issue: 登録待ち。理由: remote未設定、GitHub CLI token invalid。
