# ISSUE-003: 議事録から要件定義ドラフトを生成する

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/3

登録日: 2026-06-30
同期方法: `scripts/sync-github-issues.rb --apply`

## 背景

AI議事録ツールとの差別化には、会議内容を実装可能な要件に変換する能力が必要である。

## 目的

議事録から背景、目的、ユーザーストーリー、受け入れ条件、非機能要件、未決事項を生成する。

## 完了条件

- 要件定義ドラフトを生成できる
- 曖昧な項目を未決事項として抽出できる
- 専門家レビューを保存できる
- 人間が編集できる
- Issue生成に使える構造になっている

## スコープ

- 要件定義生成
- 未決事項抽出
- 受け入れ条件生成
- レビュー保存

## 非スコープ

- 完全自動承認
- 複数プロジェクト横断優先度最適化

## 関連レビュー

- `docs/review/20260629_mvp_review.md`
- `docs/review/20260629_requirements_review.md`
- `docs/review/20260630_screen_design_review.md`
- `docs/review/20260630_db_design_review.md`
- `docs/review/20260630_requirements_generation_mvp_review.md`
- `docs/review/20260630_requirement_quality_evaluation_review.md`
- `docs/review/20260630_requirement_approval_gate_review.md`
- `docs/review/20260706_requirement_generation_quality_baseline_review.md`
- `docs/review/20260706_requirement_generation_provider_rules_review.md`
- `docs/review/20260706_requirement_approval_review_center_gate_review.md`

## レビュー結果

本プロダクトの中核機能としてP0。ただし、AI出力品質の評価セットと人間編集UIがないと信頼されない。

2026-06-30 16:40 JST追加:

- `requirements` テーブル、Requirement model、factoryを追加
- `RequirementGenerationService` とdeterministic providerを追加
- `/minutes/{minutes_id}/generate-requirement` を実装
- `/requirements/{requirement_id}` の取得/更新を実装
- Minutesが `approved` になるまでRequirement生成を409 `review_required` でブロック
- FrontendにRequirement Workspace、生成、編集保存、Requirement review依頼導線を追加
- Playwright E2EでMinutes承認後のRequirement生成、編集保存、レビュー依頼を確認
- `bundle exec rspec`: 33 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: 成功。OpenAPI contract warningなし
- `npm run frontend:build`: 成功
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities

2026-06-30 18:50 JST追加:

- Requirement生成品質評価セットを `docs/evaluation/20260630_requirement_generation_quality_eval.md` に文書化
- G-STACK / ISO25010 / MoSCoW / STRIDEによる評価セットレビューを `docs/review/20260630_requirement_quality_evaluation_review.md` に保存
- 評価目的、対象出力項目、サンプルケース、採点rubric、合格基準、失敗時の改善アクション、今後の自動化案を定義
- 品質評価セットは文書化完了。ただし、fixture化、golden dataset、現行providerのbaseline score取得は未完了

2026-06-30 18:52 JST追加:

- `POST /requirements/{requirement_id}/approve` をOpenAPI、Backend、Frontendへ追加
- Requirementの `open_questions` が残る場合は409 `review_required` で承認をブロック
- Requirement承認時に `requirement.approved` AuditLogを保存
- FrontendにApprove Requirements導線を追加
- Playwright E2EでMinutes承認、Requirement生成、編集保存、Requirement review依頼、Requirement承認まで確認
- `bundle exec rspec`: 35 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: 成功。OpenAPI contract warningなし
- `npm run frontend:build`: 成功
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities

2026-07-06 20:06 JST追加:

- Requirement生成品質評価を `docs/evaluation/fixtures/requirement_generation/cases.json` としてfixture化
- `scripts/evaluate-requirement-generation.rb` を追加し、現行providerの採点を自動化
- `npm run requirements:evaluate` を追加
- baseline reportを `docs/evaluation/20260706_requirement_generation_baseline.md` に保存
- 評価器のRSpecを `backend/spec/scripts/evaluate_requirement_generation_spec.rb` に追加
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec rspec spec/scripts/evaluate_requirement_generation_spec.rb spec/services/requirement_generation_service_spec.rb`: 4 examples, 0 failures
- baseline結果: 平均91.0点、ケース別最低79.2点、Critical failure 0件、P0基準未達6件
- 判定: 評価基盤は完了。ただしP0基準未達が残るためIssue #3は継続

2026-07-06 20:10 JST追加:

- deterministic providerに非スコープ抽出ruleを追加
- Security/PII/secret/監査/権限/CI/UXを含む非機能要件抽出ruleを追加
- provider再利用時に前回Minutesのsource textが残る不具合を修正
- provider単体RSpecを `backend/spec/services/requirement_generation_deterministic_provider_spec.rb` に追加
- 改善後baseline reportを `docs/evaluation/20260706_requirement_generation_provider_rules_baseline.md` に保存
- 改善後baseline結果: 平均100.0点、ケース別最低100.0点、Critical failure 0件、P0基準未達0件
- 判定: deterministic providerのfixture上の品質改善は完了。ただしIssue #3は次工程接続が残るため継続

2026-07-06 20:52 JST追加:

- `RequirementApprovalGate` を追加し、Requirement承認条件をService Objectへ分離
- Requirement対象のReviewに `open` または `action_required` が残る場合、Requirement承認を409 `review_required` でブロック
- `resolved` と `accepted_risk` のReviewは承認可能状態として扱う
- Requirement Workspaceに `要件レビュー対応済み` 導線を追加し、Review Centerの対象レビューをresolvedへ更新できるようにした
- Playwright happy pathを、要件レビュー依頼、要件レビュー解決、Requirement承認の順番に更新
- Issue/OpenAPI生成条件は既存実装で `requirement.status == "approved"` を要求していることを確認
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec rspec spec/services/requirement_approval_gate_spec.rb spec/requests/api/v1/requirements_spec.rb spec/requests/api/v1/issue_drafts_spec.rb spec/requests/api/v1/open_api_drafts_spec.rb`: 48 examples, 0 failures
- `npm run frontend:build`: success
- `npm run display:check`: success
- 判定: Review Center resolved状態とRequirement承認条件の接続は完了。ただし承認メタデータとrisk acceptance期限管理が残るためIssue #3は継続

未完了:

- OpenAI providerによるRequirement生成
- Requirement Workspaceの差分、未決事項、リスク強調UX
- Requirement Workspaceで未解決Review件数と承認blocker詳細を表示する
- 承認者、承認日時、再編集時の状態戻し
- accepted_riskの期限切れをRequirement承認blockerにする

## 次アクション

- Requirement承認者、承認日時、承認コメントをDB/APIへ追加する
- accepted_riskの期限切れをRequirement承認blockerにする
- Requirement Workspaceで未解決Review件数と承認blocker詳細を表示する
- OpenAI providerを導入する場合は、同じfixtureでdeterministic providerと比較する
