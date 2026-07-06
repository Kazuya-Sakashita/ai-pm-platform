# ISSUE-050 Requirement差分履歴タイムライン設計レビュー

## 評価日時

2026-07-07

## 評価担当

Codex（Product Manager / Tech Lead / Backend Architect / Frontend Architect / Security Engineer / QA）

## 使用フレームワーク

- G-STACK
- DDD
- STRIDE
- OWASP Top 10
- ISO25010

## 対象

- Issue番号: ISSUE-050 / GitHub #67
- 対象領域: Requirement差分履歴、レビュー履歴、監査タイムライン

## 良かった点

- 既存の `AuditLog` と `Review` があるため、新規テーブルを増やさずに監査タイムラインを構築できる。
- Requirement再編集、承認差し戻し、下流Draft stale化はすでに監査ログへ残っており、履歴APIの入力情報として再利用しやすい。
- UI上ではRequirement Workspace内に履歴を置けるため、承認判断と差分確認の導線が近い。

## 改善点

- 現状の `requirement.updated` は変更フィールド名しか保持せず、変更前後の差分を追えない。
- 差分全文をAuditLogへ保存すると、secret、個人情報、会議由来の不要情報が長期保存されるリスクがある。
- Reviewは現在状態のみを持つため、厳密な状態遷移履歴を完全復元できない。
- 専用履歴APIがないため、FrontendがAuditLogとReview APIを個別に解釈すると責務が分散する。

## 改善案

- `RequirementRevisionService` で変更前後の値を短い安全プレビューへ変換し、`field_changes` としてAuditLog metadataへ保存する。
- `SensitiveContentScanner` に引っかかる値は本文を保存せず、`redacted: true` と件数だけを保存する。
- `RequirementHistoryQuery` を追加し、AuditLogとReviewを統合したRequirement専用履歴APIを返す。
- Reviewは現行データ構造の範囲で、作成イベントと解決済み/リスク受容イベントをタイムライン化する。厳密な変更履歴は将来Issueで追加する。
- Frontendは履歴専用APIだけを参照し、監査ログ構造への依存を持たない。

## 優先順位

- P0: raw secret、不要PII、本文全文を履歴へ保存しない。
- P0: OpenAPI契約を先に追加し、Frontend型を同期する。
- P1: Requirement更新、承認、レビュー作成、レビュー解決を同じタイムラインで確認できる。
- P1: RSpecで安全な差分保存と履歴APIを検証する。
- P2: Playwrightで主要ワークフロー上の履歴表示を検証する。

## 次アクション

1. OpenAPIへ `GET /requirements/{requirement_id}/history` と履歴スキーマを追加する。
2. `RequirementRevisionService` へ安全な差分プレビューを追加する。
3. `RequirementHistoryQuery` とController actionを追加する。
4. Requirement Workspaceへ履歴タイムラインを追加する。
5. RSpec、Playwright、表示文言チェック、OpenAPI型生成を実行する。

## Issue番号

ISSUE-050 / GitHub #67

## 判定

条件付きで実装へ進める。条件は、保存する差分を安全プレビューに限定し、履歴APIの責務をQuery Objectへ分離することである。
