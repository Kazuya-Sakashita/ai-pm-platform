# ISSUE-033: retention worker staging/production smoke runbookを実施可能にする

## Issue番号

ISSUE-033

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/33

登録日: 2026-07-05

## 背景

ISSUE-023でSolid Queue、ISSUE-025でQueue health、ISSUE-029でConversation Import retention jobが実装された。しかし、staging/production workerでrecurring taskが読み込まれ、実際にretention jobが実行できることの証跡はまだない。

background jobはローカルspecが成功しても、本番相当のworker process、DB接続、recurring config、環境変数、監視導線が揃わないと運用品質を保証できない。

## 目的

Conversation Import retention jobを含むSolid Queue worker smoke手順をstaging/productionで実行可能なrunbookへ更新し、実行証跡を保存できる状態にする。

## 完了条件

- `docs/release/` のworker smoke runbookにretention job確認手順が追加されている
- queue health UI/APIで確認すべき項目が明記されている
- staging実行時に残す証跡テンプレートがある
- production実行時の安全確認、dry-run、rollback基準がある
- 実staging/prod未実施の場合は未実施理由と必要権限が明記されている
- レビュー結果が `docs/review/` に保存されている
- ISSUE-023、ISSUE-025、ISSUE-029へ同期している

## スコープ

- Solid Queue worker smoke runbook更新
- Conversation Import retention job smoke手順
- queue health確認手順
- staging/production証跡テンプレート
- リリースレビュー

## 非スコープ

- 実staging環境の構築
- production secret投入
- worker autoscaling実装
- 外部監視SaaS導入

## 関連レビュー

- `docs/review/20260704_solid_queue_staging_worker_smoke_runbook_review.md`
- `docs/review/20260704_queue_health_monitoring_implementation_review.md`
- `docs/review/20260705_discord_dm_retention_delete_implementation_review.md`

## レビュー結果

ISSUE-029のレビューではretention jobの実装は完了。ただしstaging worker smokeの対象に含める作業が残っている。ISSUE-025でも実staging/production worker smoke証跡が未実施として残っている。

## 優先度

P0

理由:

- retention jobは実行されなければ削除/匿名化SLOを満たせない
- worker停止やrecurring未ロードはproduction data riskになる
- GitHub App実機がなくても進められる運用品質改善である

## 次アクション

1. 既存のworker smoke runbookを確認する。
2. retention jobのdry-run/実行/確認手順を追記する。
3. レビューとIssue同期を保存する。
4. staging環境が用意できた時点で実行証跡を追加する。
