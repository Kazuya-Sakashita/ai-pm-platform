# ISSUE-002: Discord会議ログを取り込み、議事録生成MVPを作る

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/2

状態: Closed

クローズ日: 2026-07-06

クローズレビュー: `docs/review/20260706_discord_meeting_minutes_mvp_closure_review.md`

クローズコメント: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/2#issuecomment-4891975713

main CI: https://github.com/Kazuya-Sakashita/ai-pm-platform/actions/runs/28786247024

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
- `docs/review/20260630_frontend_meeting_workspace_api_connection_review.md`
- `docs/review/20260630_frontend_playwright_smoke_review.md`
- `docs/review/20260630_ci_frontend_e2e_review.md`
- `docs/review/20260630_frontend_failure_path_e2e_review.md`
- `docs/review/20260630_openai_failure_contract_review.md`
- `docs/review/20260706_discord_meeting_minutes_mvp_closure_review.md`

## レビュー結果

P0として妥当。ただし、いきなりBot実装へ進むと権限と運用が重くなるため、初期は手動入力に絞るべき。

## 次アクション

- 完了済み。GitHub Issue #2はクローズ済み。
- live OpenAI smokeと議事録品質評価はrelease/stagingまたは品質評価Issueで継続追跡する。

## 進捗

完了。

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

2026-06-30 09:45 JST追加:

- Next.js App Router frontendを追加
- Meeting Workspaceを第一画面として実装
- Project作成/選択、Meeting保存、Minutes生成、Job取得、Minutes取得/編集/承認、Review作成をOpenAPI clientで接続
- `npm run frontend:build`: 成功
- `npm audit --omit=dev`: 0 vulnerabilities
- local API smokeでProject作成 -> Meeting保存 -> Minutes生成 -> Job取得 -> Minutes取得に成功
- `docs/decisions/ADR-0005_frontend_next_api_workspace.md` を追加

2026-06-30 10:15 JST追加:

- `@playwright/test` を導入
- `npm run frontend:e2e` を追加
- `frontend/e2e/meeting-workspace.spec.ts` でProject作成、Meeting保存、Minutes生成、Review作成、Minutes承認を自動検証
- スクリーンショットQAで1280px付近のReview gate回り込みを検出し、CSS grid配置を修正
- `npm run frontend:e2e`: 1 passed
- `npm run frontend:build`: 成功
- `npm audit --omit=dev`: 0 vulnerabilities
- `bundle exec rspec`: 24 examples, 0 failures

2026-06-30 11:05 JST追加:

- `.github/workflows/ci.yml` を追加
- CIでPostgreSQL service、Rails DB prepare、RSpec、Zeitwerk check、OpenAPI verify、Frontend build、Rails API起動、Playwright E2Eを実行する構成を追加
- OpenAI API keyに依存しないよう `MINUTES_GENERATION_PROVIDER=deterministic` をCIに明示
- 失敗時にPlaywright artifactsとbackend server logを保存する設定を追加
- GitHub Actions初回Run `28417183475` は `Gemfile.lock` のLinux platform不足で失敗
- `bundle lock --add-platform x86_64-linux` によりCI runner向けplatformを追加
- GitHub Actions修正後Run `28417288092`: 成功。verify job 1m45s

2026-06-30 12:05 JST追加:

- `MinutesGenerationService` の共通入口でsecret scanを実行するよう変更
- validation error E2Eを追加
- secret blocked + failed job E2Eを追加
- `npm run frontend:e2e`: 3 passed
- `bundle exec rspec`: 24 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run frontend:build`: 成功
- `npm run api:verify`: 成功。OpenAPI contract warningなし

2026-06-30 12:17 JST追加:

- OpenAI providerのrate limitを429として扱うmappingを追加
- provider failure時のfailed job / safe error / request_id付きaudit metadataをrequest specで追加
- FrontendでOpenAI upstream failure / invalid AI response / rate limitのUI failure E2Eを追加
- 外部OpenAI通信に依存しないAPI contract mock方式でCI再現性を維持
- `bundle exec rspec`: 27 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run frontend:build`: 成功
- `npm run frontend:e2e`: 6 passed
- `npm run api:verify`: 成功。OpenAPI contract warningなし
- `npm audit --omit=dev`: 0 vulnerabilities

残リスク:

- 本番OpenAI API keyでのlive generation検証はrelease/staging gateで扱う。
- rate limit時のRetry UI / backoff guidanceはP2 UX改善として扱う。
- 議事録品質のgolden datasetと自動採点は品質評価Issueで扱う。
- Discord Bot自動取り込み、音声文字起こし、Slack対応はMVP後ロードマップで扱う。
