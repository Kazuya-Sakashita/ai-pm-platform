# 2026-07-07 failed job通知・承認・SLOリリースゲート 設計レビュー

## 評価日時

2026-07-07 19:35 JST

## 評価担当

Codex L2サブエージェント一次レビュー

- Security Engineer
- QA / Release Manager
- Backend Architect
- Frontend Architect
- DevOps
- Product Manager

## Issue番号

ISSUE-063 / GitHub Issue #96

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- DORA Metrics
- ISO25010

## 対象

failed job操作の通知方針、二人承認方針、SLO閾値、Queue health release gate接続。

## 専門家サブエージェントレビュー統合

- Security Engineer: 条件付き合格。Project境界拒否、Queue health取得不能、本番retry/discard条件不足はrelease hard stopにする。通知payloadはsafe metadataに限定し、raw exception、backtrace、serialized arguments、token、database URL、DM本文、AI promptを保存しない。
- QA / Release Manager: 設計へ進行可。ただしOpenAPI、RSpec、Frontend表示、Playwright、runbook/evidence接続が完了するまで本番release gate解除は不可。
- Review Orchestrator判断: サブエージェント指摘のうち、release gate API/UI、safe notification policy、runbook接続、後続Issue分割を採用。Slack実送信、二人承認DB/API強制、retry後再失敗率の実測はISSUE-064、ISSUE-065、ISSUE-066へ分離する。
- 外部AI比較: Claude、ChatGPTなど外部AIレビューはこの環境から直接実行していない。今回はCodex L2サブエージェントレビューを一次レビューとして保存し、重要リリース判定時に外部AI比較を追加する。

## 良かった点

- 操作実行だけでなく、release gate warning/blockを通知対象に含めた。
- webhook URLやsecretを扱わず、論理チャンネル名 `operations` のみを返す設計にした。
- discardはMVPでも二人承認またはrelease owner承認を必要方針として明示した。
- Project境界拒否をrelease block扱いにして、Security Engineer確認を必須にした。
- Security/QAサブエージェントが独立してP0/P1リスクを出し、scopeをMVPと後続Issueに分けられた。

## 改善点

- 実Slack通知は未実装であり、通知失敗の自動再送もない。
- 二人承認はDB stateとしてはまだ強制されず、runbook/表示方針に留まる。
- retry後再失敗率は `not_measured` で、実計測は後続に残る。
- `operations` 論理チャンネルと実通知先の環境差分管理が未実装。
- 外部AI比較レビューは未実施である。

## 6価値軸評価

| 価値軸 | 判定 | メモ |
| --- | --- | --- |
| 強固なセキュリティ | 条件付き合格 | Project境界拒否blocked、safe notification policy、承認方針を採用。DB強制は後続 |
| 高い技術品質 | 合格 | release gate判定をServiceへ分離する方針 |
| 優れたUX | 条件付き合格 | 運用監視で次アクションが読める表示が必要 |
| 継続利用 | 合格 | 障害時の判断を画面とrunbookに残す |
| 事業価値 | 合格 | enterprise向け監査性とrelease統制に効く |
| 長期運用 | 条件付き合格 | 実通知、二人承認DB、再失敗率集計が後続で必要 |

## 優先順位

| 優先度 | 項目 | 判定 |
| --- | --- | --- |
| P0 | Queue health release gate schema | 必須 |
| P0 | Project境界拒否をblocked扱い | 必須 |
| P1 | 通知payload/prohibited fields方針 | 必須 |
| P1 | Frontendで承認方針とgateを表示 | 必須 |
| P2 | Slack実送信、二人承認DB、再失敗率集計 | 後続 |

## 次アクション

1. `FailedJobReleaseGate` serviceで判定を分離する。
2. OpenAPIへ `failed_job_release_gate` schemaを追加する。
3. Queue health API/UIへrelease gateを表示する。
4. RSpec、OpenAPI verify、display check、frontend build、Playwrightで検証する。
5. 実Slack通知と二人承認DBは後続Issueへ分割する。
