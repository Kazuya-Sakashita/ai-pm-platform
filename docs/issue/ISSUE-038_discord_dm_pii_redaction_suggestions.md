# ISSUE-038: Discord DMのPII検出とマスキング提案を強化する

## Issue番号

ISSUE-038

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/38

登録日: 2026-07-05

## 背景

ISSUE-022ではDMインポート前後にマスキング入力と安全チェックを行えるようになった。Backend MVPではsecret-like contentと同意不足を中心にブロックしているが、DMには氏名、メールアドレス、電話番号、住所、契約情報、個別事情などPIIが含まれやすい。

世界レベルSaaS基準では、ユーザーの手動マスキングに依存しすぎず、具体的なマスキング提案とsafe copyを出す必要がある。

## 目的

SensitiveContentScannerとUI表示を強化し、DM由来のPII/credential/legal/financial情報を検出し、ユーザーが安全にマスキングできる提案を出す。

## 完了条件

- メールアドレス、電話番号、URL token、API key風文字列、住所風表現などの検出specがある
- PII検出時のseverity/action/blocked判定が明確である
- マスキング提案が日本語UIで安全に表示される
- AI整理前に必要なマスキングが未完了の場合は生成できない
- false positive時の扱いがレビュー文書に残っている
- request specとFrontend E2Eで代表ケースを検証している
- STRIDE/OWASPレビューが `docs/review/` に保存されている

## スコープ

- SensitiveContentScanner強化
- redaction suggestion生成
- safe Japanese display labels
- request spec
- Frontend E2E
- セキュリティレビュー

## 非スコープ

- 外部DLPサービス連携
- 画像/添付ファイルOCR
- Discord自動取得
- 法務判断の自動化
- 完全な個人情報検出保証

## 関連レビュー

- `docs/review/20260705_discord_dm_frontend_mvp_review.md`
- `docs/review/20260705_discord_dm_pii_redaction_design_review.md`
- `docs/review/20260705_discord_dm_pii_redaction_implementation_review.md`
- `docs/security/20260702_discord_dm_manual_import_security.md`

## レビュー結果

Codex一次レビューでは、現在の安全チェックはMVPとして有効。ただしDMの高センシティブ性を考えると、secret検出だけでは不十分であり、PIIと業務機密のマスキング提案を強化しない限りproduction qualityには届かない。

2026-07-05に実装完了。`SensitiveContentScanner` にメールアドレス、電話番号、URL token、API key風文字列、住所風表現、金融/法務文脈の分類付きfindingを追加し、`ConversationImports::ScanService` でsafe safety flagと種別別redaction suggestionへ変換するようにした。Frontend E2Eでは安全チェックpanelに生PIIを出さず、置換候補と日本語説明を表示し、blocked状態では整理ドラフト生成ボタンが無効になることを確認した。

検証結果:

- `bundle exec rspec spec/services/sensitive_content_scanner_spec.rb spec/requests/api/v1/conversation_imports_spec.rb`: 23 examples, 0 failures
- `npm run frontend:e2e -- --grep "safe PII redaction"`: 1 passed
- `npm run api:verify`: success
- `npm run display:check`: success
- `npm run frontend:build`: success
- `bundle exec rspec`: 182 examples, 0 failures

補足: `npm run api:verify` では既存のNode `v22.7.0` が期待範囲より古い警告とRedocly CLI更新通知が出たが、OpenAPI lint/type生成は成功した。

## 優先度

P1

理由:

- DMの情報漏えいリスク低減に直結する
- #35 AI provider接続前に進めるとAI送信安全性が上がる
- #29/#32のデータ保護と並行して実装できる

## 次アクション

1. GitHub Issue #38へ実装結果を同期する。
2. CI成功後にGitHub Issue #38をcloseする。
3. 次の推奨順としてISSUE-035またはISSUE-039へ進む。
