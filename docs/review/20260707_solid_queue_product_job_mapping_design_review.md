# 2026-07-07 Product Job / Solid Queue明示マッピング 設計レビュー

## 評価日時

2026-07-07 18:59 JST

## 評価担当

Codex一次レビュー

- Security Engineer
- Backend Architect
- Tech Lead
- QA
- Product Manager

## Issue番号

ISSUE-062 / GitHub Issue #94

## 使用フレームワーク

- G-STACK
- DDD
- STRIDE
- ISO25010

## 対象

Product JobとSolid Queue jobの明示マッピング設計。

## G-STACK

- Goal: failed job操作のProject境界検証をActiveJob arguments依存から脱却する。
- Strategy: enqueue時にProduct JobとSolid Queue jobの対応を永続化し、Resolverで明示マッピングを優先する。
- Tactics: ADR-0018、mapping table、Resolver更新、Queue health/OpenAPI更新、RSpecで検証する。
- Assessment: 新規mapping tableは履歴保持と一意lookupの両方を満たす。Product Jobへの単一ID追加より安全。
- Conclusion: 新規mapping table方式で実装へ進む。
- Knowledge: 運用操作の境界検証は、payload推測より明示的な関連IDを優先すべきである。

## 良かった点

- 同一Product Jobの複数rescheduleを履歴として扱える。
- 既存jobはarguments fallbackで段階移行できる。
- Project境界検証、Queue health、AuditLogの根拠を統一できる。
- retry後再失敗率などSLO計測の前提を作れる。

## 改善点

- mapping保存失敗時の運用検知は、ISSUE-063の通知/SLO gateと接続する必要がある。
- 既存failed executionの過去データは明示mappingを持たないため、当面fallbackが残る。
- UIでは明示mappingかfallbackかを運用者に見せないと、信頼度が伝わりにくい。

## 改善案

- Queue health sampleにmapping sourceを追加する。
- AuditLog metadataへmapping sourceを保存する。
- mapping保存失敗時は秘密情報を含まないAuditLogを残す。
- ISSUE-063でmapping missing rateやretry後再失敗率をSLO候補へ接続する。

## 優先順位

| 優先度 | 項目 | 判定 |
| --- | --- | --- |
| P0 | mapping table追加 | 必須 |
| P0 | Resolverの明示mapping優先化 | 必須 |
| P1 | Queue health / AuditLogへのmapping source表示 | 必須 |
| P1 | enqueue時mapping保存 | 必須 |
| P2 | mapping保存失敗通知 | ISSUE-063で継続 |

## 次アクション

1. OpenAPIへmapping sourceを追加する。
2. DB migrationとmodelを追加する。
3. ReconciliationRetrySchedulerでmappingを保存する。
4. FailedJobProjectResolverとQueueHealthQueryを更新する。
5. RSpec、api verify、実装レビューを実施する。
