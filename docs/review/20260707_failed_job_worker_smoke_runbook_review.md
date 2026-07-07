# 2026-07-07 failed job retry/discard worker smoke runbookレビュー

## 評価日時

2026-07-07 15:37:55 JST

## 評価担当

Codex（DevOps / Security Engineer / QA / Tech Lead）

## 使用フレームワーク

- G-STACK
- STRIDE
- DORA Metrics
- ISO25010

## 対象Issue

- ISSUE-060
- GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/89
- 関連: ISSUE-004 / GitHub Issue #4

## 対象成果物

- `docs/release/20260704_solid_queue_staging_worker_smoke_runbook.md`
- `docs/release/20260703_solid_queue_operations_runbook.md`
- `docs/review/20260707_failed_job_worker_smoke_evidence_template.md`
- `docs/issue/ISSUE-060_failed_job_worker_smoke_evidence.md`

## 評価概要

ISSUE-056でfailed job retry/discard操作は実装済みだが、実worker下の証跡を取得する手順が不足していた。今回、staging/production worker smoke runbookへfailed job操作確認を追加し、productionでは原則観測のみ、実行する場合はrelease owner承認、Project確認、reason template、AuditLog確認を必須にした。

## G-STACK

- Goal: failed job retry/discardをrelease gateで安全に確認できるようにする。
- Strategy: 実環境接続は行わず、runbook、production禁止条件、証跡テンプレートを先に整備する。
- Tactics: staging手順、production rule、evidence template、operation runbook、Issue台帳を更新する。
- Assessment: 実worker smokeそのものは未実施だが、実行時に必要な安全条件と証跡項目は定義できた。
- Conclusion: Runbook整備Issueとしては合格。#4のlive release gateはopen維持。
- Knowledge: failed job操作は「実行できること」よりも、実行してよい条件、証跡、安全な非保存項目を先に固定する。

## 良かった点

- stagingとproductionの実行条件を明確に分けた。
- production retry/discardを原則観測のみとし、実行時の承認条件を明記した。
- 証跡テンプレートに操作対象、理由テンプレート、operator、AuditLog、Queue health再取得結果を含めた。
- raw exception、backtrace、serialized job arguments、secret、database URL、DM body、AI promptを保存しない確認項目を追加した。
- #4のrelease gateと接続した。

## 改善点

- 実staging/production worker環境での実行証跡はまだない。
- safe failed jobをstagingで安定して生成する専用smoke jobは未実装である。
- Project境界の厳密検証はISSUE-059で継続する。
- 通知、SLO、action別reason templateはISSUE-061で継続する。

## 改善案

- staging環境が利用可能になったら、証跡テンプレートをコピーして実行結果を `docs/review/` へ保存する。
- safe smoke-only failed jobを作る必要があるかをISSUE-059または別Issueで判断する。
- #4のrelease判定時に、GitHub App live smokeとworker smoke evidenceを並べて確認する。
- productionでは実行より先にQueue healthとAuditLogの観測証跡を取得する。

## 優先順位

- P0: PR CI `verify` 成功確認。
- P1: GitHub Issue #4へrelease gate更新を同期する。
- P1: staging環境でevidence templateに沿った実smokeを実施する。
- P2: safe smoke-only failed job設計を検討する。

## 検証結果

- `npm run display:check`: 成功
- `git diff --check`: 成功

## 次アクション

1. PRを作成し、GitHub Actions `verify` を確認する。
2. GitHub Issue #4へrelease gate更新をコメントする。
3. GitHub Issue #89へ検証結果をコメントする。
4. Issue #89をクローズする。

## Issue番号

- ISSUE-060
- GitHub Issue #89
- 関連: GitHub Issue #4

## 判定

合格。ISSUE-060のrunbook/証跡テンプレート整備は完了可能。実staging/production実行証跡は#4のrelease gateとして継続する。
