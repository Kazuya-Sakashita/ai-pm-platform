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
- `docs/review/20260701_japanese_display_label_commonization_review.md`
- `docs/review/20260704_japanese_display_label_consistency_check_review.md`
- `docs/review/20260704_japanese_display_label_ci_gate_review.md`
- `docs/review/20260704_queue_health_japanese_ui_copy_review.md`
- `docs/review/20260704_hardcoded_english_ui_copy_check_review.md`
- `docs/review/20260706_japanese_display_policy_next_preparation_review.md`

## レビュー結果

2026-07-01にCodex一次レビューを実施。日本語表示ポリシーとして妥当。追加で日本語UI用語集を作成し、主要ステータス、ボタン、ラベル、エラー文言テンプレートを整理した。Frontendの主要画面へ日本語表示を適用し、`statusLabel` / `targetLabel` / `displayMessage` で内部値と表示文言を分離した。さらに表示変換helper/mapを `frontend/lib/display-labels.ts` へ共通化した。Playwrightで主要導線、失敗導線、pending/link/validation reconciliation導線を日本語UI文言で確認した。2026-07-04に `scripts/check-display-labels.rb` と `npm run display:check` を追加し、日本語UI用語集、`display-labels.ts`、OpenAPIのGitHub照合履歴status enumの整合を静的確認できるようにした。同日にCI workflowへ `npm run display:check` を追加し、main反映前に表示ラベル劣化を検知できるようにした。API safe detail本体の日本語化範囲整理、AI生成テンプレート日本語統一、視覚回帰確認は未完了。

2026-07-04にQueue health監視MVP追加後のUIコピーを確認し、運用監視パネル内の `Worker`、`Failed`、`Recurring`、`stale`、`Queue health` などの英語表示を日本語へ修正した。内部queue名やAPI enumは英語のまま維持し、ユーザーが読むラベル、aria-label、空状態、集計表示のみを日本語化した。

2026-07-04に `display:check` へ直書き英語UIコピー検出を追加した。対象はFrontend app配下のJSX text、`aria-label`、`placeholder`、`title`、`alt`、表示系property、status/error message setterに限定し、API enumや内部識別子へ過剰反応しないようにした。あわせてmetadata description、GitHub単独ラベル、公開済みGitHub Issue見出しを日本語文脈へ修正し、E2E期待値も更新した。

2026-07-06に次回着手準備レビューを実施した。UI表示、status label、target label、safe messageの日本語化、`display:check`、GitHub/レビュー/コミット文面の日本語統一ルールは整っている。次回はBackend safe detailとAI生成テンプレートの日本語棚卸しを行い、不足が小さければ#21のクローズ判定へ進む。

良かった点:

- 主要ボタン、ラベル、見出し、空状態、ステータス、エラー表示を日本語化した。
- API enumやDB statusの物理値は英語のまま維持し、UI表示のみ日本語化した。
- GitHub公開、OpenAPI検証、Review blocker、reconciliationなど複雑な導線も日本語で読めるようにした。
- Playwrightを日本語UI文言へ更新し、主要導線の回帰を確認した。
- `display-labels.ts` と日本語UI用語集の主要status/target labelを自動照合できるようにした。
- OpenAPIの `GitHubReconciliationHistoryItem.status` enumが表示ラベルに登録されていることを確認できるようにした。
- CI workflowへ `npm run display:check` を追加し、表示ラベルのズレを継続的に検知できるようにした。
- Queue health監視パネルの主要ラベル、aria-label、空状態、集計表示を日本語化した。
- Frontend app配下の可視コピーに英語のみ文字列が混入した場合、`npm run display:check` で検出できるようにした。

改善点:

- Backend safe detailはまだ英語が中心で、Frontend側のmessage mapに依存している。
- AI生成されるIssue/Review/要件定義テンプレートの日本語統一は未完了。
- スクリーンショットによる狭幅/視覚回帰確認は未実施。
- 用語集ドキュメントと `display-labels.ts` の自動整合チェック、およびCI workflowへの組み込みは実装済み。
- 直書き英語UIコピーの初期検出は実装済み。ただしBackend safe detail、AI生成テンプレート、複雑なJSX式の完全検出は未対応。
- CIでの狭幅スクリーンショット、支援技術確認、視覚回帰確認は未実装。

検証結果:

- `npm run display:check`: success
- `git diff --check`: pass
- `npm run frontend:build`: success
- `npm run api:verify`: success
- `npm audit --omit=dev`: 0 vulnerabilities
- `npm run frontend:e2e`: 9 passed
- 2026-07-04 display label consistency: `npm run frontend:e2e`: 14 passed
- 2026-07-04 display label CI gate: `npm run display:check`: success
- 2026-07-04 display label CI gate: `npm run frontend:build`: success
- 2026-07-04 Queue health Japanese UI copy: `npm run display:check`: success
- 2026-07-04 Queue health Japanese UI copy: `npm run frontend:build`: success
- 2026-07-04 Queue health Japanese UI copy: `npm run frontend:e2e -- e2e/queue-health.spec.ts`: 1 passed
- 2026-07-04 hardcoded English UI copy check: `npm run display:check`: success
- 2026-07-04 hardcoded English UI copy check: `npm run frontend:build`: success
- 2026-07-04 hardcoded English UI copy check: `npm run frontend:e2e -- --grep "links an existing GitHub Issue|shows repository validation errors"`: 2 passed
- 2026-07-06 next preparation: `npm run display:check`: success（52 messages、53 statuses、5 targets）
- 2026-07-06 next preparation: `npm run frontend:build`: success

## 優先度

P1

理由:

- 日本語運用のプロダクト体験に直結する
- MVPの使いやすさと信頼感に影響する
- ただしGitHub publish/reconciliationなどのP0機能完了後にまとめて進めてもよい

## 次アクション

- API safe detailの日本語化範囲を整理する
- AI生成されるIssue/Review/要件定義テンプレートを日本語運用へ寄せる
- 日本語UIのスクリーンショット/狭幅表示確認を追加する
- CI上の `display:check` 成功をGitHub Actionsで確認する
- 直書き英語UIコピー検出をBackend safe detailとAI生成テンプレートへ拡張する
- 日本語表示レビューの外部AIレビュー結果を追記する
- 次回着手時は、Backend safe detailとAI生成テンプレートを短時間で棚卸しし、クローズ判定または個別Issue分割を判断する

## 関連ドキュメント

- `docs/product/20260701_japanese_display_policy.md`
- `docs/product/20260701_japanese_ui_glossary.md`
