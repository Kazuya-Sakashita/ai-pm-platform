# ISSUE-050: Requirement差分履歴とレビュー履歴タイムラインを実装する

## Issue番号

ISSUE-050

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/67

登録日: 2026-07-07
状態: OPEN（実装完了、PR CI確認待ち）

## 背景

Requirement再編集、承認差し戻し、レビュー解決、下流Draft stale化の監査情報は増えているが、ユーザーが時系列で差分と判断根拠を追える画面とAPIが不足している。

## 目的

Requirementの変更差分、承認状態変更、レビュー対応履歴を監査可能なタイムラインとして確認できるようにする。

## 完了条件

- Requirementの重要フィールド変更前後を安全に追跡できる
- AuditLogまたは専用履歴APIから差分履歴を取得できる
- Requirement Workspaceで履歴を時系列表示できる
- raw secretや不要なPIIを履歴に保存しない
- 設計レビュー、実装レビュー、RSpec、Playwrightを保存する

## スコープ

- Requirement差分履歴
- 承認リセット履歴
- Review解決履歴の表示
- 監査ログとの整合

## 非スコープ

- GitHub Issue本文の自動更新
- OpenAI provider導入
- 複数人同時編集のリアルタイム競合解決

## 関連レビュー

- `docs/review/20260707_requirement_revision_reset_review.md`
- `docs/review/20260707_requirement_blocker_details_implementation_review.md`
- `docs/review/20260707_downstream_draft_stale_implementation_review.md`
- `docs/review/20260707_requirement_followup_issue_split_review.md`
- `docs/review/20260707_requirement_history_timeline_design_review.md`
- `docs/review/20260707_requirement_history_timeline_implementation_review.md`

## レビュー結果

差分履歴は、監査性とレビュー品質を上げるP1改善である。単なるUI改善ではなく、保存する値の安全性、PII/secret除外、AuditLogとの責務分離を先に設計する必要がある。

## 優先度

P1

## 実装前アクション

1. 差分保存方式を設計する。
2. PII/secretを保存しない履歴スキーマをレビューする。
3. API契約を作成する。
4. Backend、Frontend、RSpec、Playwrightの順で実装する。

## 実装メモ

2026-07-07 07:42 JST追加:

- `GET /api/v1/requirements/{requirement_id}/history` を追加し、Requirement更新、承認、レビュー依頼、レビュー解決を時系列で取得できるようにした。
- `RequirementRevisionService` で変更前後の値を安全な短いプレビューに変換し、secret、個人情報、法務・金融情報などの検知時は本文を保存しないようにした。
- `RequirementHistoryQuery` を追加し、ControllerからAuditLogとReviewの統合ロジックを分離した。
- Requirement Workspaceへ `Requirement履歴タイムライン` を追加した。
- OpenAPI型を `frontend/lib/api/schema.d.ts` へ再生成した。
- 厳密なReview状態遷移監査は ISSUE-054 / GitHub #73 として分離した。

## 検証結果

- `npm run api:verify`
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec rspec spec/services/requirement_revision_service_spec.rb spec/requests/api/v1/requirements_spec.rb`
- `npm run display:check`
- `npm run frontend:build`
- `npm run frontend:e2e -- --grep "creates a project, saves a Discord log, generates minutes, and requests review"`

## 次アクション

1. PR CIとmain CIを確認する。
2. CI通過後にGitHub Issue #67をクローズする。
3. Review状態遷移監査は ISSUE-054 / GitHub #73 で継続する。
4. 次はISSUE-052またはISSUE-053を優先度と衝突リスクで選定する。
