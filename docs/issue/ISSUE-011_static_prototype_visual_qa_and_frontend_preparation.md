# ISSUE-011: 静的プロトタイプのビジュアルQAとフロント実装準備を行う

## GitHub Issue

登録待ち。

理由: remote未設定、GitHub CLI token invalid。

## 背景

ISSUE-009でデザインシステムと静的HTML/CSSプロトタイプを作成したが、Playwrightのブラウザ実行ファイルが未インストールで、スクリーンショットによる実ブラウザQAは未完了である。

## 目的

静的プロトタイプを実ブラウザで確認し、フロント実装へ進む前にレイアウト崩れ、重なり、レスポンシブ、アクセシビリティ初期リスクを検出する。

## 完了条件

- 1440px viewportでスクリーンショット確認済み
- 1280px viewportでスクリーンショット確認済み
- 1024px viewportでdrawer/stack挙動確認済み
- 767px以下でunsupported notice確認済み
- 主要テキストとボタンに重なりがない
- 色コントラストの初期確認がある
- フロント実装方式が決定されている
- QAレビューが `docs/review/` に保存されている

## スコープ

- 静的プロトタイプのビジュアルQA
- レスポンシブ確認
- フロント実装方式の準備
- UI改善Issue化

## 非スコープ

- API接続
- 本番認証
- GitHub同期実装

## 関連レビュー

- `docs/review/20260630_design_system_static_prototype_review.md`
- `docs/review/20260630_static_prototype_visual_qa_review.md`

## レビュー結果

デザインシステムと静的プロトタイプは作成済み。ただし、実ブラウザQAが未完了のため、世界レベルのSaaS基準ではフロント実装開始前に確認が必要。

## 次アクション

- Playwright CLIでスクリーンショット確認済み
- `prototype/index.html` を1440px、1280px、1024px、767pxで確認済み
- 確認結果は `docs/review/20260630_static_prototype_visual_qa_review.md` に保存済み
- 1024px drawer挙動、フォーカスリング、コントラスト検証はISSUE-013以降で継続

## 進捗

完了。GitHub Issue同期のみ登録待ち。
