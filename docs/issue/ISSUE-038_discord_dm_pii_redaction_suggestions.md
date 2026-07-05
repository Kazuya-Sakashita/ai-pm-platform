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
- `docs/security/20260702_discord_dm_manual_import_security.md`

## レビュー結果

Codex一次レビューでは、現在の安全チェックはMVPとして有効。ただしDMの高センシティブ性を考えると、secret検出だけでは不十分であり、PIIと業務機密のマスキング提案を強化しない限りproduction qualityには届かない。

## 優先度

P1

理由:

- DMの情報漏えいリスク低減に直結する
- #35 AI provider接続前に進めるとAI送信安全性が上がる
- #29/#32のデータ保護と並行して実装できる

## 次アクション

1. 現在のSensitiveContentScannerの検出対象を棚卸しする。
2. PII/credential/legal/financialの代表パターンを追加する。
3. Backend request specとFrontend E2Eを追加する。
4. false positiveとUI表示のレビューを保存する。
