# 20260701_openapi_validation_review_gate_review

## 評価日時

2026-07-01 04:42 JST

## 評価担当

Codex as Product Manager, CTO, Tech Lead, Backend Architect, Frontend Architect, Security Engineer, QA

## 使用フレームワーク

G-STACK、DDD、ISO25010、OWASP Top 10、RICE

## 評価対象

- ISSUE-004: OpenAPI validation結果とReview blocker / approval gate連動
- Backend: `OpenApiDraftReviewGateService`, OpenAPI Draft validation controller連携
- Frontend: Meeting Workspace Review gate / API blocker表示
- Tests: RSpec service/request specs, Playwright E2E

## 良かった点

- OpenAPI validation失敗を `action_required` Reviewとして保存し、AGENTS.mdの「レビューなしで次工程へ進まない」ルールに近づいた。
- 再validation成功時に既存Review blockerを `resolved` に更新し、修正済み状態を監査できる。
- `accepted_risk` はvalid時にも自動上書きしないため、人間が受容したリスク判断を破壊しない。
- FrontendのReview gateでOpenAPI blocker状態を確認でき、APIエラーと成果物エラーが混ざりにくい。
- invalidからvalidへ戻すE2Eを追加し、Review blockerの生成と解消を通しで確認している。

## 改善点

- GitHub Issue公開APIや実装開始APIが未実装のため、blockerは見えるが最終的な公開停止条件にはまだ接続されていない。
- OpenAPI Draftの `approved` / `in_review` 状態でcontent変更があった場合のstatus降格ルールは未決。
- Review blockerはOpenAPI validationに限定されており、Issue Draft品質やSecurity Reviewとはまだ統合されていない。
- `Review` は汎用jsonbで柔軟だが、blocker種別やseverityの構造化が弱い。
- Frontendは最新のOpenAPI Validatorレビューのみ表示しており、複数blocker履歴の比較や差分追跡は弱い。

## 優先順位

1. P0: GitHub Issue公開APIで、OpenAPI Draftがinvalidまたはaction_required blockerありの場合に公開を拒否する。
2. P0: content変更時のapproved/in_review status降格ルールをADR化する。
3. P0: Review blocker種別とseverityの構造化を検討する。
4. P1: Issue Draft側にも品質Review blockerを接続する。
5. P1: Frontendで複数Review/Blocker履歴を一覧できるようにする。
6. P2: accepted riskの期限切れ検知を追加する。

## 次アクション

- ISSUE-004は継続OPEN。次はGitHub Issue publish APIとpublish gateを実装する。
- publish APIでは `IssueDraft` のstatus、`OpenApiDraft` のstatus、OpenAPI Validator Reviewのstatusを確認する。
- GitHub App実接続前はdry-run/fake providerでrequest specとE2Eを先に固める。

## 検証結果

- `bundle exec rspec`: 58 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities

## Issue番号

ISSUE-004

GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/4
