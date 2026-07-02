# GitHub Search Rate Limit Metadata Review

## 評価日時

2026-07-02 20:02:17 JST

## 評価担当

- Codex
- CTO
- Tech Lead
- Backend Architect
- Security Engineer
- QA
- DevOps
- Product Manager

外部AIレビュー: Claude/ChatGPT等の外部レビューは未実施。現時点ではCodex一次レビューとして保存し、外部レビュー待ちとする。

## 使用フレームワーク

- G-STACK
- ADR
- STRIDE
- OWASP Top 10
- ISO25010
- DORA Metrics

## 参照

- GitHub REST API rate limits: https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api
- GitHub REST API best practices: https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api
- GitHub REST API search endpoints: https://docs.github.com/en/rest/search/search

## 対象

- Issue番号: #4
- 対象ファイル:
  - `backend/app/services/github_issue_publish/marker_search_client.rb`
  - `backend/app/services/github_issue_publish/provider_error.rb`
  - `backend/app/controllers/api/v1/issue_drafts_controller.rb`
  - `backend/spec/services/github_issue_publish/marker_search_client_spec.rb`
  - `backend/spec/requests/api/v1/issue_drafts_spec.rb`
  - `docs/api/openapi.yaml`
  - `frontend/lib/api/schema.d.ts`
  - `frontend/lib/display-labels.ts`
  - `docs/decisions/ADR-0008_github_search_retry_backoff.md`
  - `docs/issue/ISSUE-004_github_issue_and_openapi_pipeline.md`

## 良かった点

- GitHub marker searchのrate limitを `github_issue_marker_search_rate_limited` として通常の検索失敗から分離した。
- `retry-after`、`x-ratelimit-remaining`、`x-ratelimit-reset`、`x-ratelimit-resource` をsafe metadataとして抽出した。
- safe metadataをAPI error detailsとAuditLogへ反映し、運用時に次の再試行判断を追えるようにした。
- Authorization header、installation access token、raw GitHub response全文をmetadataへ含めない設計を維持した。
- OpenAPIへreconciliation endpointの429 responseを追加し、生成TypeScript schemaへ同期した。
- Frontend表示文言へGitHub rate limitの日本語メッセージを追加した。
- MarkerSearchClient specとrequest specでrate limit metadataの抽出、API応答、AuditLog保存を検証した。

## 改善点

- 非同期reconciler jobで `next_retry_at`、retry count、cooldownを管理する実装は未追加。
- Frontendではrate limitの詳細metadataを使った再検索可能時刻や待機理由の表示は未実装。
- GitHubのsecondary rate limitで `retry-after` がない場合のbackoff計算は未実装。
- live GitHub App credentialで実際のheader shapeを確認していない。
- ProviderErrorのsafe metadataは追加されたが、他のGitHub provider系エラーへの横展開は未完了。
- Job modelにはsafe metadata columnがないため、Job一覧だけではretry-after等を参照できない。

## 優先順位

- P0: live GitHub App credentialでconnect/publish/reconcile/search metadataをsmoke testする。
- P1: 非同期reconciler jobでretry count、next retry at、cooldownを管理する。
- P1: Frontendに再検索可能時刻、rate limit理由、cooldown表示を追加する。
- P1: secondary rate limit用のbackoff計算と上限回数を実装する。
- P1: controlled retryにcooldown、承認者、理由テンプレートを追加する。
- P2: GitHub provider全体でsafe metadata patternを共通化する。
- P2: Jobにsafe metadataを持たせるか、AuditLogへのリンクで代替するかをADR化する。

## 次アクション

- GitHub Search非同期retry jobを設計・実装する。
- cooldown UIとcontrolled retryの危険操作表示を追加する。
- live GitHub App credentialが設定できる環境でrate limitではない通常search smokeを実施する。
- secondary rate limitのmock testを追加する。
- GitHub App provider側のrate limit safe metadata対応を検討する。

## Issue番号

- #4

## レビュー結果

実装・API設計・運用監査改善として合格。rate limitを通常失敗と区別し、再試行判断に必要なGitHub response headersをsafe metadataとして残せるようになった点は、世界レベルのSaaS運用に近づく改善である。ただし、現時点ではmetadataを返すだけであり、非同期retry job、cooldown UI、secondary rate limit backoff、live smokeが未完了のためIssue #4はまだクローズ不可。

## 検証結果

- `bundle exec rspec spec/services/github_issue_publish/marker_search_client_spec.rb spec/services/github_issue_publish/reconciliation_service_spec.rb spec/requests/api/v1/issue_drafts_spec.rb`: 28 examples, 0 failures
- `npm run api:verify`: success。OpenAPI OK、Redocly lint OK、型生成OK。Node version warningあり
- `npm run frontend:build`: success
- `git diff --check`: success
