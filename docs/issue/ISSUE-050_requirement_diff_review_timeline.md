# ISSUE-050: Requirement差分履歴とレビュー履歴タイムラインを実装する

## Issue番号

ISSUE-050

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/67

登録日: 2026-07-07
状態: OPEN

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

## レビュー結果

差分履歴は、監査性とレビュー品質を上げるP1改善である。単なるUI改善ではなく、保存する値の安全性、PII/secret除外、AuditLogとの責務分離を先に設計する必要がある。

## 優先度

P1

## 次アクション

1. 差分保存方式を設計する。
2. PII/secretを保存しない履歴スキーマをレビューする。
3. API契約を作成する。
4. Backend、Frontend、RSpec、Playwrightの順で実装する。
