# ISSUE-068: GitHub Webhook secret rotation方針をADR化し運用導線を設計する

## Issue番号

ISSUE-068

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/108

登録日: 2026-07-07
状態: OPEN

## 背景

ISSUE-067でGitHub App webhookの署名検証を追加した。現状は `GITHUB_WEBHOOK_SECRET` 単一secretでHMAC SHA-256を検証しているため、secret漏えい、GitHub App再作成、staging / production切替、rotation作業時に旧secretと新secretを安全に併用する方針が未定義である。

世界レベルSaaS基準では、公開webhook endpointのsecretは「設定できる」だけでなく、「安全に交換できる」「交換中もdeliveryを落としにくい」「監査証跡が残る」ことが必要である。

## 目的

GitHub Webhook secret rotationの設計方針をADR化し、staging / productionで安全にsecretを交換できる運用導線を定義する。

## 完了条件

- `docs/decisions/` にWebhook secret rotationのADRを追加する
- current / previous secretを使うか、versioned keyringを使うかを比較する
- rotation時の許容期間、rollback、監査ログ、環境変数命名を定義する
- `WebhookSignatureVerifier` の変更要否を判断する
- secret未設定、旧secret、新secret、不正signatureのRSpec方針を定義する
- staging / production runbookへ手順を追記する
- Security Engineer観点のレビューを `docs/review/` へ保存する

## スコープ

- ADR
- Security / operations設計
- 必要な場合のVerifier最小変更
- RSpec追加方針
- Runbook更新

## 非スコープ

- 実GitHub App credentialの変更
- secret管理SaaS導入
- GitHub webhook live delivery smoke
- UI実装

## 関連Issue

- ISSUE-004 / GitHub Issue #4
- ISSUE-067 / GitHub Issue #106

## 関連レビュー

- `docs/review/20260707_github_webhook_signature_installation_sync_implementation_review.md`

## レビュー結果

ISSUE-067の実装レビューで、secret rotationが未実装の改善点として残った。P0 blockerではないが、production運用前にはP1として方針を固定する必要がある。

## 優先度

P1

## 次アクション

1. rotation方式をADRで比較する。
2. Verifierを変更する場合はOpenAPI影響なしでRSpecを追加する。
3. staging / production runbookへrotation手順を追加する。
