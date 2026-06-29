# ISSUE-009: フロントエンド用デザインシステムと静的プロトタイプを作る

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/9

登録日: 2026-06-30
同期方法: `scripts/sync-github-issues.rb --apply`

## 背景

ISSUE-007でMVPワイヤーフレームとReview blocker UXを定義したが、実装に入るには余白、タイポグラフィ、色、コンポーネント、状態、キーボード操作、静的プロトタイプが必要である。

## 目的

AI PM PlatformのMVP画面を、実装可能なデザインシステムと静的プロトタイプに落とし込む。

## 完了条件

- カラー、タイポグラフィ、余白、border、状態色が定義されている
- Sidebar、Top bar、Context bar、Inspector、Status chip、Review blocker、Editor、Review action listのコンポーネント仕様がある
- Project Workspace、Meeting Workspace、Requirement Workspace、Review Centerの静的プロトタイプがある
- レスポンシブ最小幅とdrawer挙動が確認されている
- キーボード操作とフォーカス順が定義されている
- コンポーネント仕様レビューが `docs/review/` に保存されている

## スコープ

- デザインシステム
- 静的プロトタイプ
- 主要画面のUI状態
- アクセシビリティ初期確認

## 非スコープ

- Backend接続
- AI生成API実装
- GitHub実同期
- Figma実ファイル作成

## 関連レビュー

- `docs/review/20260630_wireframe_and_review_blocker_review.md`
- `docs/review/20260630_design_system_static_prototype_review.md`

## レビュー結果

ワイヤーフレームは実装前の構造として有効だが、世界レベルのSaaSを目指すには、静的プロトタイプで情報密度、状態表現、アクセシビリティを検証する必要がある。

## 次アクション

- デザインシステムは `docs/product/20260630_design_system_and_static_prototype.md` に作成済み
- 静的プロトタイプは `prototype/index.html` と `prototype/styles.css` に作成済み
- コンポーネント仕様レビューは `docs/review/20260630_design_system_static_prototype_review.md` に保存済み
- Playwrightブラウザ実行ファイルが未インストールだったため、実ブラウザQAはISSUE-011へ切り出し

## 進捗

設計と静的プロトタイプは完了。実ブラウザQAのみISSUE-011で継続。
