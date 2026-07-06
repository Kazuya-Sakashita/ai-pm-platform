# Requirement差し戻し時の下流ドラフトstale化 設計レビュー

## 評価日時

2026-07-07 06:53 JST

## 評価担当

Codexレビュー統括 / Product Manager / CTO / Tech Lead / Backend Architect / Frontend Architect / Security Engineer / QA

外部AIレビュー: Claude、ChatGPTレビューは未実施。現時点ではCodex一次レビューとして保存し、外部AIレビュー結果が追加された場合は差分分析を追記する。

## 使用フレームワーク

- G-STACK
- DDD
- ISO25010
- STRIDE
- MoSCoW

## 対象

Issue #3の残タスクである、承認済みRequirementを再編集して承認状態が差し戻された場合に、既存のIssue DraftとOpenAPI Draftを古い成果物として扱う設計。

## 良かった点

- `RequirementRevisionService` が既にレビュー対象フィールド差分と承認リセットを判定しており、下流ドラフトstale化の起点を一箇所に集約できる。
- Issue DraftとOpenAPI DraftはRequirementに紐づいているため、対象範囲をRequirement配下に限定できる。
- Frontendには `stale` の表示ラベルが既にあり、UI側の日本語表示は小さい変更で済む。
- GitHub公開済み情報や照合履歴を削除せず、statusだけをstaleへ寄せれば監査証跡を保てる。

## 改善点

- Issue DraftとOpenAPI Draftのstatus enumに `stale` がまだないため、API契約から更新する必要がある。
- publishedやpublish_failedのIssue Draftをstale化する場合、GitHub上の既存Issue URLは残すべきで、再公開や差分更新の扱いは別Issueで設計する必要がある。
- stale化件数と対象IDをAuditLog metadataへ残さないと、なぜ下流成果物が止まったかを後から追いづらい。
- Frontendでstale状態のドラフトを再編集、再承認、再生成のどれに誘導するかはUX改善余地がある。

## 優先順位

| 優先度 | 指摘 | 改善案 |
| --- | --- | --- |
| P0 | Requirement再編集後も古いIssue/OpenAPI Draftが有効に見える | Requirement承認リセット時に関連Draftを `stale` へ更新する |
| P0 | API契約と実装のstatus enumが不足 | OpenAPI、型定義、モデル定数を先に同期する |
| P1 | 監査証跡不足 | stale化したIssue/OpenAPI Draft件数とIDをAuditLogへ保存する |
| P2 | 再生成導線の説明不足 | UIで `stale` を「再確認が必要」と表示し、次Issueで再生成差分UXを改善する |

## 次アクション

1. OpenAPIの `IssueDraftStatus` と `OpenApiDraftStatus` に `stale` を追加する。
2. 生成型を更新する。
3. `RequirementRevisionService` で承認リセット時に下流Draftを `stale` へ更新し、結果に対象IDを含める。
4. Requirements APIのAuditLog metadataへstale化結果を保存する。
5. RSpecで承認リセット時、差分なし時、下流Draftなし時を検証する。
6. Frontend E2Eで承認済みRequirement再編集後にIssue/OpenAPI Draftの表示が「再確認が必要」になることを確認する。

## Issue番号

- GitHub Issue: #3

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | 古い下流成果物が承認済みRequirementに基づく最新成果物であるかのように扱われるリスクをなくす |
| Strategy | Requirement承認リセットを境界イベントとして、配下のIssue/OpenAPI Draftをstaleへ更新する |
| Tactics | API status enum追加、Service Object更新、AuditLog metadata、RSpec、Playwright |
| Assessment | 実装へ進めてよい。ただしGitHub公開済みIssueの差分更新は今回の範囲外とする |
| Conclusion | 下流Draftを削除せずstale化する方針が、監査性と安全性のバランスとして妥当 |
| Knowledge | AI PMでは成果物の生成可否だけでなく、どの入力に基づく成果物かの鮮度管理が重要 |

## 判定

実装へ進めてよい。今回の完了条件は、API契約、Backend stale化、AuditLog、RSpec、Frontend表示/E2E、実装レビュー、Issue台帳更新までとする。
