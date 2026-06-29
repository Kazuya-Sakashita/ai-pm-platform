# ISSUE-002: Discord会議ログを取り込み、議事録生成MVPを作る

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/2

登録日: 2026-06-30
同期方法: `scripts/sync-github-issues.rb --apply`

## 背景

初期ICPはDiscordとGitHubを使う小規模開発チームである。最初の価値は、Discord会議や会議ログを開発成果物に変換することにある。

## 目的

会議テキストまたはDiscordログを登録し、AI議事録、決定事項、未決事項、アクションアイテムを生成できるようにする。

## 完了条件

- 会議テキストを登録できる
- 会議内容を保存できる
- AI議事録を生成できる
- 決定事項、未決事項、アクションアイテムを分離できる
- レビュー結果を保存できる
- 画面設計、API設計、DB設計レビューが完了している

## スコープ

- 手動テキスト登録
- Discordログ手動貼り付け
- AI議事録生成
- レビュー保存

## 非スコープ

- Discord Bot自動取り込み
- 音声文字起こし
- Slack対応

## 関連レビュー

- `docs/review/20260629_mvp_review.md`
- `docs/review/20260629_requirements_review.md`
- `docs/review/20260630_screen_design_review.md`
- `docs/review/20260630_db_design_review.md`
- `docs/review/20260630_discord_minutes_backend_slice_review.md`
- `docs/review/20260630_openai_minutes_generation_provider_review.md`

## レビュー結果

P0として妥当。ただし、いきなりBot実装へ進むと権限と運用が重くなるため、初期は手動入力に絞るべき。

## 次アクション

- OpenAI-backed minutes generation providerを追加する
- Meeting Workspace UIからMeeting作成とMinutes生成を呼び出す
- 生成結果のレビュー依頼導線をFrontendへ接続する
- OpenAI実装後にGitHub #2のclose可否を再評価する

## 進捗

進行中。

2026-06-30 07:51 JST確認:

- 手動テキスト/Discordログ貼り付けは `POST /api/v1/projects/:project_id/meetings` で保存可能
- `source_type: discord_log` を受け付けるrequest specを追加済み
- `POST /api/v1/meetings/:id/generate-minutes` を実装済み
- deterministic placeholderでsummary、decisions、open_questions、action_itemsを分離してMinutesを作成可能
- `GET/PATCH /api/v1/minutes/:id` と `POST /api/v1/minutes/:id/approve` を実装済み
- Minutes review resultは `POST /api/v1/reviews` で保存可能、request spec追加済み
- `bundle exec rspec`: 15 examples, 0 failures
- `npm run api:verify`: 成功。OpenAPI contract warningなし

2026-06-30 09:10 JST追加:

- `MINUTES_GENERATION_PROVIDER=auto|openai|deterministic` によるprovider選択を追加
- OpenAI Responses API + Structured Outputs用providerを追加
- `OPENAI_API_KEY` 未設定時はOpenAI強制時のみ424とfailed jobを保存
- OpenAI送信前にsecret patternを検出し、該当時はAI送信をブロック
- provider失敗時に `jobs.status=failed`、`safe_error_detail`、`minutes.generation_failed` audit logを保存
- `POST /api/v1/meetings/:id/generate-minutes` のOpenAPIへ422/424/502を追加
- `bundle exec rspec`: 24 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: 成功。OpenAPI contract warningなし

未完了:

- 本番OpenAI API keyでのlive generation検証
- Frontend Meeting Workspaceとの接続
- 生成結果レビュー導線のUI実装
