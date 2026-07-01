# 日本語UI用語集

## 作成日

2026-07-01

## 対象Issue

- ISSUE-021
- GitHub: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/21

## 目的

AI PM Platformの画面表示、エラー、レビュー、生成文言で使う日本語表記を揃え、ユーザーが迷わず操作できるようにする。

## 基本ルール

- ユーザーが読む文言は原則日本語にする
- 内部値、API path、DB status、enum、コード識別子は英語のまま維持する
- 画面表示では内部値を日本語ラベルへ変換する
- エラー文言は原因だけでなく次アクションを含める
- ボタンは動詞で始め、短く具体的にする
- レビュー文言は「何が問題か」「次に何をするか」を明確にする

## 共通ステータス

| 内部値 | 日本語表示 | 用途 |
| --- | --- | --- |
| draft | 下書き | 未承認の作業中状態 |
| generated | 生成済み | AI生成後、未レビュー |
| in_review | レビュー中 | 人間レビュー中 |
| needs_changes | 修正が必要 | 差し戻し |
| approved | 承認済み | 次工程に進める |
| failed | 失敗 | 処理失敗 |
| running | 実行中 | Job実行中 |
| succeeded | 完了 | Job成功 |
| cancelled | キャンセル済み | Job停止 |

## Reviewステータス

| 内部値 | 日本語表示 | 表示説明 |
| --- | --- | --- |
| open | 未対応 | レビュー作成直後 |
| action_required | 対応が必要 | 次工程を止める |
| resolved | 解決済み | blocker解消済み |
| accepted_risk | リスク承認済み | リスクを受け入れて進行 |

## GitHub公開・照合

| 内部値/概念 | 日本語表示 | 推奨文言 |
| --- | --- | --- |
| publish-github | GitHub Issueへ公開 | ボタン/処理名 |
| publish_failed | GitHub公開失敗 | 状態表示 |
| reconciliation_required | GitHub Issueの照合が必要 | blocker見出し |
| reconciled | 照合済み | 成功状態 |
| manually_reconciled | 手動照合済み | 人間が既存Issueを選択 |
| retry_approved | 再試行承認済み | controlled retry |
| review_required | レビューが必要 | API結果/画面表示 |

## 主要ボタン

| 英語/概念 | 日本語ボタン |
| --- | --- |
| Create project | プロジェクトを作成 |
| Save | 保存 |
| Generate minutes | 議事録を生成 |
| Approve | 承認 |
| Generate requirement | 要件定義を生成 |
| Generate issue draft | Issueドラフトを生成 |
| Generate OpenAPI draft | OpenAPIドラフトを生成 |
| Validate OpenAPI | OpenAPIを検証 |
| Publish GitHub Issue | GitHub Issueへ公開 |
| Reconcile GitHub publish | GitHub公開を照合 |
| Link existing issue | 既存Issueに紐付け |
| Approve retry | 再試行を承認 |
| Resolve action | 対応済みにする |
| Accept risk | リスクを承認 |

## 主要ラベル

| 概念 | 日本語表示 |
| --- | --- |
| Project | プロジェクト |
| Meeting | 会議 |
| Minutes | 議事録 |
| Requirement | 要件定義 |
| Issue Draft | Issueドラフト |
| OpenAPI Draft | OpenAPIドラフト |
| Review | レビュー |
| Review Gate | レビューゲート |
| Audit Log | 監査ログ |
| Job | ジョブ |
| Integration | 連携 |
| GitHub Repository | GitHubリポジトリ |

## エラー文言テンプレート

| 状況 | 推奨文言 |
| --- | --- |
| 入力不足 | 必須項目を入力してください。 |
| レビュー未承認 | レビューを完了してから次へ進んでください。 |
| OpenAPI未検証 | OpenAPIを検証してから公開してください。 |
| GitHub未接続 | GitHub連携を設定してから公開してください。 |
| GitHub公開失敗 | GitHub Issueの公開に失敗しました。設定と権限を確認してください。 |
| 照合0件 | 対応するGitHub Issueが見つかりませんでした。作成済みでないことを確認してから再試行を承認してください。 |
| 照合複数件 | 候補のGitHub Issueが複数見つかりました。正しいIssueを選択してください。 |
| AI生成失敗 | AI生成に失敗しました。入力内容を確認して再試行してください。 |
| rate limit | 利用上限に達しました。少し時間をおいて再試行してください。 |

## 文体

- 基本は敬体を使う
- ボタンは体言止めまたは短い動詞表現にする
- 見出しは短くする
- エラーは責める表現にしない
- 「失敗しました」だけで終えず、次アクションを書く

## 実装時の注意

- `status` や `enum` の値を直接日本語化しない
- UI層に表示変換helperまたはmapを置く
- Playwrightでは主要導線の日本語表示を確認する
- API safe detailは段階的に日本語化する
- GitHubやOpenAPIなど固有名詞は英語表記を維持する
