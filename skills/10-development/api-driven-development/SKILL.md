---
name: api-driven-development
description: API駆動開発を進めるSkill。Issue、要件、OpenAPI、レビュー、Backend、Frontend、テスト、PRの順序を守る必要がある作業で使う。
---

# API Driven Development

## Purpose

OpenAPIを契約として、BackendとFrontendを安全に分離して実装する。

## When to use

- API追加、変更、削除を伴う作業。
- Frontend/Backendをまたぐ機能。
- Issueから実装へ進む前。

## Inputs

- Issue番号と完了条件。
- 要件定義または既存仕様。
- `docs/api/openapi.yaml`。
- 関連レビュー文書。

## Process

1. Issueを確認する。
2. 要件と非スコープを確認する。
3. OpenAPIを先に更新する。
4. API設計レビューを保存する。
5. Backendを実装する。
6. Frontend型生成とUIを実装する。
7. RSpec、E2E、`npm run api:verify` を実行する。
8. 実装レビューを保存する。

## Output

- 更新済みOpenAPI。
- Backend/Frontend実装。
- テスト結果。
- レビュー文書とIssue更新。

## Constraints

- OpenAPIと実装が乖離した状態で完了しない。
- ControllerやUIに業務ロジックを詰め込まない。
- API error contractを安全に保つ。

## Checklist

- [ ] Issueがある。
- [ ] OpenAPIを先に更新した。
- [ ] `api:verify` が成功した。
- [ ] Backend testがある。
- [ ] Frontend/E2E検証がある。
- [ ] レビュー文書がある。
