# ISSUE-062: Product JobとSolid Queue jobの明示マッピングを保存する

## Issue番号

ISSUE-062

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/94

## 背景

ISSUE-059では、既存job互換を優先し、Solid Queue job argumentsからProduct Job ID候補を復元する方式でfailed job操作のProject境界を強化した。

この方式はMVPとして有効だが、ActiveJobの引数形式に依存する。将来、job引数の構造変更、複数Product Job IDの混入、別種jobの追加が発生すると、境界復元が不安定になる可能性がある。

世界レベルSaaSの本番運用では、運用操作対象のProject境界を偶然の引数構造に依存させず、監査可能な関連IDとして保存する必要がある。

## 目的

Product JobとSolid Queue jobの関連を明示的に保存し、Queue health表示、failed job retry/discard、AuditLogで安定したProject境界検証を行えるようにする。

## 完了条件

- Product Job IDとSolid Queue job IDの保存方式がADRまたは設計書に記録されている
- GitHub reconciliation retryなど既存Product Job enqueue時に関連IDを保存できる
- failed job操作時に明示マッピングを優先してProject境界を検証できる
- 既存jobやマッピング欠落時のfallback方針が安全側で定義されている
- Queue health sampleが明示マッピングを使ってProject別に安定表示できる
- OpenAPI、Backend、Frontend型、RSpecが必要に応じて同期されている
- 設計レビューと実装レビューが `docs/review/` に保存されている

## スコープ

- Product JobとSolid Queue jobの明示マッピング設計
- DB schemaまたは既存テーブル活用方針の決定
- enqueue時の関連ID保存
- failed job境界検証Resolverの明示マッピング優先化
- Queue health sampleの安定化
- RSpecと必要なAPI契約更新

## 非スコープ

- retry/discardの二人承認
- 通知、SLO、運用履歴UI
- bulk retry/discard
- staging/production worker smoke
- 外部監視SaaS連携

## 関連レビュー

- `docs/review/20260707_failed_job_project_boundary_design_review.md`
- `docs/review/20260707_failed_job_project_boundary_implementation_review.md`

## レビュー結果

P2。ISSUE-059のMVPは合格だが、ActiveJob arguments依存は長期運用で脆い。Security EngineerとBackend Architect観点では、本番運用前またはfailed job操作対象が増える前に、明示マッピングへ移行できる設計を準備すべきである。

## 次アクション

1. 既存のProduct `jobs`、Solid Queue tables、ActiveJob enqueue時点の取得可能IDを調査する。
2. 新規マッピングテーブル、Product Jobへのsolid_queue_job_id追加、AuditLog補完の3案を比較する。
3. ADRを作成し、選定理由とfallback方針を記録する。
4. OpenAPI、Backend、RSpecの変更範囲を確定する。
5. 実装後、ISSUE-059のResolverが明示マッピングを優先することを確認する。
