# 2026-07-07 failed job操作安全制御 設計レビュー

## 評価日時

2026-07-07 16:35 JST

## 評価担当

Codex一次レビュー

- Security Engineer
- Product Manager
- Backend Architect
- Frontend Architect
- QA

## Issue番号

ISSUE-061 / GitHub Issue #90

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- HEART
- ISO25010

## 対象

failed job retry/discard操作の安全制御、運用履歴、SLO候補、UI確認導線のMVP設計。

## G-STACK

- Goal: failed job操作の誤操作、説明不足、検知遅れを減らす。
- Strategy: action別理由テンプレート、discard確認必須、AuditLog由来の運用履歴、24時間操作メトリクスを最小追加する。
- Tactics: OpenAPIでretry/discard requestを分離し、Backend Serviceでaction別validationを行い、Queue health responseへsafe metrics/historyを追加する。
- Assessment: Slack通知や外部監視を入れずに、既存の運用監視画面とAuditLogで安全性を上げる設計はMVPとして妥当。
- Conclusion: 実装へ進む。二人承認、外部通知、SLOアラートはISSUE-063 / GitHub Issue #96へ分離する。
- Knowledge: irreversibleに近いdiscardは、理由選択だけでなく明示確認をAPI側でも必須にする必要がある。

## 良かった点

- retry理由とdiscard理由を分離し、誤った理由テンプレートをAPI側で拒否する。
- discardはUIチェックだけでなく、API requestの `discard_safety_confirmed` を必須にする。
- free-form理由を導入せず、AuditLogにsecretやPIIが混入する余地を増やさない。
- 既存AuditLogを運用履歴として利用し、新規通知基盤なしで追跡性を改善する。
- Queue healthに24時間のretry/discard/rejected件数を返し、SLO候補の土台を作る。

## 改善点

- 外部通知やアラート閾値の自動判定はまだない。
- discardの二人承認は未実装であり、本番高リスク操作では追加が必要。
- AuditLog履歴は既存画面の補助であり、専用の運用履歴検索UIではない。
- 再失敗率は今回のMVPでは正確に計算しない。

## 改善案

- ISSUE-063 / GitHub Issue #96で、二人承認とSlack通知の実装範囲を決める。
- failed job操作後の再失敗をProduct JobまたはSolid Queue明示マッピングと接続して計測する。
- 運用履歴専用のフィルタUIを作り、rejected、discard、retryを検索できるようにする。
- SLO候補をrelease gateへ接続し、継続監視の閾値を文書化する。

## 優先順位

| 優先度 | 項目 | 理由 |
| --- | --- | --- |
| P0 | action別理由テンプレート | 誤った説明での操作を防ぐ |
| P0 | discard確認必須 | 不可逆操作の誤実行を減らす |
| P1 | safe運用履歴 | 操作結果と拒否を追跡できる |
| P1 | 24時間メトリクス | SLO候補の土台になる |
| P2 | 外部通知、二人承認 | ISSUE-063 / GitHub Issue #96で継続 |

## 次アクション

1. OpenAPIでretry/discard requestとQueue health安全履歴を定義する。
2. Backend Serviceでaction別validationとdiscard確認を実装する。
3. Queue health QueryでAuditLog由来のsafe metrics/historyを返す。
4. Frontendで理由selectをaction別に分け、discard確認チェックを追加する。
5. RSpec、Playwright、実装レビュー、Issue台帳を更新する。
