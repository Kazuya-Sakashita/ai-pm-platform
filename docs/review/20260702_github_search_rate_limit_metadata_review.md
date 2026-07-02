# GitHub Search Rate Limit Metadata Review

## 評価日時

2026-07-02 20:00:10 JST

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
- ISO25010
- DORA Metrics

## 参照

- GitHub REST API rate limits: https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api
- GitHub REST API best practices: https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api
- GitHub REST API search endpoints: https://docs.github.com/en/rest/search/search

## 対象

- Issue番号: #4
- 対象ファイル:
  - `backend/app/services/github_issue_publish/provider_error.rb`
  - `backend/app/services/github_issue_publish/marker_search_client.rb`
  - `backend/app/controllers/api/v1/issue_drafts_controller.rb`
  - `backend/spec/services/github_issue_publish/marker_search_client_spec.rb`
  - `backend/spec/requests/api/v1/issue_drafts_spec.rb`
  - `docs/api/openapi.yaml`
  - `frontend/lib/api/schema.d.ts`
  - `frontend/lib/display-labels.ts`
  - `docs/decisions/ADR-0008_github_search_retry_backoff.md`
  - `docs/issue/ISSUE-004_github_issue_and_openapi_pipeline.md`

## 良かった点

- GitHub marker search失敗時に `retry-after`、`x-ratelimit-remaining`、`x-ratelimit-reset`、`x-ratelimit-resource` をsafe metadataへ正規化した。
- 429またはrate limitを示す403を `github_issue_marker_search_rate_limited` として分離し、APIは429を返すようにした。
- API error detailsとAuditLogへsafe metadataを残し、token、Authorization header、raw response本文は出さない方針を維持した。
- OpenAPIへ429 `RateLimited` responseを追加し、Frontend生成型を同期した。
- Frontend表示辞書にGitHub rate limit文言を追加し、英語safe detailがそのまま露出しないようにした。
- MarkerSearchClient specとrequest specで、header parsing、API details、Job failure、AuditLog metadataを検証した。

## 改善点

- rate limit metadataはAPI error detailsとAuditLogに出るが、Job modelにはmetadata columnがないためJob一覧だけではretry-after等を参照できない。
- 非同期reconciler job、retry count、next retry at、cooldown制御は未実装。
- Frontendは汎用rate limit文言のみで、具体的な再試行可能時刻はまだ表示しない。
- GitHub App providerのIssue作成API側には同等のrate limit metadata parsingがまだ入っていない。
- live GitHub App credentialで実Search API response headerを確認していない。

## 優先順位

- P0: live GitHub App credentialでconnect/publish/reconcile/search metadataをsmoke testする。
- P1: 非同期reconciler jobでretry count、next retry at、cooldownを管理する。
- P1: controlled retryにcooldown、承認者、理由テンプレートを追加する。
- P1: GitHub App providerのIssue作成API側にもrate limit safe metadataを展開する。
- P2: Frontendに再試行可能時刻とrate limit理由を表示する。
- P2: Jobにsafe metadataを持たせるか、AuditLogへのリンクで代替するかをADR化する。

## 次アクション

- ADR-0008に基づき、非同期reconciler jobとcooldown UIを実装する。
- controlled retryのcooldown、retry count、承認者表示、理由テンプレートを追加する。
- GitHub App provider側のrate limit safe metadata対応を検討する。
- live GitHub App credentialが設定できる環境でsmoke testを実施する。

## Issue番号

- #4

## レビュー結果

実装・API契約・セキュリティ改善として合格。rate limit時の再試行判断に必要なGitHub headerをsafe metadata化し、監査可能性が上がった。一方で世界レベルのSaaS基準では、metadataを出すだけでは不十分であり、非同期retry job、cooldown UI、controlled retry統制、live smoke、Issue作成API側の同等処理が残るためIssue #4はまだクローズ不可。

## 検証結果

- `bundle exec rspec spec/services/github_issue_publish/marker_search_client_spec.rb spec/services/github_issue_publish/reconciliation_service_spec.rb spec/requests/api/v1/issue_drafts_spec.rb`: 28 examples, 0 failures
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run frontend:build`: success
- `git diff --check`: success
