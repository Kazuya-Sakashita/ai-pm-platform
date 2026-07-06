# ISSUE-051: stale後の下流Draft再生成UXを実装する

## Issue番号

ISSUE-051

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/68

登録日: 2026-07-07
状態: OPEN（実装完了、PR CI確認待ち）

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
- `docs/review/20260707_requirement_stale_regeneration_ux_design_review.md`
- `docs/review/20260707_requirement_stale_regeneration_ux_implementation_review.md`

## レビュー結果

stale化で古い下流成果物を止めることはできたが、次に進むための再生成UXがなければ運用が止まる。Issue #4とも接続するP1改善として分離する。

2026-07-07 07:18 JST追加:

- Issue DraftとOpenAPI Draftのstale状態に再生成案内パネルを追加
- stale状態のIssue Draft保存、承認、GitHub公開、OpenAPI Draft保存、検証をFrontendで無効化
- Backendでstale Issue Draftの更新と公開、stale OpenAPI Draftの更新と検証を409 `stale_draft` で拒否
- OpenAPIへIssue Draft更新、OpenAPI Draft更新、OpenAPI検証の409 Conflictを追加し、Frontend生成型を同期
- Requirement再承認後に新しいIssue DraftとOpenAPI Draftを生成でき、既存stale Draftを上書きしないことをRequest specで確認
- Playwrightでstale案内、ボタン無効化、再承認後の再生成復帰を確認
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec rspec spec/requests/api/v1/issue_drafts_spec.rb spec/requests/api/v1/open_api_drafts_spec.rb`: 41 examples, 0 failures
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: 成功
- `npm run display:check`: 成功
- `npm run frontend:build`: 成功
- `npm run frontend:e2e -- --grep "creates a project, saves a Discord log, generates minutes, and requests review"`: 1 passed
- 判定: stale後の中核再生成UX、APIガード、既存Draft保持は完了。差分履歴はISSUE-050、公開済みGitHub Issue追跡更新は別Issue候補として継続

## 優先度

P1

## 次アクション

1. PR CIとmain CIを確認する。
2. CI通過後にGitHub Issue #68をクローズする。
3. 次はISSUE-050のRequirement差分履歴タイムラインへ進む。
