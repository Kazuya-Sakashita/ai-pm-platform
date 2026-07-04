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
- `docs/review/20260705_retention_worker_smoke_runbook_review.md`

## レビュー結果

ISSUE-029のレビューではretention jobの実装は完了。ただしstaging worker smokeの対象に含める作業が残っている。ISSUE-025でも実staging/production worker smoke証跡が未実施として残っている。

2026-07-05に `docs/release/20260704_solid_queue_staging_worker_smoke_runbook.md` を更新し、`enforce_conversation_import_retention` recurring task、`ConversationImportRetentionJob` staging smoke、Queue health API/UI確認、restore後retention/anonymization replay、production観測ルール、証跡テンプレートを追加した。

良かった点:

- GitHub App credentialなしでretention workerを確認できる手順になった。
- productionではsmoke DM importを作らず、観測中心にした。
- DM本文、ciphertext、暗号keyを証跡へ保存しないルールを明記した。
- backup restore後にretention/anonymizationを再適用する手順を追加した。

改善点:

- 実staging/prod環境での実行証跡は未取得。
- Queue health/operations panelの閲覧権限はISSUE-030待ち。
- retention jobのdry-run modeは未実装。

検証結果:

- `git diff --check`: pass
- GitHub Actions CI: push後に確認予定

実staging/prod未実施理由:

- このローカル環境にはstaging/production worker環境、deployment権限、production secret、KMS/backup provider設定がないため、実行証跡は取得していない。
- 実行にはrelease owner承認、staging/prod URL、worker process access、queue DB read access、本文を露出しないログ閲覧権限が必要。

## 優先度

P0

理由:

- retention jobは実行されなければ削除/匿名化SLOを満たせない
- worker停止やrecurring未ロードはproduction data riskになる
- GitHub App実機がなくても進められる運用品質改善である

## 次アクション

1. 既存のworker smoke runbookを確認する（完了）。
2. retention jobのdry-run/実行/確認手順を追記する（完了。dry-runは未実装のためproductionは観測中心）。
3. レビューとIssue同期を保存する（実施中）。
4. staging環境が用意できた時点で実行証跡を追加する。
