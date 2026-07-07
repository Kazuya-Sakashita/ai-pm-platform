# 2026-07-07 failed job操作後続課題Issue分割レビュー

## 評価日時

2026-07-07 15:23:47 JST

## 評価担当

Codex（DevOps / Security Engineer / Product Manager / Tech Lead / QA）

## 使用フレームワーク

- G-STACK
- RICE
- MoSCoW
- STRIDE
- DORA Metrics

## 対象Issue

- ISSUE-056
- GitHub Issue #81
- 親Issue: ISSUE-004 / GitHub Issue #4

## 評価対象

- `docs/review/20260707_failed_job_retry_discard_operations_design_review.md`
- `docs/review/20260707_failed_job_retry_discard_operations_implementation_review.md`
- `docs/issue/ISSUE-056_failed_job_retry_discard_operations.md`

## 評価概要

ISSUE-056でfailed job単体再実行/破棄MVPは完了した。一方で、実装レビューにはProject境界の厳密化、staging/production worker smoke証跡、action別理由テンプレート、二人承認、通知、SLOという後続課題が残っている。

既存OPEN Issueの #69 はOpenAI provider live比較、#4 はGitHub Issue/OpenAPI pipelineのlive smokeおよびrelease gateであり、failed job操作のProject境界や安全制御を十分に分解して追跡していない。したがって、重複を避けつつ、運用品質改善を3つのIssueへ分割する。

## G-STACK

- Goal: failed job操作MVP後の運用品質課題を、実装可能でレビュー可能なIssueへ分割する。
- Strategy: P1の安全境界、P1の実環境証跡、P2の運用安全性拡張に分ける。
- Tactics: ISSUE-059、ISSUE-060、ISSUE-061を作成し、#4との接続を明記する。
- Assessment: 分割は妥当。#4へ全て混ぜると完了判定が読みにくくなるため、子Issueとして追跡する方がよい。
- Conclusion: 3Issueを作成する。
- Knowledge: 運用操作のMVP完了後は、境界、証跡、誤操作防止を別軸で追跡する。

## RICE

| Issue | Reach | Impact | Confidence | Effort | 優先度 |
| --- | --- | --- | --- | --- | --- |
| ISSUE-059 Project境界厳密化 | 中 | 高 | 中 | 中 | P1 |
| ISSUE-060 worker smoke証跡 | 高 | 高 | 高 | 小 | P1 |
| ISSUE-061 安全制御と通知/SLO | 中 | 中 | 中 | 中 | P2 |

## MoSCoW

- Must: ISSUE-059。誤Project操作を防ぐ境界検証は本番運用前に重要。
- Must: ISSUE-060。実worker下での証跡はrelease gateに必要。
- Should: ISSUE-061。運用成熟度を上げるが、MVP完了をブロックしない。
- Won't now: bulk operation、Slack通知本実装、外部監視SaaS連携。

## 良かった点

- ISSUE-056の実装レビューで、MVP範囲と後続改善が明確に分かれていた。
- Project境界、実環境証跡、操作安全性を分割することで、Security、DevOps、QAの観点を個別に評価できる。
- #4のrelease gateと接続しつつ、#4を肥大化させない形にできる。

## 改善点

- ISSUE-056実装時点では、後続課題がGitHub Issueとして未登録だった。
- Project境界の厳密化は設計判断が必要で、先送りすると後からDB/API変更が大きくなる可能性がある。
- failed job操作の実環境証跡はcredentialや環境に依存するため、runbook整備と実行証跡を分けて扱う必要がある。
- 通知/SLOは将来の運用成熟度に重要だが、MVP範囲では見落とされやすい。

## 改善案

- ISSUE-059でProduct JobとSolid Queue jobの関連ID保存または検証方式を設計する。
- ISSUE-060でstaging/production worker smoke runbookと証跡テンプレートへretry/discard項目を追加する。
- ISSUE-061でaction別理由テンプレート、discard確認、通知、SLO候補を設計する。
- #4へ新規子Issueの関係をコメントし、release gate上の依存を可視化する。

## 優先順位

- P1: ISSUE-060。runbook整備は実credentialなしでも進められ、#4のrelease gateを前進させる。
- P1: ISSUE-059。安全境界の設計判断が必要。
- P2: ISSUE-061。MVP完了後の運用成熟度改善として扱う。

## 次アクション

1. `docs/issue/` にISSUE-059、ISSUE-060、ISSUE-061を作成する。
2. GitHub Issueとして登録し、URLをIssue台帳へ反映する。
3. GitHub Issue #4へ関連子Issueとしてコメントする。
4. PRを作成し、CIまたは軽量チェック結果を確認する。

## Issue番号

- ISSUE-059 / GitHub Issue #88
- ISSUE-060 / GitHub Issue #89
- ISSUE-061 / GitHub Issue #90
- 関連: ISSUE-004 / GitHub Issue #4

## 判定

合格。ISSUE-056の残課題は3Issueへ分割して追跡する。既存の #69 と #4 はopen維持し、新規Issueはfailed job運用品質の子課題として扱う。
