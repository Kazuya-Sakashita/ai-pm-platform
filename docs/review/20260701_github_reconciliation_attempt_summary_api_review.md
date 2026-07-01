# GitHub Reconciliation Attempt Summary API Review

## 評価日時

2026-07-01 19:10:17 JST

## 評価担当

- Codex
- CTO
- Tech Lead
- Backend Architect
- Frontend Architect
- Security Engineer
- QA

## 使用フレームワーク

- G-STACK
- DDD
- C4 Model
- STRIDE
- ISO25010

## 対象

- Issue番号: #4
- 対象契約:
  - `docs/api/openapi.yaml`
  - `IssueDraft.github_reconciliation`
  - `GitHubReconciliationStatus`

## 良かった点

- 新規エンドポイントを増やさず、既存のIssue Draft取得レスポンスにpending reconciliation attempt summaryを追加する設計にした。
- Frontendが追加API呼び出しなしで、復旧操作を表示すべき状態か判断できる。
- `pending` を必須にし、attemptがない失敗とreconciliation requiredを明確に分けられる。
- 公開する情報をattempt id、status、safe error、GitHub Issue番号/URL、completed_atに絞り、idempotency digestや内部例外を出さない設計にした。
- 既存のreconciliation API、manual resolve APIの契約を変えず、後方互換性を維持した。

## 改善点

- 現時点ではpending attempt summaryだけで、marker検索の候補Issue一覧やmatch countは返さない。
- attempt history全体は返さないため、監査詳細を見る管理画面には別APIが必要になる。
- `safe_error_detail` は安全化された文言だが、UIでの表示粒度と多言語化方針は未整理。
- 認証/認可が未接続のため、reconciliation summaryを見る権限分離はまだ実装されていない。
- retry count、cooldown、承認者、期限は契約に含めていない。

## 優先順位

- P0: Backendの `IssueDraft#api_json` にpending summaryを実装し、request specでpending true/falseを検証する。
- P0: Frontendで `github_reconciliation.pending` がtrueの場合のみ復旧操作を有効表示する。
- P1: 候補Issue一覧、retry count、cooldown、承認者を返す拡張契約を別途設計する。
- P1: 認可設計と監査閲覧APIをIssue化する。

## 次アクション

- Backend API responseを実装する。
- OpenAPI型を再生成する。
- FrontendのPublish blocked表示をpending summaryに合わせて調整する。
- Request spec、Playwright E2E、review/issue台帳を更新する。

## Issue番号

- #4

## レビュー結果

API設計としては実装へ進めてよい。世界レベルのSaaS基準では、候補Issue選択、権限分離、retry制御は不足しているが、未接続エラー時に復旧操作が紛らわしく出るP0 UXリスクを下げる最小契約として妥当。
