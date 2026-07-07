# GitHub App live smoke / GitHub Issue API ID bigint修正レビュー

## 評価日時

2026-07-08 07:11:36 JST

## 評価担当

Codex、Security Engineer、Backend Architect、QA、Product Manager

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- Release Check

## Issue番号

- ISSUE-004
- GitHub Issue #4

## 対象

- GitHub App live credential smoke
- `issue_drafts.github_issue_api_id`
- `github_issue_publish_attempts.github_issue_api_id`
- `docs/api/openapi.yaml` の `github_issue_api_id`

## 実施内容

- `.env` の必須GitHub App設定を値非表示で確認した。
- GitHub App JWTで `/app` を確認し、slug `ai-pm-platform` を取得した。
- installation `145067753` が `Kazuya-Sakashita/ai-pm-platform` に対して `issues: write`、`metadata: read` を持つことを確認した。
- 実GitHub App credentialでGitHub Issueを作成した。
- 初回publishでGitHub Issue #115は作成されたが、GitHub Issue API ID `4832594358` が32bit integer上限を超え、ローカル保存で失敗した。
- `github_issue_api_id` をDB上で `bigint` に変更した。
- OpenAPIの `github_issue_api_id` に `format: int64` を追加した。
- bigint修正後、GitHub Issue #116のpublishが `local_saved` まで成功した。
- marker searchでGitHub Issue #116を1件検出し、`incomplete_results=false` を確認した。
- 初回失敗で作成済みだったGitHub Issue #115はmarker searchで復旧し、attemptを `reconciled` にした。
- controlled retry安全シナリオでattemptを `retry_approved` にした。

## 証跡

- 基準commit SHA: `ab8a5724ad5be49e6cdcc9b6089152b271397589`
- 環境: local development
- 対象repository: `Kazuya-Sakashita/ai-pm-platform`
- 初回復旧GitHub Issue: `https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/115`、証跡記録後にクローズ済み
- 通常publish成功GitHub Issue: `https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/116`、証跡記録後にクローズ済み
- 初回復旧IssueDraft: `e567f60e-56af-42bc-bfec-f5c2144992c5`
- 初回復旧attempt: `7b9741a4-5d63-4f13-949c-00fa1140df99`
- 通常publish成功IssueDraft: `a076e949-564c-4c31-a342-0dcd22b5db8a`
- 通常publish成功attempt: `9b913975-c929-49db-b85f-0110316ae4a9`
- controlled retry attempt: `d689949b-dedc-4da6-921d-56332097a7b8`
- marker search: `total_count=1`、`match_count=1`、`incomplete_results=false`
- AuditLog actions:
  - `github.connect.smoke_verified`
  - `issue_draft.github_publish_reconciled`
  - `issue_draft.github_published`
  - `issue_draft.github_publish_retry_approved`

## 良かった点

- 実GitHub App credentialで、App ID、private key、installation、repository access、Issues write権限を確認できた。
- GitHub App providerが実際にGitHub Issueを作成できることを確認できた。
- GitHub Search markerで作成済みIssueを検出でき、初回失敗分を二重作成なしで復旧できた。
- token、JWT、private key、raw Idempotency-Keyを出力・保存しない運用を維持できた。
- live smokeで32bit integer設計の欠陥を発見し、bigint migrationとOpenAPI int64明記まで即時修正した。
- controlled retry承認が監査ログ付きで動作することを確認できた。

## 改善点

- GitHub Issue API IDを32bit integerとして保存していたため、実GitHubデータでローカル保存が失敗した。
- `GithubIssuePublishService` の通常エラーハンドリングは `ActiveRecord::ActiveRecordError` 中心で、ActiveModel range errorをreconciliation requiredへ包めなかった。
- manual link安全シナリオで、既に別IssueDraftへ紐付いたGitHub Issue URLを再利用したため、ユニーク制約で停止した。
- 今回はRails runnerでconnection/accountを検証したが、FrontendのGitHub callback画面を経由するフルブラウザsmokeは未実施。
- GitHub webhook live delivery smoke、payload/rate limit guard live smoke、staging/production worker smokeは未実施。

## 優先順位

| 優先度 | 項目 | 理由 |
| --- | --- | --- |
| P0 | `github_issue_api_id` bigint化 | 実GitHub Issue作成後のローカル保存失敗を防ぐ |
| P0 | live smoke結果をISSUE-004へ同期 | 親Issueのクローズ判断に必要 |
| P1 | Frontend callback full smoke | ユーザー導線の実到達性が未確認 |
| P1 | GitHub webhook live delivery smoke | installation変更同期の実証跡が未取得 |
| P1 | staging/production worker smoke | recurring jobとworker heartbeatの実環境証跡が未取得 |
| P2 | manual linkの専用liveシナリオ | 既存URL重複ではなく未紐付けIssueで検証する必要がある |

## 次アクション

1. migration、OpenAPI、RSpecを含む差分をPR化する。
2. GitHub Issue #115 と #116 はsmoke証跡として記録したうえでクローズ済み。
3. Frontend callback full smokeを、ブラウザでGitHub App setup URLから戻る流れで実施する。
4. GitHub webhook live delivery smokeを実施し、delivery digestのみを証跡化する。
5. staging/production worker smokeを実施し、worker heartbeat、recurring task、failed job visibilityを確認する。

## 判定

条件付き合格。

GitHub App credential、実Issue作成、marker search、reconciliation、controlled retryは実証できた。初回にDB型不備を検出したが、bigint化とOpenAPI int64明記で修正した。一方で、Frontend callback full smoke、webhook live delivery、staging/production worker smokeは未完了のため、ISSUE-004はまだクローズしない。

## Knowledge

GitHubのREST API `id` は32bit integerに収まらない。外部SaaSのnumeric IDは、DBでは原則 `bigint` または文字列として扱い、OpenAPIでは `format: int64` を明記する。
