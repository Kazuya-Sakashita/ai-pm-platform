# 2026-06-30 API設計初稿

## 対象Issue

- ISSUE-002
- ISSUE-003
- ISSUE-004
- ISSUE-005
- ISSUE-006

## 方針

APIはOpenAPIを正とし、Backend/Frontend実装前にレビューを通す。

MVPでは、会議ログ登録、議事録生成、要件生成、Issue Draft生成、OpenAPI Draft生成、レビュー保存、GitHub公開準備までを対象にする。

## API境界

### Projects

プロジェクト単位で会議、生成物、レビュー、連携状態を管理する。

### Meetings

手動入力またはDiscordログ貼り付けの会議データを保存する。

### Minutes

AI議事録と決定事項、未決事項、アクションアイテムを管理する。

### Requirements

議事録から生成された要件定義を管理する。

### Issue Drafts

GitHub Issueへ送信する前のドラフトを管理する。

### OpenAPI Drafts

要件から生成されたAPI仕様ドラフトを管理する。

### Reviews

各成果物のレビュー結果を保存する。レビュー結果は次工程ゲートに使う。

### Integrations

GitHubなど外部連携の接続状態を管理する。

### Audit Logs

生成、編集、承認、同期の履歴を記録する。

## 状態設計

### 生成物共通

- draft
- generating
- generated
- in_review
- needs_changes
- approved
- failed

### Issue Draft

- draft
- in_review
- needs_changes
- approved
- publishing
- published
- publish_failed

### OpenAPI Draft

- draft
- invalid
- valid
- in_review
- needs_changes
- approved

## エラー方針

APIエラーは `error.code`, `error.message`, `error.details`, `request_id` を返す。

主なエラー:

- validation_error
- unauthorized
- forbidden
- not_found
- review_required
- integration_not_connected
- ai_generation_failed
- rate_limited

## 冪等性

外部連携を伴うAPIは `Idempotency-Key` を受け付ける。

対象:

- GitHub Issue publish
- AI generation retry
- integration webhook handling

## セキュリティ

- 認証はBearer token前提
- GitHub公開APIは承認済みIssue Draftのみ許可
- Review gate未通過の場合は `review_required` を返す
- AuditLogを必ず記録する
- AIへ送る前に秘密情報検出を挟む設計にする

## OpenAPI

初稿は `docs/api/openapi.yaml` に保存する。

