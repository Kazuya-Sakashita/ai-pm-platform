# 20260630_issue_openapi_draft_generation_review

## 評価日時

2026-06-30 20:28 JST

## 評価担当

Codex as Product Manager, CTO, Tech Lead, AI Architect, Backend Architect, Frontend Architect, Security Engineer, QA

## 使用フレームワーク

G-STACK、DDD、ISO25010、OWASP Top 10、RICE

## 評価対象

- ISSUE-004: 要件からGitHub IssueとOpenAPIドラフトを生成する
- Backend: Issue Draft / OpenAPI Draft models, services, controllers, routes, migrations
- Frontend: Meeting Workspace Issue Draft / OpenAPI Draft panels
- Tests: RSpec request/service specs, Playwright happy path

## 良かった点

- 承認済みRequirementだけがIssue Draft / OpenAPI Draft生成へ進めるため、AGENTS.mdのレビューゲート原則と整合している。
- 生成処理がJob、AuditLog、Draft artifactに接続され、AI生成物の監査可能性が上がった。
- Draftを直接GitHubや実装へ流さず、編集可能な中間成果物として保持している。
- OpenAPI DraftをYAMLとしてFrontendから確認、編集、保存でき、API駆動開発の次工程に進む土台ができた。
- Request specとservice specに加え、Playwrightで会議からIssue/OpenAPI Draft生成までの主要導線を押さえている。

## 改善点

- GitHub Issue公開処理、GitHub App/OAuth、冪等性キー、公開失敗時リトライが未実装で、完了条件の一部を満たしていない。
- OpenAPI validation APIが未実装で、生成YAMLが実際にlint/contract checkを通る保証がまだ弱い。
- deterministic providerはMVPとして有効だが、AI provider接続時のJSON schema validation、prompt injection対策、再生成差分管理が未設計。
- Issue DraftとOpenAPI Draftの承認フローがReview APIと完全には連動していない。
- Draft編集履歴が残らず、誰がどの変更をしたかを後から追いにくい。
- Frontendは導線が増えた一方で、画面密度が上がっており、将来的にはartifact timelineやタブ化が必要。

## 優先順位

1. P0: GitHub Issue公開APIを実装し、`github_issue_number` と `github_issue_url` を保存する。
2. P0: OpenAPI validation APIを実装し、Draft保存時または明示実行時にvalidation結果を保存する。
3. P0: Draft承認とReview解決状態を連動させ、未承認Draftから実装へ進めないようにする。
4. P1: AI provider接続時のprompt/schema/secret filtering設計を `docs/ai/` と `docs/security/` に保存する。
5. P1: Draft artifact versioningの採否をADR化する。
6. P2: FrontendのDraft領域をartifact-firstの情報設計へ整理する。

## 次アクション

- ISSUE-004はクローズせず、GitHub公開とOpenAPI validationを残タスクとして継続する。
- ISSUE-006のGitHub連携、ISSUE-005のセキュリティ設計と接続して、OAuth/App権限を先に固める。
- 次の実装では `/issue-drafts/{id}/publish-github` と `/openapi-drafts/{id}/validate` をAPI駆動で追加する。
- Draft承認とReview APIの状態遷移をDDD/Event Stormingで見直す。

## 検証結果

- `bundle exec rspec`: 47 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities

## Issue番号

ISSUE-004

GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/4
