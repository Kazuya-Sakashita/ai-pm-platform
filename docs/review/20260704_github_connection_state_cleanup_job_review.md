# GitHub Connection State Cleanup Job Review

## 評価日時

2026-07-04 13:02 JST

## 評価担当

Codex / CTO / Tech Lead / Backend Architect / Security Engineer / DevOps / QA

外部AIレビュー: 未実施。Claude、ChatGPT等の外部レビューは環境から直接実行できないため、Codex一次レビューとして保存する。

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- DORA Metrics

## Issue番号

- ISSUE-004
- GitHub Issue #4

## 良かった点

- 期限切れ `github_connection_states` を削除する `GithubIntegration::ConnectionStateCleanupJob` を追加し、state replay防止テーブルの無制限肥大化を抑えた。
- 削除条件を `GithubConnectionState.cleanup_expired!` に閉じ込め、Jobは実行入口に限定した。
- 期限切れ直後のstateは24時間保持し、callback失敗調査や監査確認の余地を残した。
- Solid Queue recurringへproduction定期実行を追加し、手動運用に依存しない形にした。
- `GithubIntegration::StateError` を独立autoload定数へ分離し、model spec単体実行でも安定するようにした。
- model spec、job spec、recurring config spec、zeitwerk checkで検証した。

## 改善点

- 削除件数はRails logに残すのみで、Product用 `jobs` tableやAuditLogには記録していない。
- retentionはJob引数で調整可能だが、環境変数や運用UIからの変更には未対応。
- productionでのSolid Queue recurring実行実績は未確認であり、staging worker smokeが必要。
- callback失敗時にstateを消費済みにする方針ADRは未作成。
- 認証/認可が未実装のため、connection start APIの利用者制御は引き続き未完了。

## 優先順位

- P0: 関連RSpecとzeitwerk checkを通し、cleanup jobが安全にautoloadされることを確認する。
- P0: ISSUE-004へcleanup実装と残タスクを同期する。
- P1: staging/production相当のSolid Queue workerでrecurring jobが実行されることをsmokeする。
- P1: callback失敗時のstate消費方針をADR化する。
- P2: cleanup実行履歴を監査ログまたは運用メトリクスへ出す。

## 次アクション

- `bundle exec rspec`、`npm run api:verify`、`npm run frontend:build` を追加で通す。
- Issue #4へcleanup job実装結果を追記する。
- live smoke成功まではISSUE-004をopen維持する。

## G-STACK

### Goal

GitHub connection stateの期限切れデータを安全に削除し、replay防止のセキュリティテーブルを運用可能な状態に保つ。

### Strategy

DB削除ルールはModel、実行責務はActiveJob、定期実行はSolid Queue recurringに分け、API surfaceは増やさない。

### Tactics

- `GithubConnectionState.cleanup_expired!` で24時間より古い期限切れstateだけを削除する。
- `GithubIntegration::ConnectionStateCleanupJob` を `default` queueで実行する。
- `config/recurring.yml` へproduction scheduleを追加する。
- `GithubIntegration::StateError` を独立ファイルへ分離する。
- model/job/config specで削除条件と定期実行定義を検証する。

### Assessment

保守性と運用品質は前進した。ただし世界レベルSaaS基準では、実worker上でのrecurring実行証跡、監査メトリクス、callback失敗方針ADRがまだ不足している。

### Conclusion

cleanup jobのMVPは実装済み。Issue #4の残タスクから「期限切れstate cleanup」は完了扱いにできるが、live GitHub App smokeとstaging worker smokeが残るためIssue #4はクローズ不可。

### Knowledge

connection stateはraw stateを保存しないため情報漏洩リスクは限定的だが、nonce/state digestもセキュリティ関連データである。即時削除ではなく24時間保持後に削除することで、再試行性と調査可能性のバランスを取った。
