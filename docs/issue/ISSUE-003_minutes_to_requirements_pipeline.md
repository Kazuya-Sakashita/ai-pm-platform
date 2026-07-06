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
- `docs/review/20260707_requirement_accepted_risk_expiry_gate_review.md`
- `docs/review/20260707_requirement_approval_audit_metadata_review.md`
- `docs/review/20260707_requirement_blocker_details_design_review.md`
- `docs/review/20260707_requirement_blocker_details_implementation_review.md`
- `docs/review/20260707_downstream_draft_stale_design_review.md`
- `docs/review/20260707_downstream_draft_stale_implementation_review.md`
- `docs/review/20260707_requirement_followup_issue_split_review.md`
- `docs/review/20260707_requirement_stale_regeneration_ux_design_review.md`
- `docs/review/20260707_requirement_stale_regeneration_ux_implementation_review.md`
- `docs/review/20260707_requirement_history_timeline_design_review.md`
- `docs/review/20260707_requirement_history_timeline_implementation_review.md`

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
- FrontendにRequirement承認導線を追加
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
- Requirement Workspaceに `要件レビュー対応済み` 導線を追加し、レビューセンターの対象レビューをresolvedへ更新できるようにした
- Playwright happy pathを、要件レビュー依頼、要件レビュー解決、Requirement承認の順番に更新
- Issue/OpenAPI生成条件は既存実装で `requirement.status == "approved"` を要求していることを確認
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec rspec spec/services/requirement_approval_gate_spec.rb spec/requests/api/v1/requirements_spec.rb spec/requests/api/v1/issue_drafts_spec.rb spec/requests/api/v1/open_api_drafts_spec.rb`: 48 examples, 0 failures
- `npm run frontend:build`: success
- `npm run display:check`: success
- 判定: レビューセンターのresolved状態とRequirement承認条件の接続は完了。ただし承認メタデータとリスク受容期限管理が残るためIssue #3は継続

2026-07-07 04:39 JST追加:

- `RequirementApprovalGate` で `accepted_risk.expires_at` を評価するようにした
- 期限内のリスク受容はRequirement承認可能、期限切れ、期限未設定、不正日時は409 `review_required` で承認ブロック
- API error detailsへ `expired_accepted_risk_review_ids` と `accepted_risk_expires_at` を含める
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec rspec spec/services/requirement_approval_gate_spec.rb spec/requests/api/v1/requirements_spec.rb spec/requests/api/v1/issue_drafts_spec.rb spec/requests/api/v1/open_api_drafts_spec.rb`: 51 examples, 0 failures
- 判定: `accepted_risk` 期限切れブロッカーは完了。ただし承認メタデータとOpenAI provider比較が残るためIssue #3は継続

2026-07-07 05:10 JST追加:

- `requirements` に `approved_at`、`approved_by`、`approval_note` を追加
- Requirement承認APIで `approval_note` を必須化し、未入力時は422 `approval_note_required` を返す
- Requirement承認時に `approved_by` は認証済みactor、`approved_at` はサーバー時刻で保存
- AuditLogには承認コメント本文を保存せず、`approval_note_present` と `approved_at` のみをmetadataへ保存
- OpenAPIに `ApproveRequirementRequest`、422レスポンス、Requirement承認メタデータを追加
- Frontend型定義を更新し、Requirement Workspaceで承認コメント入力、承認者、承認日時、承認コメントを表示
- Playwright happy pathで承認コメント初期値と承認者表示を確認
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec rspec spec/services/requirement_approval_gate_spec.rb spec/requests/api/v1/requirements_spec.rb spec/requests/api/v1/issue_drafts_spec.rb spec/requests/api/v1/open_api_drafts_spec.rb`: 52 examples, 0 failures
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: 成功
- `npm run frontend:build`: 成功
- `npm run display:check`: 成功
- 判定: 承認者、承認日時、承認コメントのDB/API/UI接続は完了。ただし再編集時の状態戻しとブロッカー詳細表示が残るためIssue #3は継続

2026-07-07 05:20 JST追加:

- `RequirementRevisionService` を追加し、Requirement更新時のレビュー対象フィールド差分を検知
- 承認済みRequirementの重要フィールドが変わる場合、`status` を `needs_changes` に戻し、`approved_at`、`approved_by`、`approval_note` をクリア
- PATCHで `status` を直接送る状態変更API迂回を422 `requirement_direct_status_update_not_allowed` で拒否
- AuditLog metadataへ `changed_fields` と `approval_reset` を保存
- OpenAPIの `UpdateRequirementRequest.status` を削除し、Frontend型定義を同期
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec rspec spec/services/requirement_revision_service_spec.rb spec/services/requirement_approval_gate_spec.rb spec/requests/api/v1/requirements_spec.rb spec/requests/api/v1/issue_drafts_spec.rb spec/requests/api/v1/open_api_drafts_spec.rb`: 51 examples, 0 failures
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: 成功
- `npm run display:check`: 成功
- `npm run frontend:build`: 成功
- `npm run frontend:e2e -- --grep "creates a project, saves a Discord log, generates minutes, and requests review"`: 1 passed
- 判定: 承認済みRequirement再編集時の状態戻しは完了。ただしPR CI、ブロッカー詳細表示、下流draft stale化が残るためIssue #3は継続

2026-07-07 06:38 JST追加:

- Requirement Workspaceに承認ブロッカーパネルを追加
- Requirement専用の `requirementReviews` stateを追加し、`GET /reviews?target_type=requirement&target_id=...` で対象レビューを取得
- Requirement生成、保存、承認、レビュー依頼、レビュー解決後にRequirement reviewsを同期
- 未決事項、未解決レビュー、期限切れリスク受容を件数表示
- 未解決レビュー、期限切れリスク受容、承認コメント不足を詳細ブロッカーとして表示
- `要件レビュー対応済み` はRequirement対象の未解決レビューを解決するように変更
- 承認ボタンは未決事項、未解決レビュー、期限切れリスク受容、承認コメント不足がある場合に無効化
- E2Eで未決事項件数、未解決レビュー件数、レビュー詳細、承認ボタン無効化、解決後の復帰を確認
- `npm run frontend:e2e -- --grep "creates a project, saves a Discord log, generates minutes, and requests review"`: 1 passed
- `npm run frontend:build`: 成功
- `npm run display:check`: 成功
- `npm run api:verify`: 成功
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec rspec spec/requests/api/v1/reviews_spec.rb spec/requests/api/v1/requirements_spec.rb`: 22 examples, 0 failures
- PR CI初回でGitHub照合系E2Eのモック未追従を検知し、Requirement reviews取得の空配列モックを追加
- `npm run frontend:e2e -- --grep "GitHub reconciliation|GitHub Issue candidate|linking an existing GitHub Issue|GitHub Issue from another repository"`: 7 passed
- `npm run frontend:e2e -- --grep "links an existing GitHub Issue from pending reconciliation"`: 1 passed
- 判定: Requirement Workspaceでの承認ブロッカー詳細表示は完了。ただし下流draft stale化、差分履歴、OpenAI provider比較が残るためIssue #3は継続

2026-07-07 06:58 JST追加:

- OpenAPIの `IssueDraftStatus` と `OpenApiDraftStatus` に `stale` を追加
- Backend modelとFrontend生成型を同期
- `RequirementRevisionService` で承認済みRequirementのレビュー対象フィールドが変わる場合、関連Issue DraftとOpenAPI Draftを `stale` に更新
- stale化はRequirement更新と同じトランザクション内で実施
- AuditLog metadataへ `stale_issue_draft_ids`、`stale_issue_draft_count`、`stale_open_api_draft_ids`、`stale_open_api_draft_count` を保存
- FrontendはRequirement保存時に既存の下流Draftを消さず、stale表示として「再確認が必要」を表示
- Playwright happy pathで、Issue/OpenAPI Draft生成後のRequirement再編集により両Draftが「再確認が必要」になることを確認
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec rspec spec/services/requirement_revision_service_spec.rb spec/requests/api/v1/requirements_spec.rb spec/requests/api/v1/issue_drafts_spec.rb spec/requests/api/v1/open_api_drafts_spec.rb`: 52 examples, 0 failures
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: 成功
- `npm run display:check`: 成功
- `npm run frontend:build`: 成功
- `npm run frontend:e2e -- --grep "creates a project, saves a Discord log, generates minutes, and requests review"`: 1 passed
- 判定: Requirement差し戻し時の下流Issue/OpenAPI Draft stale化は完了。ただし差分履歴、stale後の再生成UX、OpenAI provider比較が残るためIssue #3は継続

2026-07-07 07:05 JST追加:

- 残課題を並行実施できる単位へ分割Issue化
- ISSUE-050 / GitHub #67: Requirement差分履歴とレビュー履歴タイムライン
- ISSUE-051 / GitHub #68: stale後の下流Draft再生成UX
- ISSUE-052 / GitHub #69: Requirement生成OpenAI provider比較
- ISSUE-053 / GitHub #70: Requirement Workspaceの未決事項、リスク、差分強調UX
- 分割レビューを `docs/review/20260707_requirement_followup_issue_split_review.md` に保存
- 判定: Issue #3は親Issueとして継続し、子Issueの完了状況を見て最終クローズ判断する

2026-07-07 07:18 JST追加:

- ISSUE-051 / GitHub #68でstale後の下流Draft再生成UXを実装
- Issue/OpenAPI Draftのstale状態に再生成案内を追加
- Frontendでstale Draftの保存、承認、公開、検証操作を無効化
- Backend/APIでもstale Draftの更新、公開、検証を409 `stale_draft` で拒否
- Requirement再承認後に新しいIssue DraftとOpenAPI Draftを再生成できることをPlaywrightで確認
- 既存stale Draftを上書きせず保持することをRequest specで確認
- 判定: ISSUE-051の中核要件は完了。Issue #3はISSUE-050、ISSUE-052、ISSUE-053完了状況を見て最終クローズ判断する

2026-07-07 07:42 JST追加:

- ISSUE-050 / GitHub #67でRequirement差分履歴とレビュー履歴タイムラインを実装
- `GET /api/v1/requirements/{requirement_id}/history` を追加し、Requirement更新、承認、レビュー依頼、レビュー解決を時系列で取得できるようにした
- 差分履歴は `RequirementRevisionService` で安全な短いプレビューに限定し、secret、個人情報、法務・金融情報などの検知時は本文を保存しないようにした
- `RequirementHistoryQuery` を追加し、AuditLogとReviewの統合をControllerから分離した
- Requirement Workspaceに `Requirement履歴タイムライン` を追加し、承認差し戻し、レビュー依頼、レビュー解決、下流Draft stale化を同じ流れで確認できるようにした
- Review状態遷移の厳密監査はISSUE-054 / GitHub #73として分離
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec rspec spec/services/requirement_revision_service_spec.rb spec/requests/api/v1/requirements_spec.rb`: 20 examples, 0 failures
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: 成功
- `npm run display:check`: 成功
- `npm run frontend:build`: 成功
- `npm run frontend:e2e -- --grep "creates a project, saves a Discord log, generates minutes, and requests review"`: 1 passed
- 判定: ISSUE-050のMVP要件は完了。PR CI通過後にGitHub #67をクローズし、Issue #3はISSUE-052、ISSUE-053、ISSUE-054の完了状況を見て最終クローズ判断する

未完了:

- ISSUE-052: Requirement生成OpenAI provider比較
- ISSUE-053: Requirement Workspaceの未決事項、リスク、差分強調UX
- ISSUE-054: Review状態遷移の厳密監査

## 次アクション

- ISSUE-052は既存provider実装を読み、OpenAI provider比較の設計レビューから始める
- ISSUE-053はRequirement履歴タイムラインと衝突しない範囲で画面改善を進める
- ISSUE-054はReview状態遷移イベントのDB/API設計レビューから始める
