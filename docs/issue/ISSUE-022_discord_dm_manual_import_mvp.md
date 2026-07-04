# ISSUE-022: Discord DM手動インポートとAI整理MVPを作る

## Issue番号

ISSUE-022

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/22

登録理由: ユーザーから「DiscordのDMのやり取りを整理してまとめる機能も欲しい」と要望があったため。

登録日: 2026-07-02

## 背景

AI PM Platformは、会議だけでなく、日常的な意思決定や仕様相談が発生するチャットからも、議事録、要件、Issue、API設計へ変換できる必要がある。Discord DMには、少人数の意思決定、仕様確認、契約前相談、個別依頼、障害対応の初動など、プロジェクト化すべき情報が多く含まれる。

一方で、DMは会議ログよりもセンシティブであり、相手方の同意、個人情報、秘密情報、利用規約、Discord API制約を強く考慮する必要がある。初期実装でDiscord DMの自動取得を狙うと、プライバシー・審査・運用リスクが高い。

## 目的

ユーザーが明示的に貼り付けたDiscord DMテキストを、AIが安全に整理し、要約、決定事項、未決事項、TODO、Issue候補、要件候補へ変換できるMVPを作る。

## 完了条件

- Discord DM由来テキストの手動インポート要件が定義されている
- Discord DM自動取得をMVP非スコープとするADRが保存されている
- API設計でインポート、整理生成、レビュー、承認の境界が定義されている
- DM由来データの同意、秘匿、保持、監査、AI送信前チェックが定義されている
- STRIDE/OWASP観点のセキュリティレビューが保存されている
- Issue/要件/API設計レビューが `docs/review/` に保存されている
- 実装前にOpenAPIレビューを通す次アクションが明確である

## スコープ

- Discord DMテキストの手動貼り付けインポート
- インポート前の同意確認、編集、redaction
- AIによる会話整理ドラフト生成
- 要約、決定事項、未決事項、TODO、Issue候補、要件候補、リスク抽出
- レビューゲート
- AuditLog
- API設計
- セキュリティ設計

## 非スコープ

- Discord DMの自動取得
- self-bot、ユーザーアカウント自動操作
- 未承認の `dm_channels.read` 前提の実装
- Group DMへのBot参加
- 相手方同意のないDM取り込み
- Slack DM対応
- 音声通話/画面共有の自動記録

## 関連レビュー

- `docs/review/20260702_discord_dm_manual_import_requirements_review.md`
- `docs/review/20260702_discord_dm_parallel_design_review.md`
- `docs/review/20260702_discord_dm_openapi_design_review.md`
- `docs/review/20260705_discord_dm_backend_mvp_review.md`

## レビュー結果

2026-07-02にCodex一次レビューを実施。Discord DM整理はAI PM Platformの価値を広げる有望機能だが、DM自動取得は初期MVPとしてリスクが高い。世界レベルのSaaS基準では、ユーザーが明示的に貼り付けた会話だけを対象にし、同意確認、redaction、secret scan、レビューゲート、監査ログを必須にする方針が妥当。実装へ進む前にOpenAPI、DB設計、UI設計レビューが必要。

2026-07-05にBackend MVPを実装。既存OpenAPI契約に合わせてConversation Import API、Conversation Summary Draft API、scan service、deterministic summary generation、DB migration、request specを追加した。ControllerはHTTP受付とレスポンスに留め、同意/secret scanと整理生成はServiceへ分離した。AuditLogには本文全文やsecret値を保存せず、safe metadataだけを残す。

追加レビューで、raw/redacted text更新後に再scanなしでAI整理へ進める穴と、承認理由なしでsummary draftをapproveできる穴を修正した。更新後は既存draftを `stale` にし、import statusを `draft` へ戻す。承認時は `approval_note` を必須にする。

良かった点:

- DM整理をIssue #2の会議ログ取り込みから分離し、プライバシー境界を明確化した。
- 手動貼り付けMVPに絞ることでDiscord API審査・規約・権限リスクを下げた。
- AI整理結果をそのままIssue化せず、レビューゲートを維持する方針にした。
- 同意確認、redaction、秘密情報検出、AuditLogをP0要件に含めた。
- ADR、要件、API設計、セキュリティ設計を実装前に作成した。
- DB設計、画面設計、AI prompt/schemaを並行して追加し、実装前の責任境界を整理した。
- OpenAPI本体へConversation Import / Summary Draft endpointとschemaを追加し、TypeScript API型を生成した。
- BackendでConversation Import作成/一覧/取得/更新、scan、summary生成、summary取得/更新/承認の最小APIを実装した。
- 同意なし、secret-like contentありではAI整理へ進めないBackend gateを追加した。
- raw/redacted text更新後は既存summary draftを `stale` にし、再scanを必須にした。
- redacted textをAI整理入力として優先し、raw secretが生成結果へ混入しないことをrequest specで固定した。
- 承認理由なしのsummary draft approveを拒否し、OpenAPI契約の必須項目とBackend挙動を揃えた。

改善点:

- OpenAPI本体への反映とBackend route、controller、model、migration、serviceは実装済み。
- DB設計とDB migrationは実装済み。画面設計、AI prompt/schemaは設計文書として追加済みだが、UI実装、Structured Outputs接続は未実施。
- Discord公式審査やDeveloper Policyに対する詳細リーガルレビューは未実施。
- 参加者同意のUI文言、証跡保存粒度、削除/保持期間の仕様が未確定。
- AI出力の引用根拠、confidence、誤要約訂正フローは未実装。
- raw textは平文DB保存のため、本番前に暗号化、retention、削除/匿名化方針のADRが必要。
- 認証ユーザー未実装のため、imported_by、approved_by、consent_confirmed_byは実ユーザーに紐付いていない。

検証結果:

- ドキュメント追加のみ
- `git diff --check`: success
- `npm run api:verify`: success
- `docs/api/openapi.yaml`: Conversation Import / Summary Draft API追加
- `frontend/lib/api/schema.d.ts`: OpenAPI型再生成
- `docs/architecture/20260702_discord_dm_manual_import_db_design.md`: 追加
- `docs/product/20260702_discord_dm_manual_import_screen_design.md`: 追加
- `docs/ai/20260702_discord_dm_summary_prompt_schema.md`: 追加
- 2026-07-05 Backend MVP: `bundle exec rails db:migrate`: success
- 2026-07-05 Backend MVP: `RAILS_ENV=test bundle exec rails db:migrate`: success
- 2026-07-05 Backend MVP: `bundle exec rspec spec/requests/api/v1/conversation_imports_spec.rb spec/requests/api/v1/conversation_summary_drafts_spec.rb`: 12 examples, 0 failures
- 2026-07-05 Backend MVP: `bundle exec rspec`: 165 examples, 0 failures
- 2026-07-05 Backend MVP: `bundle exec ruby bin/rails zeitwerk:check`: All is good
- 2026-07-05 Backend MVP: `npm run api:verify`: success
- 2026-07-05 Backend MVP: `npm run display:check`: success
- 2026-07-05 Backend MVP: `npm run frontend:build`: success
- 2026-07-05 Backend MVP: `git diff --check`: pass
- 2026-07-05 Backend MVP: GitHub Actions CI `28713458334`: success（commit `c48d3b8`）

## 優先度

P1

理由:

- Discord中心の開発チームでは、DMに仕様・依頼・意思決定が埋もれやすく、AI PMの差別化につながる
- ただし、既存P0のGitHub Issue/OpenAPI publish pipeline完了後に実装するのが安全
- DMは高センシティブ領域のため、実装速度より統制設計を優先する

## 次アクション

- DMインポートUIのワイヤーフレームまたは静的画面を作成する
- AI整理prompt/schemaをStructured Outputs providerへ接続する
- raw text暗号化、retention、削除/匿名化方針のADRを作成する
- PII/redaction suggestionを強化する
- Review CenterとConversation Summary Draft承認を接続する
- Frontend/AI provider実装時にSTRIDEレビューを再実施する
- GitHub IssueへBackend MVP完了内容を同期する（完了）

## 関連ドキュメント

- `docs/product/20260702_discord_dm_manual_import_requirements.md`
- `docs/api/20260702_discord_dm_manual_import_api_design.md`
- `docs/security/20260702_discord_dm_manual_import_security.md`
- `docs/decisions/ADR-0009_discord_dm_manual_import_first.md`
- `docs/architecture/20260702_discord_dm_manual_import_db_design.md`
- `docs/product/20260702_discord_dm_manual_import_screen_design.md`
- `docs/ai/20260702_discord_dm_summary_prompt_schema.md`
