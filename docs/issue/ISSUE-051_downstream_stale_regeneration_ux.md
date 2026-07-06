# ISSUE-051: stale後の下流Draft再生成UXを実装する

## Issue番号

ISSUE-051

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/68

登録日: 2026-07-07
状態: OPEN

## 背景

Requirement再編集時にIssue DraftとOpenAPI Draftをstale化できるようになったが、stale後に何を再生成し、何を保持し、何を差分確認するかの導線が不足している。

## 目的

staleになった下流Draftを安全に再生成、比較、再承認できるUXとAPI契約を整える。

## 完了条件

- stale状態のIssue/OpenAPI Draftに再確認理由と次アクションが表示される
- Requirementの最新版からIssue DraftとOpenAPI Draftを再生成できる
- 再生成前に既存Draftを失わない
- 差分確認または再承認導線がある
- 設計レビュー、実装レビュー、RSpec、Playwrightを保存する

## スコープ

- stale後の再生成導線
- Issue/OpenAPI Draftの再確認UX
- 既存Draft保持と新Draft生成方針
- 再承認ゲート

## 非スコープ

- 公開済みGitHub Issue本文の自動更新
- Requirement差分履歴の完全実装
- OpenAI provider導入

## 関連レビュー

- `docs/review/20260707_downstream_draft_stale_design_review.md`
- `docs/review/20260707_downstream_draft_stale_implementation_review.md`
- `docs/review/20260707_requirement_followup_issue_split_review.md`

## レビュー結果

stale化で古い下流成果物を止めることはできたが、次に進むための再生成UXがなければ運用が止まる。Issue #4とも接続するP1改善として分離する。

## 優先度

P1

## 次アクション

1. stale後の再生成フローをAPI駆動で設計する。
2. 既存Draftを破壊しない保持方針をレビューする。
3. Issue/OpenAPI Draftそれぞれの再承認条件を定義する。
4. RSpecとPlaywrightでstale後の再生成を検証する。
