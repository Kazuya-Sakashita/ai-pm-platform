# Queue Health API Design Review

## 評価日時

2026-07-04 21:10 JST

## 評価担当

Codex / CTO / Tech Lead / Backend Architect / Frontend Architect / DevOps / Security Engineer / QA / Product Manager

外部AIレビュー: 未実施。Claude、ChatGPT等の外部レビューは環境から直接実行できないため、Codex一次レビューとして保存する。

## 使用フレームワーク

- G-STACK
- DORA Metrics
- ISO25010
- STRIDE
- OWASP Top 10

## Issue番号

- ISSUE-025

## 良かった点

- ISSUE-023で非スコープだったqueue管理画面を、まずread-only監視MVPとして切り出した。
- failed job再実行/破棄を非スコープにし、認証/承認ログなしで危険な運用操作を実装しない判断にした。
- Solid Queue table未準備時にも `unavailable` を返す方針にし、開発/preview環境での500を避ける設計にした。
- raw job arguments、raw exception、DB URL、state digest、tokenを返さない安全境界を定義した。
- DORA/運用観点でworker heartbeat、failed count、queue latency、recurring taskを最小監視指標にした。

## 改善点

- MVPでは固定thresholdであり、環境別SLOや通知先は未設計。
- failed executionの詳細、再実行、破棄は未実装で、運用者はrunbookとDB確認に戻る必要がある。
- 認証/認可が未実装のため、API公開範囲は今後ISSUE-006で制御が必要。
- 外部監視SaaS、alert routing、on-call escalationとはまだ連携していない。
- Solid Queue内部schemaへの依存があるため、gem upgrade時にrequest specで回帰検知する必要がある。

## 優先順位

- P0: OpenAPI contractへread-only queue health endpointを追加する。
- P0: Backend APIはsafe fieldsのみ返し、未準備時も500にしない。
- P0: Frontendに手動更新可能な運用監視パネルを追加する。
- P1: failed job再実行/破棄は認証/承認ログ設計後に別Issue化する。
- P1: queue latency / failed count / heartbeatの通知設計を追加する。
- P2: SLO thresholdを環境別設定へ移す。

## 次アクション

- ISSUE-025をGitHub Issueへ登録する。
- OpenAPIを更新し、型生成を通す。
- Backend query/serviceとrequest specを追加する。
- Frontend運用パネルとmock E2Eを追加する。
- 実装レビューを `docs/review/` へ保存する。

## G-STACK

### Goal

AI PM Platformのbackground job運用状態を、運用者がアプリ内で安全に把握できるようにする。

### Strategy

read-only APIに限定し、Solid Queueの内部情報をsafe summaryへ変換する。操作系は認証と承認ログが整うまで実装しない。

### Tactics

- Queue health queryをControllerから分離する。
- OpenAPIでresponse schemaを固定する。
- Product jobs summaryとSolid Queue summaryを分ける。
- Frontendは手動更新中心にし、自動pollingはMVPでは行わない。
- E2Eはmock APIでdegraded状態の表示を固定する。

### Assessment

運用監視の第一歩として妥当。ただし世界レベルSaaS基準では、外部監視、alert、権限、failed job操作、staging/production証跡まで必要であり、ISSUE-025だけで運用完成とは扱わない。

### Conclusion

API設計は実装へ進めてよい。破壊的操作を入れないこと、safe fieldsに限定すること、未準備環境を500にしないことを実装レビューで確認する。

### Knowledge

Solid Queueは運用に必要なprocess、job、failed execution、recurring task tableを持つが、そのまま外部へ出すとargumentsやexception detailの情報漏えいリスクがある。必ずsafe summaryへ変換する。

## STRIDE / OWASP確認

| 観点 | 評価 | 改善案 |
| --- | --- | --- |
| Spoofing | 認証未実装のためAPI公開範囲に注意 | ISSUE-006でoperator権限を追加 |
| Tampering | read-onlyなのでqueue状態を変更しない | 操作系は別Issueで承認ログ必須 |
| Repudiation | 今回は閲覧のみで監査ログなし | 操作系導入時にAuditLogへ接続 |
| Information Disclosure | raw args、exception、secretを返さない | serializerでsafe fieldsを固定 |
| Denial of Service | 集計queryは軽量・件数制限付きにする | pagination/limitとcacheを検討 |
| Elevation of Privilege | 操作系なし | operator role導入まで再実行UIは禁止 |

## Issue番号

- ISSUE-025
