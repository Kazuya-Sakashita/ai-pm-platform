# GitHub Reconciliation Candidate Ranking ADR Review

## 評価日時

2026-07-02 06:53:39 JST

## 評価担当

- Codex
- Product Manager
- Tech Lead
- Backend Architect
- Frontend Architect
- QA
- Security Engineer
- UI/UX Designer

外部AIレビュー: Claude/ChatGPT等の外部レビューは未実施。現時点ではCodex一次レビューとして保存し、外部レビュー待ちとする。

## 使用フレームワーク

- G-STACK
- ADR
- STRIDE
- ISO25010
- HEART
- WCAG

## 対象

- Issue番号: #4
- 対象ファイル:
  - `docs/decisions/ADR-0007_github_reconciliation_candidate_ranking.md`
  - `docs/issue/ISSUE-004_github_issue_and_openapi_pipeline.md`

## 良かった点

- GitHub Search APIのscoreを業務的な正解判定に使わない方針を明文化した。
- 複数候補時は自動linkせず、人間レビューに止める既存reconciliation方針と整合した。
- 最大10件表示、GitHub best match順維持、closed Issue表示の方針を明確にした。
- 返却してよい候補情報と返さないraw/sensitive情報を分け、Security観点を補強した。
- UIの選択済み状態、aria属性、long title視覚回帰など次の改善を具体化した。

## 改善点

- ADR追加のみで、選択済み状態やaria属性はまだ未実装。
- `total_count`、`incomplete_results`、10件超過表示はAPI contractに未追加。
- GitHub Search APIのindexing delay、rate limit、retry/backoff方針は別ADRが必要。
- long title/URLの狭幅視覚回帰は未検証。
- live GitHub App credentialでの候補メタデータ表示smokeは未実施。

## 優先順位

- P0: live GitHub App credentialでcandidate metadataをsmoke testする。
- P1: ADR-0007に基づき、候補選択済み状態とaria属性をFrontendへ追加する。
- P1: 長いtitle/URLの視覚回帰E2Eを追加する。
- P1: `total_count` / `incomplete_results` / 10件超過表示のAPI拡張要否を判断する。
- P1: GitHub Search retry/backoff方針をADR化する。

## 次アクション

- Candidate selection UIに選択済み状態とアクセシビリティ属性を追加する。
- long title/URLの視覚回帰E2Eを追加する。
- GitHub Searchの `total_count` と `incomplete_results` を候補APIへ出すか検討する。
- GitHub Search retry/backoff方針をADR化する。
- live GitHub App credentialが設定できる環境でsmoke testを実施する。

## Issue番号

- #4

## レビュー結果

ADRとして合格。候補scoreを信頼しすぎず、GitHub best match順、最大10件、人間レビュー停止を明文化できた。世界レベルのSaaS基準では、方針文書だけでは不十分であり、選択済み状態、アクセシビリティ、long titleの視覚品質、10件超過表示、live smokeが残るためIssue #4はまだクローズ不可。

## 検証結果

- ドキュメント追加のみ。
- `git diff --check`: success
