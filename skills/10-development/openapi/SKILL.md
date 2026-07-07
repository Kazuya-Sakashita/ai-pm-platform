---
name: openapi
description: OpenAPI contractを設計、更新、検証するSkill。docs/api/openapi.yaml、生成型、API error response、request/response schemaを変更するときに使う。
---

# OpenAPI

## Purpose

API contractを実装前に明確にし、Backend/Frontendの乖離を防ぐ。

## When to use

- API path、method、schema、error responseを追加変更するとき。
- Frontend型生成が必要なとき。
- API設計レビューを書くとき。

## Inputs

- Issueと要件。
- 既存 `docs/api/openapi.yaml`。
- 既存schema、response、parameter。

## Process

1. 既存pathとschemaの命名に合わせる。
2. request、response、errorを明確にする。
3. 安全なerror codeとdetailsだけ返す。
4. `npm run api:verify` を実行する。
5. 生成型差分を確認する。
6. API設計レビューを保存する。

## Output

- 更新済みOpenAPI。
- 生成済みFrontend型。
- API設計レビュー。

## Constraints

- 実装後にOpenAPIを後追いしない。
- raw exceptionやsecretをschemaに含めない。
- breaking changeはIssueとレビューで明示する。

## Checklist

- [ ] path、operationId、schemaが命名規則に合う。
- [ ] error responseがある。
- [ ] `api:verify` が成功した。
- [ ] 生成型差分を確認した。
