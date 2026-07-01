# ISSUE-021: プロダクト表示文言を原則日本語に統一する

## Issue番号

ISSUE-021

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/21

登録理由: ユーザーから「このプロジェクトの表示は、基本的に日本語でお願いしたい」と明示要望があったため。

## 登録日

2026-07-01

## 背景

AI PM Platformは日本語で運用されるプロジェクト管理・議事録・レビュー支援プロダクトである。現在の実装やドキュメントには英語のステータス、ボタン、エラー、レビュー文言が混在する可能性がある。

ユーザー体験としては、画面表示、操作導線、エラーメッセージ、レビュー結果、Issue生成文言など、利用者が直接読む表示は原則日本語で統一する必要がある。

## 目的

プロダクトのユーザー向け表示文言を原則日本語に統一し、日本語話者が迷わず利用できるAI PM体験を作る。

## 完了条件

- UIの主要ボタン、ラベル、見出し、空状態、エラー表示が日本語である
- ユーザー向けのAPI error safe detailが必要に応じて日本語化されている
- 生成されるIssue/Review/議事録/要件定義の表示文言が日本語運用に合っている
- 内部コード識別子、API enum、DB statusなど、英語のまま維持すべきものと表示翻訳するものの境界が整理されている
- Playwrightまたはrequest specで主要表示が日本語であることを確認している
- レビュー結果が `docs/review/` に保存されている

## スコープ

- Frontend UI文言
- ユーザー向けエラー文言
- Review/Issue生成結果の表示文言
- 日本語表示ポリシーのドキュメント化
- 主要導線の表示確認テスト

## 非スコープ

- API enumやDB statusの物理値を日本語へ変更すること
- 開発者向けログ、内部例外、コード識別子の全面日本語化
- 多言語切り替え機能の実装
- 翻訳管理SaaSの導入

## 関連レビュー

- `docs/review/20260701_japanese_display_policy_review.md`
- `docs/review/20260701_japanese_ui_glossary_review.md`
- `docs/review/20260701_japanese_frontend_ui_implementation_review.md`

## レビュー結果

2026-07-01にCodex一次レビューを実施。日本語表示ポリシーとして妥当。追加で日本語UI用語集を作成し、主要ステータス、ボタン、ラベル、エラー文言テンプレートを整理した。Frontendの主要画面へ日本語表示を適用し、`statusLabel` / `targetLabel` / `displayMessage` で内部値と表示文言を分離した。Playwrightで主要導線、失敗導線、pending reconciliation導線を日本語UI文言で確認した。API safe detail本体の日本語化範囲整理、AI生成テンプレート日本語統一、表示変換helperの共通化、視覚回帰確認は未完了。

良かった点:

- 主要ボタン、ラベル、見出し、空状態、ステータス、エラー表示を日本語化した。
- API enumやDB statusの物理値は英語のまま維持し、UI表示のみ日本語化した。
- GitHub公開、OpenAPI検証、Review blocker、reconciliationなど複雑な導線も日本語で読めるようにした。
- Playwrightを日本語UI文言へ更新し、主要導線の回帰を確認した。

改善点:

- 表示変換helper/mapが `workspace-client.tsx` 内にあり、画面追加時に共通化が必要。
- Backend safe detailはまだ英語が中心で、Frontend側のmessage mapに依存している。
- AI生成されるIssue/Review/要件定義テンプレートの日本語統一は未完了。
- スクリーンショットによる狭幅/視覚回帰確認は未実施。

検証結果:

- `git diff --check`: pass
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 7 passed

## 優先度

P1

理由:

- 日本語運用のプロダクト体験に直結する
- MVPの使いやすさと信頼感に影響する
- ただしGitHub publish/reconciliationなどのP0機能完了後にまとめて進めてもよい

## 次アクション

- 表示変換helper/mapを `frontend/lib` へ共通化する
- API safe detailの日本語化範囲を整理する
- AI生成されるIssue/Review/要件定義テンプレートを日本語運用へ寄せる
- 日本語UIのスクリーンショット/狭幅表示確認を追加する
- 日本語表示レビューの外部AIレビュー結果を追記する

## 関連ドキュメント

- `docs/product/20260701_japanese_display_policy.md`
- `docs/product/20260701_japanese_ui_glossary.md`
