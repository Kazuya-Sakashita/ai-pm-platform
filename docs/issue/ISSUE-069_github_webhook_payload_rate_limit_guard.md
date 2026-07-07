# ISSUE-069: GitHub Webhook payload sizeとrate limit guardを設計する

## Issue番号

ISSUE-069

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/109

登録日: 2026-07-07
状態: OPEN

## 背景

ISSUE-067でGitHub App webhookの署名検証とinstallation状態同期を実装した。一方で、payload size limitとrate limitingはRails / upstream設定に依存しており、application-level guardは未実装である。

公開webhook endpointは外部から到達するため、巨大payload、短時間連打、unsupported eventの大量deliveryにより、JSON parse、DB書き込み、AuditLog、E2E運用へ負荷がかかる可能性がある。

## 目的

GitHub Webhook endpointに対するpayload sizeとrate limitの安全境界を設計し、production公開前のDoS耐性を上げる。

## 完了条件

- payload size上限を定義する
- size超過時のHTTP status、error code、safe detailを定義する
- rate limitをRails appで持つか、reverse proxy / platform側で持つかを比較する
- unsupported eventを受け続ける場合の保存方針とTTLを確認する
- OpenAPIへ413または429など必要なerror responseを追加するか判断する
- RSpecでsize超過またはrate limit相当の安全失敗を確認する
- Security Engineer / DevOps / Backend Architect観点のレビューを `docs/review/` へ保存する

## スコープ

- payload size guard設計
- rate limit方針
- 必要な場合のRails最小実装
- OpenAPI / RSpec / Runbook更新

## 非スコープ

- WAFや外部CDNの導入
- 実GitHub App webhook live smoke
- Slack通知
- 長期監視SaaS連携

## 関連Issue

- ISSUE-004 / GitHub Issue #4
- ISSUE-067 / GitHub Issue #106

## 関連レビュー

- `docs/review/20260707_github_webhook_signature_installation_sync_implementation_review.md`

## レビュー結果

ISSUE-067の実装レビューで、payload size limitとrate limitingがRails / upstream依存であることが改善点として残った。production公開前の堅牢性向上としてP1で扱う。

## 優先度

P1

## 次アクション

1. payload sizeとrate limitの責務境界を設計する。
2. OpenAPIとRails実装への影響を確認する。
3. 必要なguardとRSpecを追加する。
