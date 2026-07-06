# Requirement承認ブロッカー表示 実装レビュー

## 評価日時

2026-07-07 06:38 JST

## 評価担当

Codexレビュー統括 / Product Manager / Frontend Architect / Backend Architect / Security Engineer / QA / UI/UX Designer

外部AIレビュー: Claude、ChatGPTレビューは未実施。現時点ではCodex一次レビューとして保存し、外部AIレビュー結果が追加された場合は差分分析を追記する。

## 使用フレームワーク

- G-STACK
- HEART
- WCAG
- ISO25010
- MoSCoW

## 対象

Issue #3のRequirement Workspaceで、未決事項、未解決レビュー、期限切れリスク受容、承認コメント不足を承認前に確認できるようにする実装。

## 良かった点

- 既存の `GET /reviews` を使い、追加APIなしでRequirement対象レビューを取得できている。
- `lastReview` 依存を減らし、Requirement専用の `requirementReviews` stateで対象レビューを扱うようにした。
- 承認ボタンの近くに承認ブロッカーを表示し、APIエラー後に理由を知る体験を減らした。
- 未決事項、未解決レビュー、期限切れリスク受容を件数で見せ、詳細リストには対応が必要なレビューや承認コメント不足を表示した。
- E2Eで未決事項件数、未解決レビュー件数、レビュー詳細、承認ボタンの無効化と復帰を確認した。

## 改善点

- UI側の期限切れリスク受容判定はクライアント時刻に依存するため、最終判定はBackendの `RequirementApprovalGate` を正とする必要がある。
- ブロッカー詳細は最大4件表示のため、件数が多い場合の全履歴確認導線はまだ弱い。
- Requirement reviewsの取得中状態、再取得失敗時の専用表示、手動再読み込み導線は未実装。
- Requirement再編集後に下流Issue/OpenAPI draftをstale化する処理はまだ未実装。
- 外部AIレビュー比較は未実施であり、L3比較レビューとしては未完了。

## 優先順位

| 優先度 | 指摘 | 改善案 |
| --- | --- | --- |
| P0 | 承認ブロッカーをUIで把握できない問題は解消 | 今回の実装をPR CIで確認し、main反映後にIssue台帳とGitHub Issueへ同期する |
| P1 | 全レビュー履歴と解決理由が見えない | Requirement差分履歴またはReview詳細パネルで全件表示する |
| P1 | 下流draftの古さが残る | Requirement差し戻し時にIssue/OpenAPI draftをstale化する |
| P2 | クライアント時刻依存の補助判定 | 期限切れの最終判定はBackend APIのエラー詳細を優先表示する |

## 次アクション

1. PR CIで `frontend:build`、Playwright、API検証を確認する。
2. GitHub Issue #3へ今回の完了範囲と残課題をコメント同期する。
3. 次のIssue #3作業として、Requirement差し戻し時の下流Issue/OpenAPI draft stale化を設計する。
4. Requirement差分履歴と全レビュー履歴表示を別作業として整理する。

## Issue番号

- GitHub Issue: #3

## 検証結果

- `npm run frontend:e2e -- --grep "creates a project, saves a Discord log, generates minutes, and requests review"`: 1 passed
- `npm run frontend:build`: 成功
- `npm run display:check`: Display labels OK: 86 messages, 53 statuses, 5 targets
- `npm run api:verify`: OpenAPI OK、Redocly valid、型生成成功。Redocly CLIのNode version warningは既存警告
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec rspec spec/requests/api/v1/reviews_spec.rb spec/requests/api/v1/requirements_spec.rb`: 22 examples, 0 failures
- PR CI初回でGitHub照合系E2Eのモック未追従を検知。Requirement reviews取得の空配列モックを追加して修正
- `npm run frontend:e2e -- --grep "GitHub reconciliation|GitHub Issue candidate|linking an existing GitHub Issue|GitHub Issue from another repository"`: 7 passed
- `npm run frontend:e2e -- --grep "links an existing GitHub Issue from pending reconciliation"`: 1 passed

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | Requirement承認前に、止まっている理由と対応先を画面上で把握できるようにする |
| Strategy | 既存Reviews APIと既存validation UIを活用し、Backend gateの前段で説明責務を果たす |
| Tactics | Requirement reviews state、未決事項/未解決レビュー/期限切れリスク受容件数、詳細ブロッカー、承認ボタン制御、E2E |
| Assessment | P0の視認性課題は解消。全履歴表示と下流stale化は継続課題 |
| Conclusion | Issue #3のブロッカー詳細表示としてPR化してよい |
| Knowledge | ReviewOpsでは、承認を止める条件と、ユーザーが次に直す場所を同じ画面で示すことが重要 |

## 判定

実装はPR化してよい。世界レベルSaaS基準では、全履歴表示、下流draft stale化、外部AIレビュー比較が不足しているため、Issue #3は継続する。
