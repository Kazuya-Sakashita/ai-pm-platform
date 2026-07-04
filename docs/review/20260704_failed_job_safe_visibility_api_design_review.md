# Failed Job Safe Visibility API Design Review

## 評価日時

2026-07-04 21:17 JST

## 評価担当

Codex / CTO / Tech Lead / Backend Architect / Frontend Architect / DevOps / Security Engineer / QA / Product Manager

外部AIレビュー: 未実施。Claude、ChatGPT等の外部レビューは環境から直接実行できないため、Codex一次レビューとして保存する。

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- DORA Metrics

## Issue番号

- ISSUE-027

## 良かった点

- failed job運用UIをいきなり操作系にせず、safe visibilityに分割した。
- raw exception、backtrace、job argumentsを返さない安全境界を明確化した。
- 既存のQueue health APIを拡張するため、運用パネルの情報が分散しない。
- `active_job_id` を相関IDとして使い、詳細なsecret-bearing payloadとは切り離した。
- retry/discardは認証、operator権限、承認ログ、AuditLog後の別Issueに残した。

## 改善点

- failed jobの根本原因まではUI上で表示できず、runbook/log確認が必要。
- `active_job_id` の運用上の扱いは権限導入後に再確認が必要。
- 実staging/productionのfailed executionを使ったsmokeは未実施。
- 通知/SLO/外部監視連携は未設計。

## 優先順位

- P0: OpenAPI schemaへsafe failed job sampleを追加する。
- P0: Backendはraw error/argumentsを返さないことをspecで固定する。
- P0: Frontendで直近failed jobをread-only表示する。
- P1: retry/discard操作はoperator権限とAuditLog設計後に別Issue化する。
- P1: 実環境smokeと通知/SLOへ接続する。

## 次アクション

- GitHub Issueへ登録する。
- OpenAPIを更新する。
- Backend/Frontendを実装する。
- 実装レビューを保存する。

## G-STACK

### Goal

運用者がfailed jobの発生箇所を安全に把握できるようにする。

### Strategy

Queue health APIにsafe summaryだけを追加し、失敗原因の詳細や操作はrunbook/後続Issueへ残す。

### Tactics

- failed job sample schemaを追加する。
- Query ObjectでSolid Queue failed executionとjobをsafe fieldsへ変換する。
- raw errorとargumentsを読まない/返さない。
- Frontendはqueue/class/failed_atのみ表示する。

### Assessment

MVPの運用可視化として妥当。世界レベルSaaS基準では、通知、権限、再実行/破棄、監査ログ、実環境証跡が残る。

### Conclusion

実装へ進めてよい。ただし、操作系を混ぜないことを実装レビューで必ず確認する。

### Knowledge

Solid Queue failed executionのraw errorはsecretや外部API payloadを含み得る。運用初動に必要なqueue/class/時刻だけを返すことで、情報漏えいリスクを抑えつつ可視性を上げられる。

## STRIDE / OWASP確認

| 観点 | 評価 | 改善案 |
| --- | --- | --- |
| Spoofing | 認証未実装のため閲覧権限は未完 | ISSUE-006でoperator roleを導入 |
| Tampering | read-onlyでqueue状態を変更しない | 操作系は別Issue |
| Repudiation | 閲覧のみでAuditLogなし | retry/discard導入時にAuditLog必須 |
| Information Disclosure | raw error/argumentsを返さない | specで非表示を固定 |
| Denial of Service | 直近数件にlimitする | 将来はcache/limit設定化 |
| Elevation of Privilege | 操作を入れない | operator権限まで操作UI禁止 |

## Issue番号

- ISSUE-027
