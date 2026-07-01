# 2026-07-01 日本語表示ポリシーレビュー

## 評価日時

2026-07-01 19:02 JST

## 評価担当

Codex

- Product Manager
- UI/UX Designer
- Frontend Architect
- QA
- Tech Lead

外部AIレビュー: Claude/ChatGPT等の外部レビューは未実施。現時点ではCodex一次レビューとして保存し、外部レビュー待ちとする。

## 使用フレームワーク

- G-STACK
- WCAG
- ISO25010
- HEART

## 対象Issue

- ISSUE-021
- GitHub: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/21

## 対象成果物

- `docs/issue/ISSUE-021_japanese_display_policy.md`
- `docs/product/20260701_japanese_display_policy.md`

## G-STACK

### Goal

AI PM Platformのユーザー向け表示を原則日本語に統一し、日本語話者が迷わず使える体験を作る。

### Strategy

内部API/DBの英語識別子は維持し、UIやsafe detailなどユーザーが読む文言を日本語表示へ変換する。

### Tactics

- 日本語表示ポリシーを `docs/product/` に保存する。
- ISSUE-021としてGitHub IssueとローカルIssue台帳へ登録する。
- 表示対象、英語維持対象、表示変換対象を分ける。
- 実装時はFrontend文言棚卸しとPlaywright確認を行う。

### Assessment

ポリシーとしては妥当。特に内部値を日本語化せず表示層で変換する方針は、API契約とユーザー体験を両立できる。一方で、現時点では実UIの棚卸しと修正は未実施である。

### Conclusion

ISSUE-021は有効なP1改善。GitHub publish/reconciliationなどP0機能と並行して進められるが、実装着手時はUI文言、safe detail、生成文言の3領域を分けて進めるべき。

### Knowledge

日本語化は単純翻訳ではなく、業務ユーザーが次に何をすべきか分かる文言設計として扱う。

## 良かった点

- ユーザー要望をIssue #21として即時登録した。
- 内部値と表示文言の境界を明確にした。
- UI、エラー、生成文言を対象に含めた。
- Playwrightで日本語表示を確認する完了条件を入れた。

## 改善点

- 現在のFrontend文言棚卸しは未実施。
- API safe detailの日本語化範囲が未確定。
- 生成されるIssue/Review文言のテンプレート方針が未整理。
- 日本語文言のトーン、敬体/常体、用語集が未作成。

## 優先順位

| Priority | 内容 | 判断 |
| --- | --- | --- |
| P0 | P0機能の実装完了を阻害しない | 現在の主線を守る |
| P1 | Frontend表示文言を棚卸し | 日本語化の第一歩 |
| P1 | UI用語集を作る | 表記揺れ防止 |
| P1 | Playwrightで主要日本語文言を確認 | 回帰防止 |
| P2 | API safe detailを段階的に日本語化 | UX改善 |

## WCAG / ISO25010 / HEART確認

| 観点 | 評価 | 改善案 |
| --- | --- | --- |
| WCAG | 日本語表示は理解可能性を高める | ボタン文言は短く具体的にする |
| ISO25010 Usability | 業務ユーザーの学習コストを下げる | 用語集と文言レビューを追加 |
| ISO25010 Maintainability | 内部値を維持する方針は保守しやすい | 表示変換helperを集約 |
| HEART Happiness | 日本語話者の安心感が上がる | エラーに次アクションを含める |
| HEART Task Success | 操作ミス低減が期待できる | Playwrightで主要導線を確認 |

## 次アクション

1. Frontendの表示文言を棚卸しする。
2. UI用語集を `docs/product/` または `docs/design/` 相当に追加する。
3. 主要画面のボタン、ラベル、空状態、エラーを日本語化する。
4. Playwrightで主要表示文言を確認する。
5. API safe detailの日本語化範囲を決める。

## 検証結果

- `docs/issue/ISSUE-021_japanese_display_policy.md`: 作成済み
- GitHub Issue #21: OPEN
- `docs/product/20260701_japanese_display_policy.md`: 作成済み
- `git diff --check`: 後続確認予定

## Issue番号

- ISSUE-021
- GitHub Issue #21
