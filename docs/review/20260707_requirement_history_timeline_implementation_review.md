# ISSUE-050 Requirement差分履歴タイムライン実装レビュー

## 評価日時

2026-07-07

## 評価担当

Codex（Product Manager / CTO / Tech Lead / Backend Architect / Frontend Architect / Security Engineer / QA）

## 使用フレームワーク

- G-STACK
- DDD
- STRIDE
- OWASP Top 10
- ISO25010
- WCAG

## 対象

- Issue番号: ISSUE-050 / GitHub #67
- 対象ファイル:
  - `docs/api/openapi.yaml`
  - `backend/app/services/requirement_revision_service.rb`
  - `backend/app/services/requirement_history_query.rb`
  - `backend/app/controllers/api/v1/requirements_controller.rb`
  - `frontend/app/workspace-client.tsx`
  - `frontend/app/globals.css`
  - `frontend/e2e/meeting-workspace.spec.ts`

## 良かった点

- OpenAPIへ `GET /requirements/{requirement_id}/history` を先に追加し、API駆動の順番を守った。
- Controllerへ履歴統合ロジックを置かず、`RequirementHistoryQuery` に分離したため責務が明確になった。
- 差分履歴は本文全文ではなく短い安全プレビューに限定し、`SensitiveContentScanner` 検知時は本文を保存しない設計にした。
- FrontendはAuditLogとReview APIを個別に解釈せず、Requirement専用履歴APIだけを参照するためUI責務が軽い。
- RSpecで安全な差分保存と履歴API、Playwrightで主要ワークフローの履歴表示を検証した。

## 改善点

- Reviewは現在の `reviews` テーブルが状態履歴を保持しないため、作成時点と現在の解決時点を擬似的にタイムライン化している。厳密な状態遷移監査としては不十分。
- 差分プレビューは短く安全だが、変更内容の完全な比較や文字単位diffはできない。
- `SensitiveContentScanner` のルールに依存するため、未知の秘密情報や組織固有PIIを100%検知できるわけではない。
- タイムラインは全件表示であり、履歴が増えた場合のページング、フィルタ、折りたたみが未実装。

## 改善案

- Review状態変更用の監査ログまたはReviewEventテーブルを追加し、解決、リスク受容、再オープンを厳密に記録する。
- Requirement履歴APIへページングとイベント種別フィルタを追加する。
- fieldごとの安全diff方針を拡張し、配列差分は追加、削除、変更の件数を返す。
- project単位で追加のsecret/PII検知ルールを設定できるようにする。
- 履歴タイムラインのキーボード移動、折りたたみ、スクリーンリーダー向け要約を強化する。

## 優先順位

- P0: secret、不要PII、本文全文を履歴へ保存しない。対応済み。
- P1: Requirement更新、承認、レビュー作成、レビュー解決の時系列表示。対応済み。
- P1: Review状態遷移の厳密監査。未対応、追加Issue化候補。
- P2: 履歴のページング、フィルタ、折りたたみ。未対応、履歴量が増えた時点で対応。

## 次アクション

1. GitHub Issue #67へ実装内容と検証結果をコメントする。
2. PRを作成し、CI結果を確認する。
3. Review状態遷移監査を追加Issue候補として整理する。

## Issue番号

ISSUE-050 / GitHub #67

## 検証

- `npm run api:verify`: 成功。Redocly CLIからNodeバージョン警告のみ表示。
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec rspec spec/services/requirement_revision_service_spec.rb spec/requests/api/v1/requirements_spec.rb`: 19 examples, 0 failures。
- `npm run display:check`: 成功。
- `npm run frontend:build`: 成功。
- `npm run frontend:e2e -- --grep "creates a project, saves a Discord log, generates minutes, and requests review"`: 1 passed。

## 判定

条件付き合格。ISSUE-050のMVPとしては完了水準に達している。ただし、世界レベルの監査SaaSとしてはReview状態遷移のイベントソーシング、履歴ページング、組織別secret検知ルールが次の改善対象である。
