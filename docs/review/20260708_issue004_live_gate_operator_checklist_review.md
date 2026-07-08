# 2026-07-08 ISSUE-004 live gate運用チェックリストレビュー

## 評価日時

2026-07-08 19:25:00 JST

## 評価担当

Codex / DevOps / Security Engineer / QA / Tech Lead

## Issue番号

ISSUE-004 / GitHub Issue #4

## 対象

- `docs/release/20260708_issue004_live_gate_operator_checklist.md`
- `docs/release/README.md`
- `docs/issue/ISSUE-004_github_issue_and_openapi_pipeline.md`

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- DORA Metrics
- ISO25010

## 評価サマリー

Issue #4は、アプリ側の主要実装が進んでいる一方で、GitHub App webhook URL、runtime secret、2xx delivery、DB / AuditLog同期、staging / production worker readinessの外部証跡が残っている。既存runbookは詳細だが、運用担当者が「次にどの設定を直すか」を短時間で把握するには長い。

今回、#4のlive gateだけに絞った日本語チェックリストを追加した。GitHub App側設定、runtime secret、delivery redeliver、`GithubWebhookDelivery` / AuditLog safe確認、worker readiness、safe failure対応表、レビュー保存項目、クローズ判定を一本化している。

## 良かった点

- 現在のブロッカーを冒頭にまとめ、設定作業の優先順位が分かりやすくなった。
- GitHub App settingsとrepository Installed Apps画面を混同しないよう注意を明記した。
- secret、raw payload、raw delivery id、DB URL、job argumentsを保存しない方針を繰り返し明示した。
- `GithubWebhookDelivery` とAuditLogのsafe確認runnerを追加し、証跡保存時の漏えいリスクを下げた。
- worker readinessをlocal developmentでは完了証跡にしない判断を明文化した。

## 改善点

- 実際のWebhook URL、secret store、staging環境名は環境ごとに異なるため、チェックリストだけでは設定完了まで自動化できない。
- GitHub UIの表示位置は将来変わる可能性があるため、画面名に依存しすぎず、設定対象を中心に記載している。
- DB / AuditLog確認runnerはread-onlyだが、環境権限が必要であり、運用担当者の権限管理は別Issueの範囲である。
- 成功証跡テンプレートは項目を列挙しただけで、まだ専用template fileには分離していない。

## 改善案

1. GitHub App webhook URLとruntime secret設定後、チェックリスト順にlive smokeを実行する。
2. 成功時は `docs/review/YYYYMMDD_issue004_live_gate_evidence_review.md` として証跡レビューを保存する。
3. staging / production worker readinessの成功JSONをreview docへ要約し、raw secretやDB URLが含まれないことを確認する。
4. 成功証跡が増えたら、evidence templateを別ファイル化する。

## 優先順位

| 優先度 | 項目 | 理由 |
| --- | --- | --- |
| P0 | Webhook URL / secret設定 | 2xx deliveryの前提 |
| P0 | `GithubWebhookDelivery` / AuditLog safe確認 | webhook受信がプロダクト状態へ反映された証跡 |
| P0 | staging worker readiness合格 | release gate |
| P1 | 成功証跡template化 | 繰り返し運用しやすくするため |
| P2 | GitHub UI変更時のrunbook更新 | 将来の手順陳腐化を防ぐため |

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | Issue #4の外部設定待ちを運用担当者が安全に解消できるようにする |
| Strategy | 長いrunbookとは別に、現在のブロッカー専用チェックリストを作る |
| Tactics | 設定順、検証コマンド、safe failure対応表、保存項目、クローズ判定を日本語で整理する |
| Assessment | 手順の分かりやすさは改善。ただし実外部設定と成功証跡は未完了 |
| Conclusion | チェックリストは採用。Issue #4はOPEN継続 |
| Knowledge | live gateでは実装よりも運用手順の迷いが進捗を止めるため、短い現在地チェックリストが有効 |

## STRIDE / OWASP観点

- Spoofing: webhook secret設定と署名検証をP0に置き、未設定時は完了不可とした。
- Tampering: owned endpointとSSL verificationを明記し、placeholder URLを拒否する。
- Repudiation: delivery digest、DB保存、AuditLog同期を証跡項目に含めた。
- Information Disclosure: secret、raw payload、raw delivery id、DB URL、job argumentsの保存禁止を明記した。
- Denial of Service: 502 delivery時はredeliver前にURL/secretを修正する順序にした。
- OWASP A05 Security Misconfiguration: placeholder URL、runtime secret未設定、local async adapterを未完了ブロッカーとして扱う。

## 検証結果

- `git diff --check`: 問題なし
- `npm run display:check`: Display labels OK
- 実secret値パターン確認: 検出なし

保存していない情報:

- GitHub App private key
- webhook secret
- signature
- raw payload
- raw GitHub delivery id
- `DATABASE_URL`
- `QUEUE_DATABASE_URL`
- Rails master key
- Active Record Encryption key
- raw exception / backtrace
- serialized job arguments

## 次アクション

1. チェックリストに従い、GitHub App settingsのWebhook URLをowned endpointへ変更する。
2. runtimeへ `GITHUB_WEBHOOK_SECRET` を設定する。
3. deliveryをredeliverまたは再triggerし、2xx deliveryを確認する。
4. `GithubWebhookDelivery` とAuditLog同期を確認する。
5. staging / production-equivalent worker readinessを実行し、`safe_failures` 空の証跡を保存する。

## 結論

運用担当者向けのlive gateチェックリストとしては採用可能である。ただし、これは外部設定と実環境証跡の代替ではない。Issue #4はWebhook URL、runtime secret、2xx delivery、DB / AuditLog同期、staging worker readinessが揃うまでOPENを継続する。
