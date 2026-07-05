# ISSUE-035: Discord DM整理をStructured Outputs providerへ接続する

## Issue番号

ISSUE-035

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/35

登録日: 2026-07-05

## 背景

ISSUE-022でDiscord DM手動インポートBackend/Frontend MVPが実装され、現在はdeterministic providerで整理ドラフトを生成している。`docs/ai/20260702_discord_dm_summary_prompt_schema.md` にはAI整理prompt/schemaがあるが、OpenAI Structured Outputs providerにはまだ接続されていない。

AI PM Platformの価値は、DMから決定事項、未解決事項、アクション、Issue候補、要件候補、リスクを高品質に抽出できることにある。deterministic providerだけでは、実利用時の精度、引用根拠、confidence、誤要約リスクを検証できない。

## 目的

Discord DM整理のAI providerをStructured Outputsへ接続し、schema準拠、引用根拠、confidence、safe failure handlingをテスト可能にする。

## 完了条件

- Conversation Summary用Structured Outputs providerが実装されている
- 通常テストはlocal/deterministicまたはstubで安定実行できる
- OpenAI実呼び出しは明示的なmanual smokeに限定されている
- invalid AI response、rate limit、provider failureをsafe errorへ変換している
- secret/blocked importではAI providerを呼ばないことをrequest specで固定している
- schemaと `docs/ai/20260702_discord_dm_summary_prompt_schema.md` の差分が更新されている
- レビュー結果が `docs/review/` に保存されている

## スコープ

- Conversation Summary provider実装
- provider factory / DI
- schema validation
- request spec / service spec
- safe error handling
- manual smoke手順
- AI設計レビュー

## 非スコープ

- Discord DM自動取得
- Frontend編集UI
- Review Center連動
- OpenAI実APIを通常CIで叩くこと
- production key管理

## 関連レビュー

- `docs/review/20260705_discord_dm_frontend_mvp_review.md`
- `docs/review/20260705_discord_dm_backend_mvp_review.md`

## レビュー結果

Codex一次レビューでは、deterministic providerはMVP開発とCI安定性には有効。ただし世界レベルSaaS基準では、実AI provider接続、schema準拠、引用根拠、safe failure handlingを確認しない限り、DM整理機能の品質評価は不十分である。

## 優先度

P1

理由:

- AI PM Platformの中核価値に直結する
- #29/#32のデータ保護と並行して設計・stub実装できる
- 実API smokeは後段に分離できる

## 次アクション

1. 現在のConversation Summary generation serviceとprovider境界を確認する。
2. Structured Outputs schemaを実装用に固定する。
3. provider failure contractをrequest specで固定する。
4. manual OpenAI smoke手順を `docs/release/` または `docs/ai/` に保存する。
