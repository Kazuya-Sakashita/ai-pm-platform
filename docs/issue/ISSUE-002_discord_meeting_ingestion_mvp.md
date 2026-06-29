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

## レビュー結果

P0として妥当。ただし、いきなりBot実装へ進むと権限と運用が重くなるため、初期は手動入力に絞るべき。

## 次アクション

- 画面設計初稿は `docs/product/20260630_mvp_screen_design.md` に作成済み
- DB設計初稿は `docs/architecture/20260630_db_design.md` に作成済み
- Minutes APIを含むOpenAPI初稿は `docs/api/openapi.yaml` に作成済み
- 次はISSUE-007としてワイヤーフレームとReview blocker UXを詳細化する
