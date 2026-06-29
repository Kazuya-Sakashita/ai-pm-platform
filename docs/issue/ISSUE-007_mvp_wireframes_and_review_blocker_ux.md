# ISSUE-007: MVPワイヤーフレームとReview blocker UXを詳細化する

## GitHub Issue

登録待ち。

理由: remote未設定、GitHub CLI token invalid。

## 背景

2026-06-30の画面設計レビューで、Project Workspace、Meeting Workspace、Review Centerの実ワイヤーフレームとReview blockerの詳細仕様が不足していると評価した。

## 目的

MVP実装に入る前に、主要画面のワイヤーフレーム、生成失敗、再試行、レビュー差し戻し、承認ゲートのUXを具体化する。

## 完了条件

- Project Workspaceのワイヤーフレームがある
- Meeting Workspaceのワイヤーフレームがある
- Requirement Workspaceのワイヤーフレームがある
- Review Centerのワイヤーフレームがある
- Review blockerの表示、解除、再レビュー導線が定義されている
- AI生成失敗、再試行、部分再生成のUXが定義されている
- 画面設計レビューが `docs/review/` に保存されている

## スコープ

- テキストまたは図によるワイヤーフレーム
- Review blockerの詳細仕様
- 生成失敗と再試行UX
- デスクトップ優先のレスポンシブ方針

## 非スコープ

- Figma実ファイル
- フロントエンド実装
- モバイル専用UI

## 関連レビュー

- `docs/review/20260630_screen_design_review.md`
- `docs/review/20260630_wireframe_and_review_blocker_review.md`

## レビュー結果

画面設計レビューでは、画面構成と状態設計は妥当だが、実装に入るにはワイヤーフレームと失敗状態UXが不足していると評価した。

2026-06-30の更新レビューでは、ワイヤーフレーム、Review blocker、生成失敗、再試行UXはMVP実装前の設計として前進した。ただし、デザインシステム、静的プロトタイプ、accepted_riskの権限管理、エラー詳細マスキングは追加改善が必要。

## 次アクション

- MVPワイヤーフレームは `docs/product/20260630_mvp_wireframes_and_review_blocker_ux.md` に作成済み
- Review blockerの状態、文言、解除条件は同ファイルに定義済み
- 更新後レビューは `docs/review/20260630_wireframe_and_review_blocker_review.md` に保存済み
- ISSUE-008でaccepted_risk、secret scan、error maskingをAPI/DB設計へ反映する
- ISSUE-009でデザインシステムと静的プロトタイプを作成する

## 進捗

完了。GitHub Issue同期のみ登録待ち。
