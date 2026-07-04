# retention worker staging/production smoke runbookレビュー

## 評価日時

2026-07-05 07:00:43 JST

## 評価担当

Codex as CTO / Tech Lead / Backend Architect / DevOps / Security Engineer / QA / Product Manager / Release Manager

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- DORA Metrics
- ISO25010

## Issue番号

- ISSUE-033
- ISSUE-023
- ISSUE-025
- ISSUE-029

## 評価対象

- `docs/release/20260704_solid_queue_staging_worker_smoke_runbook.md`
- `docs/release/20260703_solid_queue_operations_runbook.md`
- `docs/release/README.md`

## 良かった点

- 既存のGitHub connection state cleanup smokeに、`ConversationImportRetentionJob` と `enforce_conversation_import_retention` の確認を追加した。
- stagingでは人工的なsmoke DM importだけを作成し、productionでは観測中心にする方針を明確にした。
- Queue health API/UIの確認をrunbookに入れ、worker heartbeat、failed job、recurring taskをアプリ側からも確認できるようにした。
- restore後にretention/anonymizationを再適用する手順を追加し、backupから削除済みDMが復活するリスクを下げた。
- 証跡に保存してよいもの、保存禁止のものを明記し、DM本文、ciphertext、暗号keyを残さない方針にした。

## 改善点

- 実staging/prod環境でのsmoke実行証跡はまだない。
- Queue health API/UIのproductionアクセス制御は認証/認可導入前であり、ISSUE-030の権限設計が必要。
- retention jobのdry-run modeは実装されていないため、productionでは観測中心に限定される。
- unexpected anonymizationのrollbackは実質的にbackup restore頼みであり、操作前承認とstaging検証が必須。
- 外部監視/SLO/alertへの接続は未実装。

## 優先順位

| Priority | 項目 | 理由 |
| --- | --- | --- |
| P0 | staging worker smoke実行 | runbookの実効性確認に必須 |
| P0 | restore後retention replayのrelease手順化 | backup復元時のデータ復活防止に必須 |
| P0 | Queue healthアクセス制御 | operations情報の閲覧境界に必要 |
| P1 | dry-run mode検討 | production観測だけでは期限切れ件数の安全確認に限界がある |
| P1 | SLO/alert設計 | failed jobやworker停止の検知を速くする |

## 次アクション

1. ISSUE-033へrunbook更新と未実施理由を同期する（完了）。
2. GitHub Issue #33へコメントし、CI成功後にrunbook化Issueとしてクローズする（完了）。
3. 実staging環境が用意できたら、このrunbookに従ってsmoke証跡レビューを `docs/review/` へ追加する。
4. ISSUE-030でQueue health/operations panelの閲覧権限を設計する。
5. 将来Issueでretention dry-run modeとSLO/alertを検討する。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | retention jobを実装済みから運用確認可能な状態へ進める |
| Strategy | staging実行手順、production観測手順、restore replayを同じrunbookへ統合 |
| Tactics | recurring task確認、staging runner、safe verification、Queue health API/UI、evidence templateを追加 |
| Assessment | runbookとしては合格。ただし実staging証跡がないためproduction-readyとは判定しない |
| Conclusion | ISSUE-033はrunbook化として完了可能。実環境smokeは次のrelease gateに残す |
| Knowledge | retention/anonymizationはjob実装だけでなく、worker起動、recurring load、restore replay、証跡管理まで揃って初めて信頼できる |

## STRIDE / OWASP評価

| 観点 | 評価 | 残課題 |
| --- | --- | --- |
| Spoofing | operator/環境/commitを証跡に残す方針にした | 実operator認証は未接続 |
| Tampering | smoke IDsと件数で確認し、本文を出さない | 証跡保存先の改ざん耐性は未設計 |
| Repudiation | evidence review保存を必須化した | 実staging証跡は未取得 |
| Information Disclosure | DM body/key/ciphertext保存禁止を明記した | Queue health閲覧権限はISSUE-030 |
| Denial of Service | failed job/latency/worker heartbeat確認を追加した | alert/SLOは未実装 |
| Elevation of Privilege | productionでのデータ作成を禁止した | operations権限設計は未完了 |

## 判定

条件付き合格。ISSUE-033の「runbookを実施可能にする」範囲は満たした。ただし、実staging/production worker smoke証跡は未取得であり、release gateでは別途実行レビューが必要。

## AIレビュー比較

Codex一次レビューのみ。Claude、ChatGPTなど外部AIレビューは未実施。外部レビュー結果が追加された場合は、production観測手順、dry-run mode要否、restore replayの順序を比較する。
