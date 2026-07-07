# ISSUE-066: failed job retry後再失敗率を計測する

## Issue番号

ISSUE-066

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/99

## 背景

ISSUE-062でProduct JobとSolid Queue jobの明示マッピングを保存し、ISSUE-063でrelease gateに `retry_refailure_rate` を `not_measured` として表示した。retry後に同種のfailed jobへ戻る比率を測れないと、retry操作が改善に効いているか判断できない。

## 目的

retry操作後の再失敗率を計測し、無効なretryや副作用リスクの高いretryをrelease gateで検知できるようにする。

## 完了条件

- retry後再失敗率の定義、計測窓、分母/分子、除外条件が設計されている
- `job_queue_mappings` とAuditLogを使って安全に集計できる
- Queue health APIの `retry_refailure_rate` checkが `not_measured` から実測値へ更新される
- 閾値10%以上でwarningまたはblockedにする基準がレビューされている
- raw exception、serialized arguments、secret、DM本文、AI入力全文を保存しない
- RSpecと必要ならFrontend/Playwrightが追加されている
- 設計レビューと実装レビューが `docs/review/` に保存されている

## スコープ

- retry後再失敗率の集計設計
- Queue health release gate check更新
- RSpec
- 必要なOpenAPI/Frontend表示更新

## 非スコープ

- Slack実通知
- 二人承認DB/API強制
- 外部監視SaaS連携
- 長期BI分析基盤

## 関連レビュー

- `docs/review/20260707_solid_queue_product_job_mapping_implementation_review.md`
- `docs/review/20260707_failed_job_notification_approval_slo_gate_implementation_review.md`

## レビュー結果

P2。release gateの精度向上に必要だが、ISSUE-063のMVP完了条件には含めず、明示マッピングの運用データが蓄積してから実装する。

## 次アクション

1. retry後再失敗率の定義を設計レビューで確定する。
2. AuditLogと `job_queue_mappings` のjoin方針を決める。
3. Queue health release gateへ実測値を返す。
