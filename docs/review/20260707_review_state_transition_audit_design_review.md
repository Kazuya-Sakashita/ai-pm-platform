# ISSUE-054 Review状態遷移の厳密監査 設計レビュー

## 評価日時

2026-07-07 07:57 JST

## 評価担当

Codex（Review Orchestrator）

専門家サブエージェント:

- Archimedes（Security Engineer / QA）
- Mill（Backend Architect / API Architect）

## 使用フレームワーク

- G-STACK
- DDD
- ADR
- STRIDE
- OWASP Top 10
- ISO25010

## Issue番号

ISSUE-054 / GitHub #73

## 対象

- `docs/issue/ISSUE-054_review_state_transition_audit.md`
- `backend/app/models/review.rb`
- `backend/app/controllers/api/v1/reviews_controller.rb`
- `backend/app/models/audit_log.rb`
- `backend/app/services/requirement_history_query.rb`
- `docs/api/openapi.yaml`
- `backend/app/services/open_api_draft_review_gate_service.rb`
- `backend/app/services/github_issue_publish/reconciliation_service.rb`
- `backend/app/services/github_issue_publish/manual_reconciliation_service.rb`

## 現状評価

`reviews` は現在状態のみを保持し、状態履歴は持たない。`ReviewsController` は `create`、`resolve_action`、`accept_risk` で `Review` を直接作成・更新しており、状態遷移イベントは保存していない。`RequirementHistoryQuery` は `Review.created_at` と `Review.updated_at` からレビュー依頼、解決、リスク受容を擬似的に組み立てているため、actor、理由、途中の `action_required`、再オープンを厳密に復元できない。

また、Review状態変更はControllerだけでなく、OpenAPI検証ゲート、GitHub publish reconciliation、manual reconciliation serviceからも直接行われている。Controllerだけにイベント記録を追加すると監査漏れが残る。

## 良かった点

- Review target typeとstatus enumが既にOpenAPIとModelに存在し、状態遷移イベントの契約化に進みやすい。
- `current_actor_id` とProject membership認可が共通Controllerにあり、actorつき監査イベントの入力情報は揃っている。
- `AuditLog` がproject単位の監査ログとして存在し、ReviewEventとの連携先になる。
- `RequirementHistoryQuery` が既にFrontendから監査ログ構造を隠しており、ReviewEvent統合先として適切。

## 改善点

- `Review.update!` が複数箇所に散っており、状態遷移のルール、actor、理由、Issue番号の保存が統制されていない。
- `ResolveReviewActionRequest` と `AcceptReviewRiskRequest` に最大長や安全要約のルールがなく、長文や不要PIIが監査イベントに流入しやすい。
- `AuditLog.metadata` は自由なJSONであり、Review状態遷移の厳密なsource of truthにするとスキーマ保証が弱い。
- `RequirementHistoryItem` の `source_type` と `event_type` は現行の擬似Reviewイベント前提で、`action_required` と `reopened` を表現できない。

## 推奨データモデル

`review_state_events` テーブルと `ReviewStateEvent` modelを追加する。`AuditLog` はproject activity feed、`ReviewStateEvent` はReview domainの状態遷移source of truthとして分ける。

必須カラム案:

- `id: uuid`
- `review_id: uuid, null: false, foreign_key`
- `project_id: uuid, null: false, foreign_key`
- `target_type: string, null: false`
- `target_id: string, null: false`
- `event_type: string, null: false`
- `from_status: string`
- `to_status: string, null: false`
- `actor_id: string, null: false`
- `reason_code: string`
- `reason_summary: string`
- `issue_numbers: jsonb, null: false, default: []`
- `metadata: jsonb, null: false, default: {}`
- `occurred_at: datetime, null: false`
- `created_at / updated_at`

`event_type` は `review_requested`、`review_action_required`、`review_resolved`、`review_risk_accepted`、`review_reopened` を最小セットにする。`reason_summary` は安全な短文に限定し、レビュー本文全文、secret、不要PII、長文resolution noteを保存しない。必要な詳細は `reason_code` とsafe metadataで表現する。

## API契約

- `GET /reviews/{review_id}/events` を追加し、Review状態遷移イベントを時系列で返す。
- `ReviewResponse` には後方互換として任意の `last_event` を追加できる。ただし、一覧取得で全イベントをネストしない。
- `POST /reviews/{review_id}/reopen` を追加し、再オープンを明示操作にする。汎用 `PATCH status` は避ける。
- `ResolveReviewActionRequest`、`AcceptReviewRiskRequest`、`ReopenReviewRequest` に `reason_code`、`reason_summary`、`linked_issue_number` または `issue_numbers`、`maxLength` を定義する。
- `accepted_risk.approved_by` はクライアント入力ではなく `current_actor_id` を優先する。表示名が必要なら別フィールドで扱う。
- `RequirementHistoryItem.source_type` は `review_event` を追加し、`event_type` に `review_action_required` と `review_reopened` を追加する。

## 責務分離

- Controller: 認証、認可、target project解決、入力受け取り、レスポンス返却に限定する。
- `ReviewTransitionService`: Review作成・状態更新・ReviewStateEvent作成・必要なAuditLog作成を同一transactionで行う。
- `ReviewTargetProjectResolver`: 現在Controllerにある `project_for_review_target` を移す候補。複数サービスから使う場合のみ切り出す。
- `ReviewStateEventSerializer`: OpenAPI response用JSONを定義する。
- `RequirementHistoryQuery`: `Review` の現在状態推測をやめ、`ReviewStateEvent` を読む。
- `AuditLog`: 状態遷移のsource of truthにしない。必要なら `action: review.state_changed`、`metadata: { review_id, event_id, from_status, to_status }` 程度のsafe metadataだけを保存する。

ActiveRecord callbackでイベントを自動生成する案は避ける。actor、理由、Issue番号、外部サービス由来のsafe metadataが必要であり、callbackでは文脈が欠けやすい。

## 過剰設計リスク

- 本格的なevent sourcingやCQRSへ広げすぎない。今回必要なのはReview状態遷移のappend-only監査であり、Review全属性の再構築ではない。
- workflow engineやstate machine gemはまだ不要。遷移は少数で、Service Objectの明示的メソッドで十分。
- targetごとの専用イベントテーブルは不要。Review targetは既にpolymorphic文字列で運用されているため、`review_state_events` へ集約する。
- イベントにReview本文や改善提案全文を毎回snapshot保存しない。監査価値より情報漏えいと肥大化のリスクが高い。

## migration方針

1. `review_state_events` を追加し、indexは `review_id + occurred_at`、`project_id + occurred_at`、`target_type + target_id + occurred_at`、`event_type + occurred_at` を貼る。
2. 既存Reviewをbackfillする。全Reviewに `review_requested` を `created_at` で作成し、現在状態が `action_required`、`resolved`、`accepted_risk` の場合は追加イベントを `updated_at` または `accepted_risk.accepted_at` で作成する。
3. backfillイベントは `actor_id: "system"` または `"unknown"`、`reason_code: "legacy_backfill"`、`metadata: { backfilled: true }` として、厳密なactor不明を隠さない。
4. アプリコードを `ReviewTransitionService` 経由に変更し、Review更新とイベント作成をtransaction化する。
5. `RequirementHistoryQuery` をReview推測からReviewStateEvent参照へ切り替える。

## テスト観点

- Request spec: create、resolve、accept-risk、reopenでReviewStateEventがactor、from/to status、理由、Issue番号つきで作成される。
- 権限spec: editor、viewer、cross-project actor、未認証ではReviewもEventも作成・更新されない。
- Service spec: OpenAPI validation blocker、GitHub reconciliation blocker、manual reconciliationが `ReviewTransitionService` 経由でイベントを残す。
- Requirement history spec: `review_action_required`、`review_resolved`、`review_risk_accepted`、`review_reopened` が発生順に表示され、擬似 `updated_at` 依存が消える。
- 安全性spec: reason、resolution note、accepted risk reasonにsecret風文字列や長文が入っても、イベントにはsafe summary、redacted flag、件数だけが残る。
- migration/backfill確認: 既存Reviewから最低限のイベントが作成され、actor不明が `legacy_backfill` として明示される。
- OpenAPI検証: `npm run api:verify` と生成型同期。
- Frontend/Playwright: Requirement履歴に状態遷移イベントが表示され、レビュー依頼、対応要求、解決、リスク受容、再オープンが日本語表示で崩れない。

## 優先順位

- P0: Review状態更新の入口をService Objectに集約し、状態更新とイベント作成をtransaction化する。
- P0: secret、不要PII、長文レビュー本文をReviewStateEventへ保存しない契約と検証を入れる。
- P1: RequirementHistoryQueryをReviewStateEvent参照に切り替える。
- P1: OpenAPIへReviewEvent schema、events endpoint、reopen endpoint、履歴event_type追加を反映する。
- P2: AuditLogへのsummary連携と一覧ページングを追加する。

## 専門家サブエージェントレビュー統合

### Security Engineer / QA

判定: 不合格。ISSUE-054実装前の現状は、厳密監査として未完了。

採用したP0指摘:

- `accept_risk.approved_by` がクライアント入力由来であり、Spoofing/Repudiationリスクがある。
- `resolution_note`、`accepted_risk.reason`、`accepted_risk.residual_risk`、Review本文配列にsecret/PIIを保存しない強制策が不足している。

採用方針:

- リスク受容者は `current_actor_id` からサーバー側で設定する。
- ユーザー入力のReview本文、解決メモ、リスク受容理由、残存リスクは `SensitiveContentScanner` で検査し、検知時は422で保存しない。
- システム生成文言はredact modeで安全化する。

### Backend Architect / API Architect

判定: 条件付き設計承認。

採用した指摘:

- `AuditLog.metadata` ではなく、専用の `review_state_events` をsource of truthにする。
- `ReviewTransitionService` に状態更新とイベント作成を集約する。
- `GET /reviews/{review_id}/events` と `POST /reviews/{review_id}/reopen` を追加する。
- `RequirementHistoryQuery` はReview現在状態推測ではなくReviewStateEventを読む。

### 衝突分析

大きな衝突はない。Security/QAは完了判定不可、Backend/APIは条件付き承認だったが、両者とも専用イベントテーブル、Service Object集約、secret/PII非保存を要求しており方向性は一致した。

### 外部AIレビュー

Claude、ChatGPTなど外部AIレビューはこの環境から直接実行していない。今回はCodex L2サブエージェントレビューを一次レビューとして保存し、外部AI比較は将来の重要リリース判定時に実施する。

## 次アクション

1. OpenAPIへ `ReviewStateEvent`、`GET /reviews/{review_id}/events`、`POST /reviews/{review_id}/reopen`、履歴event_type追加を先に定義する。
2. `review_state_events` migrationとbackfill方針を実装前レビューする。
3. `ReviewTransitionService` のpublic APIを `request_review`、`mark_action_required`、`resolve`、`accept_risk`、`reopen` に絞る。
4. OpenAPI検証ゲートとGitHub reconciliation系の直接 `Review.update!` をService経由へ移す。
5. RSpec、Playwright、OpenAPI verify、表示文言チェックを実行し、実装レビューを保存する。

## 判定

条件付きで設計承認。条件は、`AuditLog.metadata` ではなく専用の `review_state_events` をsource of truthにすること、状態更新の入口をService Objectへ集約すること、イベントにraw secret、不要PII、長文レビュー原文を保存しないこと。これを満たせば、ISSUE-054はAGENTS.mdのAPI駆動・監査可能ワークフロー方針に沿って実装へ進められる。
