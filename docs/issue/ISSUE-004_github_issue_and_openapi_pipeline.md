# ISSUE-004: 要件からGitHub IssueとOpenAPIドラフトを生成する

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/4

登録日: 2026-06-30
同期方法: `scripts/sync-github-issues.rb --apply`

## 背景

AI実装エージェントの成功率は、IssueとAPI仕様の品質に大きく依存する。議事録からIssueだけでなくOpenAPIまで落とし込むことで、実装前の曖昧さを減らす。

## 目的

承認済み要件から、GitHub IssueドラフトとOpenAPIドラフトを生成し、レビュー後にGitHubへ登録する。

## 完了条件

- Issueタイトル、本文、完了条件、ラベル案を生成できる
- OpenAPI path、method、request、response、errorを生成できる
- APIレビューを保存できる
- GitHub Issue作成後にIssue番号とローカル台帳が紐づく
- レビュー未通過なら実装へ進めない

## スコープ

- GitHub Issueドラフト
- GitHub Issue作成
- OpenAPIドラフト
- APIレビュー

## 非スコープ

- Pull Request自動作成
- 自動マージ
- Jira/Linear同期

## 関連レビュー

- `docs/review/20260629_winning_strategy_review.md`
- `docs/review/20260629_mvp_review.md`
- `docs/review/20260629_requirements_review.md`
- `docs/review/20260630_api_design_review.md`
- `docs/review/20260630_db_design_review.md`
- `docs/review/20260630_issue_openapi_draft_generation_review.md`
- `docs/review/20260701_openapi_validation_api_review.md`
- `docs/review/20260701_openapi_validation_review_gate_review.md`
- `docs/review/20260701_github_issue_publish_api_review.md`
- `docs/review/20260701_github_app_provider_review.md`
- `docs/review/20260701_github_integration_account_api_review.md`
- `docs/review/20260701_github_callback_verification_review.md`
- `docs/review/20260701_github_connection_state_nonce_review.md`
- `docs/review/20260701_github_issue_publish_reconciliation_adr_review.md`
- `docs/review/20260701_github_issue_publish_attempts_review.md`
- `docs/review/20260701_github_issue_publish_reconciler_review.md`
- `docs/review/20260701_github_reconciliation_api_review.md`
- `docs/review/20260701_github_manual_reconciliation_review.md`
- `docs/review/20260701_github_reconciliation_frontend_review.md`
- `docs/review/20260701_github_reconciliation_attempt_summary_api_review.md`
- `docs/review/20260701_github_reconciliation_attempt_summary_implementation_review.md`
- `docs/review/20260701_github_reconciliation_pending_ui_e2e_review.md`
- `docs/review/20260701_github_reconciliation_link_issue_e2e_review.md`

## レビュー結果

差別化に直結するP0。2026-06-30時点で、承認済みRequirementからIssue DraftとOpenAPI Draftを生成、編集、保存できるMVP実装を追加した。2026-07-01時点で、OpenAPI Draftのvalidation API、Frontend validation導線、validation結果とReview blockerの連動、GitHub Issue publish API/gate、GitHub App provider、`integration_accounts`、GitHub connection API、callback時のGitHub API照合、state nonce/replay防止、GitHub Issue publish reconciliation ADR、`github_issue_publish_attempts` によるpublish attempt監査、marker検索reconciler、reconciliation Review blocker、手動reconciliation API、Frontend管理導線、pending reconciliation attempt summaryを追加した。

良かった点:

- Requirement承認後のみIssue/OpenAPI Draft生成を許可するレビューゲートを実装した。
- 生成処理をJob、AuditLog、Draftモデルに接続し、監査できる形にした。
- FrontendからIssue DraftとOpenAPI Draftを生成、編集、保存できる導線を追加した。
- OpenAPI Draftを保存後にvalidationし、`valid` / `invalid`、errors、warningsをFrontendで確認できるようにした。
- validation処理をJob、AuditLog、Draft status、`validation_errors` に接続した。
- validation失敗時にOpenAPI Draft対象の `action_required` Review blockerを作成し、再validation成功時に `resolved` へ更新するようにした。
- Issue Draft承認、OpenAPI valid、OpenAPI blocker解決をpublish gateとして実装した。
- GitHub未接続時は424で安全に停止し、Job、AuditLog、`publish_failed` を残すようにした。
- GitHub App providerを追加し、installation access tokenを都度発行してGitHub Issueを作成する実装経路を用意した。
- `integration_accounts` でProjectとGitHub App installation/repository/権限の接続状態を管理できるようにした。
- installation access tokenをDBへ保存せず、Idempotency-Keyの生値もGitHub Issue本文へ出さないようにした。
- GitHub connection start/callback/disconnect APIを追加し、署名付きstateでproject/repositoryを検証するようにした。
- callback時にGitHub APIでinstallation、Issues write権限、対象repository accessを照合するようにした。
- callback本文の `granted_permissions` を信頼せず、GitHub APIから取得したpermissions/accountを保存するようにした。
- GitHub connection stateのnonce digestをDB保存し、署名検証後のcallback処理で一度だけ消費してreplayを拒否するようにした。
- stateの生値はDB保存しないようにした。
- ADR-0006で、GitHub Issue作成成功後のDB保存失敗やtimeout時に二重Issueを作らないreconciliation方針を決めた。
- ADR-0006で、marker検索、publish attempt table、0件/複数件時のReview blocker方針を定義した。
- `github_issue_publish_attempts` table/modelを追加し、publish開始、GitHub作成成功、ローカル保存成功、provider失敗、reconciliation requiredを監査できるようにした。
- GitHub作成後のローカル保存失敗を `github_publish_reconciliation_required` として止め、attemptにGitHub Issue情報を残すようにした。
- GitHub作成後にattemptのGitHub作成記録が失敗した場合も、reconciliation requiredとして停止するようにした。
- `Idempotency-Key` の生値をローカルDBへ保存せず、SHA-256 digest保存へ変更した。
- 同じidempotency digestで失敗再試行しても、attempt履歴を複数残せるようにした。
- GitHub App installation tokenでAI PM markerを検索する `MarkerSearchClient` を追加した。
- markerが1件だけ見つかった場合にIssue Draftとattemptを自動reconcileできるようにした。
- markerが0件/複数件の場合は `GitHub Publish Reconciler` Review blockerを作成し、publish gateでも再publishを止めるようにした。
- reconciliation結果をAuditLogへ保存するようにした。
- `POST /issue-drafts/{issue_draft_id}/reconcile-github-publish` を追加し、reconcilerをAPIから実行できるようにした。
- `github_reconciliation` Jobを追加し、reconciler APIの成功/失敗を追跡できるようにした。
- OpenAPIとFrontend生成型をreconciliation APIへ同期した。
- `POST /issue-drafts/{issue_draft_id}/resolve-github-reconciliation` を追加し、手動紐付けとcontrolled retryを実行できるようにした。
- 手動紐付けではGitHub Issue URLがProject repositoryとissue numberに一致することを検証するようにした。
- controlled retryではattemptを `retry_approved`、Issue Draftを `approved` に戻し、Review blockerを解決するようにした。
- publish成功レスポンスと `issue_draft.github_published` AuditLogへ `attempt_id` を追加した。
- Frontendからmarker検索、既存GitHub Issue手動リンク、controlled retry承認を実行できる復旧導線を追加した。
- Publish失敗時にGitHub issue number、GitHub issue URL、resolution noteを入力して監査可能な復旧判断を残せるようにした。
- `IssueDraft` responseへ `github_reconciliation.pending` を追加し、pending attemptがある失敗だけ復旧操作を表示できるようにした。
- pending attemptがないGitHub未接続エラーでは、Frontendにmarker検索/手動リンク/controlled retry操作を表示しないようにした。
- pending summaryではidempotency digestや内部例外を返さず、attempt id、status、safe error、GitHub Issue番号/URLに限定した。
- pending trueの復旧UIをmock E2Eで検証し、controlled retryのpayloadと承認後状態遷移を確認した。
- `既存Issueに紐付け` のpayloadと成功後状態遷移をmock E2Eで検証した。
- Request spec、service spec、Playwright E2EにIssue/OpenAPI Draftの主要導線を追加した。

改善点:

- GitHub App providerとconnection APIは実装済みだが、live credentialでのconnect/publish検証は未実施。
- callback失敗時にstateを消費済みにする現在仕様は安全寄りだが、ユーザー再試行性のADRが未作成。
- 期限切れ `github_connection_states` のcleanup jobは未実装。
- marker検索reconciler、手動リンク、controlled retryのFrontend管理導線は実装済みだが、実GitHub App credentialでのlive smokeは未実施。
- `Link Issue` の入力エラー表示E2Eは未追加。
- marker検索結果が0件/複数件だった場合の候補Issue一覧表示は未実装。
- controlled retryのcooldown、retry count、承認者表示、理由テンプレートは未実装。
- 実GitHub App credentialでのconnect/publish/reconcile smokeは未実施。
- GitHub searchのindexing delay、rate limit、retry/backoff方針は未実装。
- `issue_drafts.publish_idempotency_key` はdigest保存へ変更済みだが、名称と保存値がずれているため将来renameが必要。
- deterministic providerはMVP用途であり、AI provider、差分再生成、レビューコメント反映が未接続。
- validationはRails内の軽量構文/構造チェックであり、Redocly級の完全なOpenAPI lintではない。
- Draftの承認状態は保存できるが、validation blockerとGitHub公開/実装開始の最終停止条件は未接続。
- `validation_errors` は `string[]` 保存、validateレスポンスは `ValidationIssue[]` で粒度差がある。
- GitHub webhook署名検証、installation revoked、permissions changed同期が未実装。

レビュー結果: MVPとしては前進。fake provider、GitHub App provider spec、connection API spec、callback verification spec、state nonce spec、publish attempt spec、marker search/reconciler spec、reconciliation API request spec、manual reconciliation specではGitHub Issue番号とローカル台帳の紐付け経路、外部side effect監査、reconciliation required停止、exact match復旧、0件/複数件時のReview blocker、APIからのreconciler実行、手動紐付け、controlled retryまで確認済み。ADR-0006でpublish reconciliation方針も実装へ進み、Frontend管理導線からmarker検索、手動リンク、controlled retry承認を実行できるようになった。pending reconciliation attempt summaryにより、未接続エラーとreconciliation requiredもUIで区別できる。pending trueの復旧UI、controlled retry payload、Link Issue payload、手動リンク成功後のUI遷移もE2Eで検証済み。ただし実GitHub App credentialによるconnect/publish/reconcile smoke、候補Issue選択UX、retry制御が未完了のため、ISSUE-004はクローズ不可。

検証結果:

- `bundle exec rspec spec/services/issue_draft_generation_service_spec.rb spec/requests/api/v1/issue_drafts_spec.rb spec/services/open_api_draft_generation_service_spec.rb spec/requests/api/v1/open_api_drafts_spec.rb`: 12 examples, 0 failures
- `bundle exec rspec`: 70 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities
- `bundle exec rspec spec/services/open_api_draft_validation_service_spec.rb spec/requests/api/v1/open_api_drafts_spec.rb`: 10 examples, 0 failures
- `bundle exec rspec spec/services/open_api_draft_review_gate_service_spec.rb spec/services/open_api_draft_validation_service_spec.rb spec/requests/api/v1/open_api_drafts_spec.rb`: 15 examples, 0 failures
- `bundle exec rspec spec/services/issue_draft_publish_gate_spec.rb spec/services/github_issue_publish_service_spec.rb spec/requests/api/v1/issue_drafts_spec.rb`: 16 examples, 0 failures
- `bundle exec rails db:migrate`: success
- `RAILS_ENV=test bundle exec rails db:migrate`: success
- `bundle exec rspec spec/models/integration_account_spec.rb spec/services/github_issue_publish/github_app_provider_spec.rb spec/services/github_issue_publish_service_spec.rb spec/requests/api/v1/issue_drafts_spec.rb`: 20 examples, 0 failures
- `bundle exec rspec`: 78 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities
- `bundle exec rspec spec/requests/api/v1/integration_accounts_spec.rb spec/services/github_issue_publish/github_app_provider_spec.rb spec/models/integration_account_spec.rb`: 14 examples, 0 failures
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `bundle exec rspec`: 84 examples, 0 failures
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities
- `bundle exec rspec spec/requests/api/v1/integration_accounts_spec.rb spec/services/github_integration/installation_verifier_spec.rb spec/services/github_issue_publish/github_app_provider_spec.rb spec/models/integration_account_spec.rb`: 20 examples, 0 failures
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `bundle exec rspec`: 90 examples, 0 failures
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities
- `bundle exec rails db:migrate`: success
- `RAILS_ENV=test bundle exec rails db:migrate`: success
- `bundle exec rspec spec/models/github_connection_state_spec.rb spec/services/github_integration/connection_state_spec.rb spec/requests/api/v1/integration_accounts_spec.rb spec/services/github_integration/installation_verifier_spec.rb`: 19 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `bundle exec rspec`: 97 examples, 0 failures
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities
- `docs/decisions/ADR-0006_github_issue_publish_reconciliation.md`: 追加
- `docs/review/20260701_github_issue_publish_reconciliation_adr_review.md`: 追加
- `bundle exec rails db:migrate:redo VERSION=20260701114500`: success
- `RAILS_ENV=test bundle exec rails db:migrate:redo VERSION=20260701114500`: success
- `bundle exec rspec spec/models/github_issue_publish_attempt_spec.rb spec/services/github_issue_publish_service_spec.rb spec/requests/api/v1/issue_drafts_spec.rb`: 18 examples, 0 failures
- `bundle exec rspec`: 103 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities
- `bundle exec rspec spec/services/issue_draft_publish_gate_spec.rb spec/services/github_issue_publish/marker_search_client_spec.rb spec/services/github_issue_publish/reconciliation_service_spec.rb spec/services/github_issue_publish_service_spec.rb spec/requests/api/v1/issue_drafts_spec.rb`: 26 examples, 0 failures
- `bundle exec rspec`: 110 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities
- `bundle exec rspec spec/requests/api/v1/issue_drafts_spec.rb spec/services/github_issue_publish/reconciliation_service_spec.rb spec/services/github_issue_publish/marker_search_client_spec.rb spec/services/issue_draft_publish_gate_spec.rb`: 24 examples, 0 failures
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `bundle exec rspec`: 114 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities
- `bundle exec rspec spec/services/github_issue_publish/manual_reconciliation_service_spec.rb spec/requests/api/v1/issue_drafts_spec.rb spec/services/issue_draft_publish_gate_spec.rb`: 26 examples, 0 failures
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `bundle exec rspec spec/services/github_issue_publish/manual_reconciliation_service_spec.rb spec/services/github_issue_publish_service_spec.rb spec/requests/api/v1/issue_drafts_spec.rb spec/services/issue_draft_publish_gate_spec.rb`: 32 examples, 0 failures
- `bundle exec rspec`: 122 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `bundle exec rspec spec/requests/api/v1/issue_drafts_spec.rb`: 18 examples, 0 failures
- `bundle exec rspec`: 123 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm run frontend:e2e`: 7 passed
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 8 passed
- `npm run frontend:build`: success

## 次アクション

- 実GitHub App credentialを使ったstaging/live connect + publish + reconcile smokeを実施する
- `Link Issue` の入力エラー表示E2Eを追加する
- marker検索候補一覧と手動選択UIを追加する
- controlled retryのcooldown、retry count、承認者表示、理由テンプレートを追加する
- GitHub search retry/backoff方針をADR化する
- `publish_idempotency_key` のdigest名称renameをADRまたはmigrationで検討する
- 期限切れ `github_connection_states` cleanup jobを追加する
- callback失敗時のstate消費方針をADR化する
- Backend runtime validatorを強化し、Redocly CLIまたは専用OpenAPI parser採用をADR化する
- GitHub webhook署名検証、installation revoked、permissions changed同期を実装する
- Issue同期の冪等性方針をADR化する
- AI provider接続時のプロンプト、スキーマ検証、失敗時リカバリを `docs/ai/` に追加する
