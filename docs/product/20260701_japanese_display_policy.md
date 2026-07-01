# 日本語表示ポリシー

## 作成日

2026-07-01

## 対象Issue

- ISSUE-021
- GitHub: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/21

## 目的

AI PM Platformのユーザー向け表示を原則日本語に統一し、日本語話者が迷わず会議、議事録、要件定義、Issue、レビュー、リリースまで進められる体験を作る。

## 基本方針

ユーザーが画面上で読む文言は、原則として日本語にする。

対象:

- 画面見出し
- ボタン
- タブ
- ラベル
- 入力補助文
- 空状態
- 成功/失敗メッセージ
- ユーザー向けエラー
- Review blockerの改善案/次アクション
- 生成されるIssue/議事録/要件定義の標準文言

## 英語のまま維持するもの

内部実装や外部API契約として英語のまま維持する。

- API path
- OpenAPI operationId
- DB column
- enum/statusの物理値
- class/module/method名
- GitHub API由来の識別子
- 開発者向けログ
- stack trace

## 表示変換するもの

内部値は英語のまま保持し、UI表示時に日本語へ変換する。

| 内部値 | 表示例 |
| --- | --- |
| draft | 下書き |
| approved | 承認済み |
| action_required | 対応が必要 |
| resolved | 解決済み |
| publish_failed | 公開失敗 |
| reconciliation_required | 照合が必要 |
| review_required | レビューが必要 |

## 文体

- 短く、業務画面向けに明確に書く
- 過度にカジュアルにしない
- 操作可能な文言にする
- エラーは原因と次アクションを含める
- AIが判断した内容は断定しすぎず、確認を促す

## 例

良い例:

- `GitHub Issueの照合が必要です`
- `候補が複数見つかりました。正しいIssueを選択してください。`
- `OpenAPIの検証エラーを修正してから公開してください。`

避ける例:

- `Failed`
- `Action required`
- `Something went wrong`
- `Publish reconciliation required`

## 実装メモ

- まずFrontend表示文言から棚卸しする
- API safe detailは段階的に日本語化する
- 内部値を日本語化してDB/API契約を壊さない
- Playwrightでは主要導線の日本語文言を検証する

## 完了判定

- 主要画面のユーザー向け文言が日本語である
- 主要エラーのsafe detailが日本語である
- 内部値と表示文言の境界が崩れていない
- 日本語表示レビューが `docs/review/` に保存されている
