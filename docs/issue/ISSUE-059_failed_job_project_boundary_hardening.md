# ISSUE-059: failed job操作のProject境界を厳密化する

## Issue番号

ISSUE-059

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/88

## 背景

ISSUE-056でfailed jobの再実行/破棄APIとUIを追加した。MVPではproject admin権限と運用画面文脈を前提にしているが、Solid Queue job単体から対象Projectとの厳密な関連を常に復元できる設計にはなっていない。

世界レベルSaaSの運用操作では、operatorが別Project由来のjobを誤って操作しない境界検証が必要である。

## 目的

Product JobとSolid Queue jobの関連を明示的に保存または検証し、failed job retry/discard操作が対象Project由来であることをAPI側で厳密に確認できるようにする。

## 完了条件

- failed job操作時に対象Projectとの関連をAPI側で検証できる
- 関連が確認できないfailed jobは403または404のsafe errorで拒否される
- OpenAPI、Backend、Frontend型、RSpecが同期されている
- AuditLogにProject境界検証結果がsafe metadataとして保存される
- 既存のQueue health表示とfailed job操作UIが破綻しない
- 設計レビューと実装レビューが `docs/review/` に保存されている

## スコープ

- Product JobとSolid Queue jobの関連ID保存または検証設計
- failed job操作APIのProject境界検証
- Queue health sampleの関連情報追加
- RSpec、必要に応じたPlaywright更新
- OpenAPIと生成型同期

## 非スコープ

- bulk retry/discard
- staging/production worker smoke
- 通知、SLO、二人承認
- GitHub App live smoke

## 関連レビュー

- `docs/review/20260707_failed_job_retry_discard_operations_design_review.md`
- `docs/review/20260707_failed_job_retry_discard_operations_implementation_review.md`
- `docs/review/20260707_failed_job_followup_issue_split_review.md`

## レビュー結果

P1。ISSUE-056のMVPは合格だが、Project境界の厳密化は本番運用前に強化すべき重要課題である。Security Engineer観点では、operator UIの文脈だけに依存した境界判断は長期的に不十分である。

## 次アクション

1. 現在のProduct Job、Solid Queue job、AuditLogの関連情報を調査する。
2. 関連ID保存または検証方式の設計レビューを作成する。
3. OpenAPIから更新し、Backend実装とRSpecを追加する。
4. 必要に応じてFrontend表示とPlaywrightを更新する。
