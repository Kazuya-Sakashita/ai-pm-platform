# 2026-07-01 日本語UI用語集レビュー

## 評価日時

2026-07-01 19:41 JST

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

- `docs/product/20260701_japanese_ui_glossary.md`

## G-STACK

### Goal

AI PM Platformの日本語表示における表記揺れを防ぎ、画面、エラー、レビュー、生成文言の一貫性を高める。

### Strategy

内部値は英語のまま維持し、UI表示では日本語ラベルへ変換する。主要ステータス、ボタン、ラベル、エラー文言を用語集として固定する。

### Tactics

- 共通ステータスとReviewステータスの表示名を定義する。
- GitHub公開・照合まわりの日本語表現を定義する。
- 主要ボタン、主要ラベル、エラー文言テンプレートを整理する。
- 実装時にUI表示変換helper/mapを作る前提を明記する。

### Assessment

用語集としては実装前の基準になる。特にGitHub reconciliation周辺の文言が明確になり、Issue #4とIssue #21の接続がしやすくなった。一方で、現UIへの適用とPlaywright検証は未実施である。

### Conclusion

Issue #21を進める準備として有効。次はFrontendの既存文言棚卸し、表示変換helper/map、主要画面の日本語化に進むべき。

### Knowledge

日本語化は翻訳だけではなく、業務ユーザーが次に何をすべきか理解できる操作設計である。

## 良かった点

- 内部値と表示名の対応表を作った。
- GitHub公開・照合の複雑な状態を日本語化した。
- 主要ボタンと主要ラベルの基準を作った。
- エラー文言に次アクションを含める方針を明記した。

## 改善点

- まだ実UIへ適用していない。
- 表示変換helper/mapの実装場所が未決定。
- Playwrightで日本語表示を確認していない。
- 生成文言テンプレートの日本語統一は別途整理が必要。

## 優先順位

| Priority | 内容 | 判断 |
| --- | --- | --- |
| P1 | Frontend文言棚卸し | 実装対象を確定する |
| P1 | 表示変換helper/mapを作る | 内部値と表示名を分離する |
| P1 | 主要画面を日本語化 | UX改善の中心 |
| P1 | Playwrightで日本語表示を確認 | 回帰防止 |
| P2 | 生成文言テンプレートの日本語統一 | AI出力品質改善 |

## WCAG / ISO25010 / HEART確認

| 観点 | 評価 | 改善案 |
| --- | --- | --- |
| WCAG | 日本語表示で理解可能性が上がる | エラー文言は具体的にする |
| ISO25010 Usability | 用語統一により学習コストが下がる | UI文言棚卸しを実施 |
| ISO25010 Maintainability | 表示変換方針は保守しやすい | helper/mapを集約 |
| HEART Task Success | 操作ミス低減が期待できる | Playwrightで文言を固定 |
| HEART Happiness | 日本語話者の安心感が上がる | 不自然な直訳を避ける |

## 次アクション

1. Frontendの既存表示文言を棚卸しする。
2. UI表示変換helper/mapを設計する。
3. 主要画面のボタン、ラベル、空状態、エラーを日本語化する。
4. Playwrightで主要日本語文言を確認する。
5. 生成文言テンプレートの日本語方針を追加する。

## 検証結果

- `docs/product/20260701_japanese_ui_glossary.md`: 作成済み
- `git diff --check`: 後続確認予定

## Issue番号

- ISSUE-021
- GitHub Issue #21
