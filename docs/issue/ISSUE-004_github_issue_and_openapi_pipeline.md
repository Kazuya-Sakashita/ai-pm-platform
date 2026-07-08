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
- `docs/review/20260701_github_reconciliation_link_issue_validation_e2e_review.md`
- `docs/review/20260701_github_reconciliation_link_issue_api_error_e2e_review.md`
- `docs/review/20260702_github_reconciliation_candidate_selection_review.md`
- `docs/review/20260702_github_reconciliation_candidate_metadata_review.md`
- `docs/review/20260702_github_reconciliation_candidate_ranking_adr_review.md`
- `docs/review/20260702_github_reconciliation_candidate_a11y_review.md`
- `docs/review/20260702_github_reconciliation_candidate_keyboard_e2e_review.md`
- `docs/review/20260702_github_reconciliation_candidate_long_text_layout_review.md`
- `docs/review/20260702_github_reconciliation_search_metadata_review.md`
- `docs/review/20260702_github_reconciliation_ten_candidate_ui_review.md`
- `docs/review/20260702_github_search_retry_backoff_adr_review.md`
- `docs/review/20260702_github_search_rate_limit_metadata_review.md`
- `docs/review/20260702_github_reconciliation_cooldown_retry_review.md`
- `docs/review/20260703_github_reconciliation_async_retry_job_review.md`
- `docs/review/20260703_production_job_queue_adr_review.md`
- `docs/review/20260703_solid_queue_production_job_backend_implementation_review.md`
- `docs/review/20260704_github_reconciliation_controlled_retry_approval_review.md`
- `docs/review/20260704_github_reconciliation_link_issue_number_mismatch_e2e_review.md`
- `docs/review/20260704_github_app_live_smoke_runbook_review.md`
- `docs/review/20260704_github_reconciliation_history_ui_review.md`
- `docs/review/20260704_github_connection_state_cleanup_job_review.md`
- `docs/review/20260704_github_callback_state_consumption_adr_review.md`
- `docs/review/20260704_github_callback_failure_audit_reconnect_ui_review.md`
- `docs/review/20260704_github_callback_result_page_review.md`
- `docs/review/20260704_solid_queue_staging_worker_smoke_runbook_review.md`
- `docs/review/20260704_queue_health_monitoring_implementation_review.md`
- `docs/review/20260704_failed_job_safe_visibility_implementation_review.md`
- `docs/review/20260707_github_webhook_signature_installation_sync_implementation_review.md`
- `docs/review/20260708_github_app_live_smoke_bigint_fix_review.md`
- `docs/review/20260708_github_callback_full_smoke_review.md`
- `docs/review/20260708_github_callback_state_log_filter_review.md`
- `docs/review/20260708_github_webhook_live_smoke_readiness_review.md`
- `docs/review/20260708_solid_queue_worker_smoke_readiness_review.md`

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
- controlled retryでは承認者と理由テンプレートを必須化し、AuditLog、attempt detail、Review resolution noteへ監査情報を残すようにした。
- `resolve-github-reconciliation` responseへcontrolled retryの承認者と理由テンプレートを返すようにした。
- publish成功レスポンスと `issue_draft.github_published` AuditLogへ `attempt_id` を追加した。
- Frontendからmarker検索、既存GitHub Issue手動リンク、controlled retry承認を実行できる復旧導線を追加した。
- Publish失敗時にGitHub issue number、GitHub issue URL、resolution noteを入力して監査可能な復旧判断を残せるようにした。
- `IssueDraft` responseへ `github_reconciliation.pending` を追加し、pending attemptがある失敗だけ復旧操作を表示できるようにした。
- pending attemptがないGitHub未接続エラーでは、Frontendにmarker検索/手動リンク/controlled retry操作を表示しないようにした。
- pending summaryではidempotency digestや内部例外を返さず、attempt id、status、safe error、GitHub Issue番号/URLに限定した。
- pending trueの復旧UIをmock E2Eで検証し、controlled retryのpayloadと承認後状態遷移を確認した。
- `既存Issueに紐付け` のpayloadと成功後状態遷移をmock E2Eで検証した。
- `既存Issueに紐付け` のGitHub Issue番号/URL入力エラーをmock E2Eで検証した。
- `既存Issueに紐付け` のAPI 422失敗と別repository URL拒否をmock E2Eで検証した。
- `既存Issueに紐付け` の非GitHub URL、http URL、別repository URLを送信前に拒否するE2Eを追加した。
- `既存Issueに紐付け` のURL/番号不一致を送信前に拒否するE2Eを追加し、Backend request specでも同じ不一致を422で拒否することを確認した。
- 別repository URL拒否時のsafe detailをFrontendで日本語表示するようにした。
- marker検索で複数候補が見つかった場合に、安全な候補情報をAPIレスポンスへ返すようにした。
- Frontendでmarker検索候補一覧を表示し、候補選択から手動リンクフォームへ反映できるようにした。
- marker検索、候補選択、既存Issueへの手動リンク成功までをmock E2Eで検証した。
- marker検索候補へtitle、state、updated_at、scoreを追加し、候補選択時の判断材料を増やした。
- 候補メタデータをMarkerSearchClient spec、request spec、Playwright E2Eで検証した。
- ADR-0007で、候補score、GitHub best match順、最大10件表示、closed Issue表示、人間レビュー停止方針を定義した。
- Candidate selection UIに選択中表示、`aria-pressed`、`aria-current` を追加し、選択状態を視覚とDOMの両方で表現した。
- 選択状態の視覚表示とa11y属性をPlaywright E2Eで検証した。
- Candidate selectionをキーボードフォーカス移動とEnterで実行できることをPlaywright E2Eで検証した。
- 長いGitHub Issue title/URLを含む候補一覧が狭幅viewportで水平overflowしないことをPlaywright E2Eで検証した。
- GitHub Searchの `total_count`、`incomplete_results`、10件上限超過有無をreconciliation APIとUIへ追加した。
- 候補ヘッダーに検索総数、上位10件のみ表示、検索未完了を表示できるようにした。
- 検索メタデータをMarkerSearchClient spec、ReconciliationService spec、request spec、Playwright E2Eで検証した。
- 10件候補時に検索メタデータ、全候補表示、最後の候補選択、水平overflowなしをPlaywright E2Eで検証した。
- ADR-0008でGitHub Search retry/backoff、indexing delay、rate limit、`incomplete_results` の安全方針を定義した。
- `incomplete_results=true` の場合は候補が1件でも自動reconcileせずReview blockerへ止めるようにした。
- GitHub marker search失敗時に `retry-after`、`x-ratelimit-remaining`、`x-ratelimit-reset`、`x-ratelimit-resource` をsafe metadataとしてAPI error detailsとAuditLogへ反映できるようにした。
- GitHub marker search rate limit時は `github_issue_marker_search_rate_limited` と429で返し、Frontend表示文言を日本語化した。
- GitHub reconciliation attemptにretry countとnext retry atを追加し、0件/不完全検索/rate limit時にcooldownを設定できるようにした。
- cooldown中はmarker search APIとcontrolled retry承認を停止し、Frontendでもマーカー検索と再試行承認ボタンをdisabledにした。
- Frontendに再検索回数と次の再検索時刻を表示し、cooldown UIをPlaywright E2Eで検証した。
- cooldown設定時に監査用の `github_reconciliation` Jobをqueued作成し、ActiveJobでcooldown後のmarker searchを自動実行するようにした。
- 非同期retry Jobの成功、失敗、cooldown継続による再予約、attempt解決済み時のcancelをRSpecで検証した。
- ADR-0010で、production向け永続Job基盤としてMVP-to-betaではSolid Queueを採用する方針を決めた。
- ADR-0010で、Product用 `jobs` table とqueue backendの責務分離、worker process、queue health、failed job監視、graceful shutdownを実装条件にした。
- ISSUE-023でSolid Queueを導入し、production adapter、queue database設定、`bin/jobs`、queue schema、運用runbookを追加した。
- `GithubIssuePublish::ReconciliationRetryJob` を `github_reconciliation` queueへ移し、config specでqueue設定を検証した。
- Request spec、service spec、Playwright E2EにIssue/OpenAPI Draftの主要導線を追加した。
- Request spec、service spec、Playwright E2Eでcontrolled retry承認者/理由テンプレートとLink Issue URL送信前検証を確認した。
- 実GitHub App credentialでconnect/publish/reconcile smokeを行うためのrunbookを `docs/release/20260704_github_app_live_smoke_runbook.md` として追加した。
- Issue Draft APIへ直近5件の `github_reconciliation_history` を追加し、attempt status、safe error、GitHub Issue URL、retry承認メタデータを安全に表示できるようにした。
- GitHub照合履歴の整形を `IssueDraftReconciliationHistorySerializer` へ分離し、`IssueDraft#api_json` は呼び出し口に留め、ControllerとModel本体の肥大化を避けた。
- Frontendに `照合履歴` パネルを追加し、pending、retry承認、GitHub作成、ローカル保存、照合済みの流れを日本語ラベルで追跡できるようにした。
- 期限切れ `github_connection_states` のcleanup jobを追加し、24時間retention後に古いstateを削除できるようにした。
- cleanup条件を `GithubConnectionState` の短いscope/クラスメソッドに置き、定期実行は `GithubIntegration::ConnectionStateCleanupJob` とSolid Queue recurring scheduleへ分離した。
- `GithubIntegration::StateError` を独立autoload定数へ分離し、model spec単体実行でも安定するようにした。
- ADR-0011で、GitHub callback失敗時もconnection stateを一回限りで消費し、再試行は新しいconnection startから行う方針を明文化した。
- GitHub installation verification失敗後に同じstateを再送しても、GitHub API照合前にreplay拒否されることをrequest specで固定した。
- GitHub callbackでinstallation verificationに失敗した場合、safe metadataだけを `github.connect.failed` AuditLogとして保存できるようにした。
- FrontendにGitHub連携状態パネルを追加し、未接続または公開失敗時にワークスペース内からGitHub連携を開始/やり直せる導線を追加した。
- `/github/callback` result pageを追加し、GitHub App setup URLから戻ったユーザーに接続成功/失敗を日本語で表示できるようにした。
- callback result pageはraw stateを画面へ表示せず、Backend callback APIへ1回だけPOSTすることをPlaywright E2Eで確認した。
- Solid Queue staging/production worker smoke runbookを追加し、worker heartbeat、recurring task、cleanup job、failed job、queue latencyの確認手順を明文化した。
- `GET /operations/queue-health` とFrontend運用監視パネルを追加し、worker heartbeat、queue latency、failed execution、recurring task、Product jobs summaryをread-onlyで確認できるようにした。

改善点:

- GitHub App providerとconnection APIは実装済みだが、live credentialでのconnect/publish検証は未実施。
- callback失敗時にstateを消費済みにする現在仕様はADR-0011で方針決定済み。callback failure AuditLog、ワークスペース内のFrontend再接続導線、GitHub callback result pageは実装済み。ただし実GitHub App setup URLからのlive callback payload確認は未実施。
- 期限切れ `github_connection_states` のcleanup jobは実装済み。ただし、staging/production worker上でrecurring scheduleが発火するsmokeは未実施。
- marker検索reconciler、手動リンク、controlled retryのFrontend管理導線は実装済みだが、実GitHub App credentialでのlive smokeは未実施。
- `Link Issue` のinline error、非GitHub URL、http URL、別repository URL、URL/番号不一致のE2Eは実装済み。
- ADR-0007でmarker検索候補のscore解釈、並び順、最大表示件数は定義済み。選択済み状態、a11y属性、候補ボタンのキーボード選択E2E、long title/URLの狭幅overflow検証、検索総数/不完全結果/10件超過表示、10件候補時の操作性E2Eは実装済みだが、スクリーンリーダー確認は未実施。
- 実GitHub App credentialでのconnect/publish/reconcile smokeは未実施。
- controlled retryのcooldown、retry count、cooldown後の非同期retry job、承認者入力、理由テンプレート、直近の照合履歴UIは実装済み。ただし、pagination、filter、監査ログ全文検索、認証ユーザーへの紐付けは未実装。
- live smoke runbookは追加済みだが、実credentialでの実行結果レビューは未作成。
- GitHub searchのindexing delay、rate limit、retry/backoff方針はADR-0008で定義済みで、response header parsing、retry metadata、cooldown UI、ActiveJobによる非同期retry jobは実装済み。production向け永続Job基盤はADR-0010でSolid Queue採用方針を決め、ISSUE-023で実装済み。production mode local worker smokeも別queue DBで確認済み。Solid Queue staging/production worker smoke runbook、Queue health監視MVP、failed job safe visibilityも追加済み。ただし、実staging/productionでのworker smoke証跡、通知/SLO、failed job再実行/破棄のoperator権限と監査UIは未実装。
- `issue_drafts.publish_idempotency_key` はdigest保存へ変更済みだが、名称と保存値がずれているため将来renameが必要。
- deterministic providerはMVP用途であり、AI provider、差分再生成、レビューコメント反映が未接続。
- validationはRails内の軽量構文/構造チェックであり、Redocly級の完全なOpenAPI lintではない。
- Draftの承認状態は保存できるが、validation blockerとGitHub公開/実装開始の最終停止条件は未接続。
- `validation_errors` は `string[]` 保存、validateレスポンスは `ValidationIssue[]` で粒度差がある。
- GitHub webhook署名検証、installation revoked、permissions changed同期が未実装。

レビュー結果: MVPとしては前進。fake provider、GitHub App provider spec、connection API spec、callback verification spec、state nonce spec、publish attempt spec、marker search/reconciler spec、reconciliation API request spec、manual reconciliation specではGitHub Issue番号とローカル台帳の紐付け経路、外部side effect監査、reconciliation required停止、exact match復旧、0件/複数件時のReview blocker、APIからのreconciler実行、手動紐付け、controlled retryまで確認済み。ADR-0006でpublish reconciliation方針も実装へ進み、Frontend管理導線からmarker検索、候補一覧表示、候補選択、手動リンク、controlled retry承認を実行できるようになった。pending reconciliation attempt summaryにより、未接続エラーとreconciliation requiredもUIで区別できる。pending trueの復旧UI、controlled retry payload、承認者/理由テンプレート、Link Issue payload、手動リンク成功後のUI遷移、Link Issue入力validation、非GitHub/http/別repository URLの送信前拒否、Backend validation失敗時のAPI 422表示、候補選択から手動リンク成功、候補メタデータ表示、選択状態とa11y属性、キーボード選択、長文候補の狭幅overflow、検索総数/不完全結果/10件超過表示、10件候補時の操作性までをE2Eで検証済み。ADR-0007で候補score、並び順、最大10件表示、closed Issue表示、人間レビュー停止方針も定義済み。ADR-0008でGitHub Search retry/backoff、indexing delay、rate limit、`incomplete_results` の安全方針を定義し、不完全検索では候補が1件でも自動reconcileしない実装へ更新済み。GitHub Search rate limit時のresponse headerをsafe metadataとしてAPI error detailsとAuditLogへ残せるようになった。retry count、next retry at、cooldown UIにより、cooldown中のmarker searchとcontrolled retry承認も停止できる。2026-07-03にActiveJobによるcooldown後の非同期marker search retryを追加し、queued Job監査、成功、失敗、cancel、rescheduleを検証した。ADR-0010でproduction向け永続Job基盤としてSolid Queueを採用し、ISSUE-023でGem、production adapter、queue database設定、worker executable、queue schema、runbookまで実装した。production mode local worker smokeも別queue DBで確認済み。2026-07-04にQueue health監視MVPとfailed job safe visibilityも追加済み。ただし実GitHub App credentialによるconnect/publish/reconcile smoke、スクリーンリーダー確認、認証ユーザーへの承認者紐付け、実staging/production worker smoke、通知/SLO、failed job再実行/破棄のoperator権限と監査UIが未完了のため、ISSUE-004はクローズ不可。

2026-07-04追記: live smoke runbookとGitHub照合履歴API/UIを追加し、pending中の1件だけでなく直近のattemptとcontrolled retry承認履歴を安全に追跡できるようにした。履歴レスポンスは `idempotency_digest`、raw exception、free-form resolution noteを返さず、attempt id、status、safe error、GitHub Issue URL、retry承認メタデータに限定している。さらに期限切れ `github_connection_states` cleanup jobを追加し、24時間retention後に古いstateをSolid Queue recurringで削除できるようにした。ADR-0011でcallback失敗時のstate消費方針を確定し、GitHub verification失敗後のreplay拒否をrequest specで固定した。callback failure AuditLog、ワークスペース内の再接続導線、GitHub callback result pageも追加した。Solid Queue staging/production worker smoke runbookも追加し、実行証跡テンプレートを整えた。Queue health監視MVPとfailed job safe visibilityも追加し、read-onlyでworker heartbeat、queue latency、failed execution、recurring task、直近失敗ジョブのsafe summaryを確認できるようにした。ただし実GitHub App credentialによるconnect/publish/reconcile smoke、スクリーンリーダー確認、認証ユーザーへの承認者紐付け、実staging/production worker smoke、通知/SLO、failed job再実行/破棄のoperator権限と監査UIが未完了のため、ISSUE-004はクローズ不可。

2026-07-07追記: ISSUE-067 / GitHub Issue #106として、GitHub webhook署名検証、delivery digest冪等性、installation deleted / repository removed / permission downgrade同期、safe AuditLog、OpenAPI同期を追加した。これにより「GitHub webhook署名検証、installation revoked、permissions changed同期」の実装残件は解消した。ただし実GitHub App credentialでのwebhook live delivery smokeは未実施のため、ISSUE-004のrelease gateとして継続する。

2026-07-08追記: 実GitHub App credentialでlive smokeを実施した。GitHub App JWT、installation、repository access、`issues: write` / `metadata: read` を確認し、GitHub Issue #115 と #116 を作成した。初回publishではGitHub Issue API ID `4832594358` が32bit integer上限を超え、ローカル保存が失敗したため、`issue_drafts.github_issue_api_id` と `github_issue_publish_attempts.github_issue_api_id` を `bigint` へ変更し、OpenAPIの `github_issue_api_id` に `format: int64` を追加した。初回失敗分のIssue #115はmarker searchで復旧し、attemptを `reconciled` にした。bigint修正後のIssue #116は通常publishで `local_saved` まで成功し、marker searchも `total_count=1`、`match_count=1`、`incomplete_results=false` で確認した。controlled retry安全シナリオも `retry_approved` まで確認済み。Frontend callback full smoke、GitHub webhook live delivery smoke、staging/production worker smokeは未実施のため、ISSUE-004は継続OPENとする。

2026-07-08追記: Frontend callback full smokeを実施した。`POST /api/v1/projects/{project_id}/integrations/github/connect` でone-time stateを発行し、`/github/callback` 画面から実backend callback APIへPOSTされることを確認した。GitHub App installation `145067753` のverification後、`integration_accounts` は `connected`、repositoryは `Kazuya-Sakashita/ai-pm-platform`、issues write permissionは `true` になった。画面には「接続が完了しました」「GitHub連携が完了しました。」、接続済みrepository/accountが表示され、state生値は表示されなかった。初回はbackendが `.env` 未読込で `github_app_not_configured` になったが、safe AuditLogとして `github.connect.failed` が保存され、`.env` 読込付きで再起動後に成功した。GitHub webhook live delivery smoke、staging/production worker smokeは未実施のため、ISSUE-004は継続OPENとする。

2026-07-08追記: Frontend callback full smokeのログ確認中に、Rails development logの `Parameters` にcallback `state` 生値が出ることを検出した。`state` はone-timeでもcallback replay防止の信頼境界に関わるため、Rails parameter filterへ `state` を追加し、`ActiveSupport::ParameterFilter` specで `[FILTERED]` になることを固定した。GitHub webhook live delivery smoke、staging/production worker smokeは未実施のため、ISSUE-004は継続OPENとする。

2026-07-08追記: GitHub webhook live delivery smokeへ進む前段として、secretやraw payloadを出力しない `scripts/github-webhook-live-smoke.rb` を追加した。GitHub App管理APIでwebhook設定と直近deliveryを確認し、delivery id生値ではなくdigestのみを証跡化する。実行結果ではApp IDとprivate keyは設定済みだったが、runtimeの `GITHUB_WEBHOOK_SECRET` が未設定、GitHub App webhook URLがplaceholder、直近deliveryが502であり、safe failureは `github_webhook_secret_missing`、`github_webhook_url_placeholder`、`github_webhook_recent_delivery_failed` だった。GitHub webhook live delivery smokeは未合格であり、Webhook URLとsecret設定後に再実行する。

2026-07-08追記: staging/production worker smokeへ進む前段として、read-onlyの `scripts/solid-queue-worker-smoke-readiness.rb` を追加した。Rails runnerからActiveJob adapter、Solid Queue table、worker heartbeat、recurring task、queue latency、failed execution count、Queue health release gate、secret presenceをsafe JSONで確認できる。local実行ではSolid Queue table未準備のため `solid_queue_tables_unavailable` で安全失敗した。実staging/production-equivalent環境で `safe_failures` が空の証跡を取得するまで、worker smokeは未完了とする。

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
- `bundle exec rspec spec/services/github_issue_publish/manual_reconciliation_service_spec.rb spec/requests/api/v1/issue_drafts_spec.rb`: 29 examples, 0 failures
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 14 passed
- `bundle exec rspec`: 123 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm run frontend:e2e`: 7 passed
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 8 passed
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 9 passed
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 10 passed
- `npm run frontend:build`: success
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run frontend:e2e`: 11 passed
- `npm run frontend:build`: success
- `bundle exec rspec spec/requests/api/v1/issue_drafts_spec.rb`: 19 examples, 0 failures
- `bundle exec rspec`: 124 examples, 0 failures
- `git diff --check`: success
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm audit --omit=dev`: 0 vulnerabilities
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 11 passed
- `bundle exec rspec spec/services/github_issue_publish/marker_search_client_spec.rb spec/requests/api/v1/issue_drafts_spec.rb`: 21 examples, 0 failures
- `docs/decisions/ADR-0007_github_reconciliation_candidate_ranking.md`: 追加
- `docs/review/20260702_github_reconciliation_candidate_ranking_adr_review.md`: 追加
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 11 passed
- `npm run frontend:e2e`: 11 passed（keyboard candidate selection）
- `npm run frontend:e2e`: 12 passed（long title/URL narrow layout）
- `npm run frontend:build`: success
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 12 passed
- `bundle exec rspec spec/services/github_issue_publish/marker_search_client_spec.rb spec/services/github_issue_publish/reconciliation_service_spec.rb spec/requests/api/v1/issue_drafts_spec.rb`: 25 examples, 0 failures
- `npm run frontend:e2e`: 13 passed（10 candidate UI）
- `bundle exec rspec spec/services/github_issue_publish/reconciliation_service_spec.rb spec/services/github_issue_publish/marker_search_client_spec.rb spec/requests/api/v1/issue_drafts_spec.rb`: 26 examples, 0 failures（incomplete search blocker）
- `bundle exec rspec spec/services/github_issue_publish/marker_search_client_spec.rb spec/services/github_issue_publish/reconciliation_service_spec.rb spec/requests/api/v1/issue_drafts_spec.rb`: 28 examples, 0 failures（rate limit metadata）
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK（429 RateLimited response）
- `npm run frontend:build`: success（GitHub rate limit表示文言）
- `bundle exec rails db:migrate`: success（reconciliation retry metadata）
- `RAILS_ENV=test bundle exec rails db:migrate`: success（reconciliation retry metadata）
- `bundle exec rspec spec/models/github_issue_publish_attempt_spec.rb spec/services/github_issue_publish/reconciliation_service_spec.rb spec/services/github_issue_publish/marker_search_client_spec.rb spec/services/github_issue_publish/manual_reconciliation_service_spec.rb spec/requests/api/v1/issue_drafts_spec.rb`: 39 examples, 0 failures（cooldown retry）
- `npm run frontend:e2e`: 14 passed（cooldown UI）
- `bundle exec rspec spec/jobs/github_issue_publish/reconciliation_retry_job_spec.rb spec/services/github_issue_publish/reconciliation_retry_scheduler_spec.rb spec/services/github_issue_publish/reconciliation_service_spec.rb spec/models/github_issue_publish_attempt_spec.rb`: 16 examples, 0 failures（async retry job）
- `bundle exec rspec`: 137 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run frontend:build`: success
- `FRONTEND_URL=http://localhost:3002 NEXT_PUBLIC_API_BASE_URL=http://localhost:3003/api/v1 npm run frontend:e2e`: 14 passed
- `npm run frontend:e2e`: 3000番を別プロジェクトが使用していたため初回は環境要因で失敗。3002/3003へ分離して再実行済み。
- GitHub Actions CI `28654075484`: success（commit `5d837a2189255e9f77c03930365a43d3ba003cee`）
- `docs/decisions/ADR-0010_production_job_queue_backend.md`: 追加（production job queue backend ADR）
- `docs/review/20260703_production_job_queue_adr_review.md`: 追加（ADR review）
- `bundle exec rspec spec/config/solid_queue_configuration_spec.rb spec/jobs/github_issue_publish/reconciliation_retry_job_spec.rb spec/services/github_issue_publish/reconciliation_retry_scheduler_spec.rb spec/services/github_issue_publish/reconciliation_service_spec.rb spec/models/github_issue_publish_attempt_spec.rb`: 19 examples, 0 failures（Solid Queue config / dedicated queue）
- `bundle exec rspec`: 140 examples, 0 failures（Solid Queue導入後）
- `bundle exec ruby bin/rails zeitwerk:check`: All is good（Solid Queue導入後）
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK（Solid Queue導入後）
- `npm run frontend:build`: success（Solid Queue導入後）
- `FRONTEND_URL=http://localhost:3002 NEXT_PUBLIC_API_BASE_URL=http://localhost:3003/api/v1 npm run frontend:e2e`: 14 passed（Solid Queue導入後）
- production mode local worker smoke: 別queue DB `ai_pm_queue_test` で `bin/jobs` がSupervisor、Dispatcher、Worker、Schedulerを起動
- production mode heartbeat check: `SolidQueue::Process` に Dispatcher、Scheduler、Supervisor(async)、Worker を確認
- 2026-07-04 controlled retry approval metadata: `bundle exec rspec spec/services/github_issue_publish/manual_reconciliation_service_spec.rb spec/requests/api/v1/issue_drafts_spec.rb`: 29 examples, 0 failures
- 2026-07-04 controlled retry approval metadata: `bundle exec rspec`: 143 examples, 0 failures
- 2026-07-04 controlled retry approval metadata: `bundle exec ruby bin/rails zeitwerk:check`: All is good
- 2026-07-04 controlled retry approval metadata: `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK（Node engine warning: current v22.7.0）
- 2026-07-04 controlled retry approval metadata: `npm run frontend:build`: success
- 2026-07-04 controlled retry approval metadata: `npm run frontend:e2e`: 14 passed
- 2026-07-04 Link Issue URL/番号不一致: `bundle exec rspec spec/requests/api/v1/issue_drafts_spec.rb`: 24 examples, 0 failures
- 2026-07-04 Link Issue URL/番号不一致: `FRONTEND_URL=http://localhost:3002 NEXT_PUBLIC_API_BASE_URL=http://localhost:3003/api/v1 npm run frontend:e2e`: 14 passed
- 2026-07-04 GitHub App live smoke runbook: `docs/release/20260704_github_app_live_smoke_runbook.md` 追加、実credential実行は未実施
- 2026-07-04 GitHub照合履歴API/UI: `npm run display:check`: success
- 2026-07-04 GitHub照合履歴API/UI: `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK（Node engine warning: current v22.7.0）
- 2026-07-04 GitHub照合履歴API/UI: `bundle exec rspec spec/requests/api/v1/issue_drafts_spec.rb`: 25 examples, 0 failures
- 2026-07-04 GitHub照合履歴API/UI: `bundle exec ruby bin/rails zeitwerk:check`: All is good
- 2026-07-04 GitHub照合履歴API/UI: `npm run frontend:build`: success
- 2026-07-04 GitHub照合履歴API/UI: `npm run frontend:e2e`: 14 passed
- 2026-07-04 GitHub connection state cleanup: `bundle exec rspec spec/models/github_connection_state_spec.rb spec/services/github_integration/connection_state_spec.rb spec/jobs/github_integration/connection_state_cleanup_job_spec.rb spec/config/solid_queue_configuration_spec.rb`: 13 examples, 0 failures
- 2026-07-04 GitHub connection state cleanup: `bundle exec ruby bin/rails zeitwerk:check`: All is good
- 2026-07-04 GitHub connection state cleanup: `bundle exec rspec`: 150 examples, 0 failures
- 2026-07-04 GitHub connection state cleanup: `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK（Node engine warning: current v22.7.0）
- 2026-07-04 GitHub connection state cleanup: `npm run frontend:build`: success
- 2026-07-04 GitHub callback state consumption ADR: `bundle exec rspec spec/requests/api/v1/integration_accounts_spec.rb spec/services/github_integration/connection_state_spec.rb`: 11 examples, 0 failures
- 2026-07-04 GitHub callback failure AuditLog / reconnect UI: `bundle exec rspec spec/requests/api/v1/integration_accounts_spec.rb spec/requests/api/v1/audit_logs_spec.rb`: 9 examples, 0 failures
- 2026-07-04 GitHub callback failure AuditLog / reconnect UI: `bundle exec rspec`: 150 examples, 0 failures
- 2026-07-04 GitHub callback failure AuditLog / reconnect UI: `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK（Node engine warning: current v22.7.0）
- 2026-07-04 GitHub callback failure AuditLog / reconnect UI: `npm run display:check`: Display labels OK
- 2026-07-04 GitHub callback failure AuditLog / reconnect UI: `npm run frontend:build`: success
- 2026-07-04 GitHub callback failure AuditLog / reconnect UI: `npm run frontend:e2e -- --grep "shows pending GitHub reconciliation controls"`: 1 passed
- 2026-07-04 GitHub callback result page: `npm run frontend:build`: success
- 2026-07-04 GitHub callback result page: `npm run display:check`: Display labels OK
- 2026-07-04 GitHub callback result page: `npm run frontend:e2e -- e2e/github-callback.spec.ts`: 3 passed
- 2026-07-04 GitHub callback result page: `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK（Node engine warning: current v22.7.0）
- 2026-07-04 Solid Queue staging worker smoke runbook: `docs/release/20260704_solid_queue_staging_worker_smoke_runbook.md` 追加、実staging実行は未実施
- 2026-07-04 Queue health monitoring MVP: `bundle exec rspec spec/requests/api/v1/operations_spec.rb spec/services/operations/queue_health_query_spec.rb`: 3 examples, 0 failures
- 2026-07-04 Queue health monitoring MVP: `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK（Node engine warning: current v22.7.0）
- 2026-07-04 Queue health monitoring MVP: `npm run frontend:build`: success
- 2026-07-04 Queue health monitoring MVP: `npm run frontend:e2e -- e2e/queue-health.spec.ts`: 1 passed
- 2026-07-04 failed job safe visibility: `bundle exec rspec spec/services/operations/queue_health_query_spec.rb spec/requests/api/v1/operations_spec.rb`: 3 examples, 0 failures
- 2026-07-04 failed job safe visibility: `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK（Node engine warning: current v22.7.0）
- 2026-07-04 failed job safe visibility: `npm run display:check`: Display labels OK
- 2026-07-04 failed job safe visibility: `npm run frontend:build`: success
- 2026-07-04 failed job safe visibility: `npm run frontend:e2e -- e2e/queue-health.spec.ts`: 1 passed

## 次アクション

- GitHub App settingsでWebhook URLをowned staging / production endpointへ変更する
- `GITHUB_WEBHOOK_SECRET` をruntimeへ設定し、GitHub App側のWebhook secretと一致させる
- `scripts/github-webhook-live-smoke.rb --limit 5` を再実行し、`safe_failures` が空になることを確認する
- GitHub deliveryを再triggerまたはredeliverし、2xx deliveryと `GithubWebhookDelivery` / AuditLog同期を確認する
- stagingで `scripts/solid-queue-worker-smoke-readiness.rb` をRails runnerから実行し、`safe_failures` が空の証跡を取得する
- productionはobservation-onlyから開始し、release owner承認後にworker heartbeat、recurring task、Queue health release gateの証跡を保存する
- failed job retry/discard staging smokeを既存templateで実施する
- queue監視の通知/SLO、failed job再実行/破棄、operator権限、監査UIを後続Issueとして設計する
- `publish_idempotency_key` のdigest名称renameをADRまたはmigrationで検討する
- cleanup jobのstaging/production recurring schedule発火をworker smokeで確認する
- GitHub照合履歴のpagination、filter、監査ログ詳細画面を検討する
- Backend runtime validatorを強化し、Redocly CLIまたは専用OpenAPI parser採用をADR化する
- Issue同期の冪等性方針をADR化する
- AI provider接続時のプロンプト、スキーマ検証、失敗時リカバリを `docs/ai/` に追加する
