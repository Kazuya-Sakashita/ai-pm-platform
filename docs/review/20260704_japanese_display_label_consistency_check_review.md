# Japanese Display Label Consistency Check Review

## 評価日時

2026-07-04 08:13 JST

## 評価担当

Codex / Product Owner / Frontend Architect / QA / UI/UX Designer / Tech Lead

外部AIレビュー: 未実施。Claude、ChatGPT等の外部レビューは環境から直接実行できないため、Codex一次レビューとして保存する。

## 使用フレームワーク

- G-STACK
- HEART
- ISO25010
- WCAG

## Issue番号

- ISSUE-021
- GitHub Issue #21

## 良かった点

- `frontend/lib/display-labels.ts` と `docs/product/20260701_japanese_ui_glossary.md` の主要ステータス/対象ラベルを自動照合する `scripts/check-display-labels.rb` を追加した。
- display labelの表示値が日本語を含むことを検査し、英語safe detailや内部enumが画面へ漏れるリスクを下げた。
- `draft`、`action_required`、`reconciliation_required`、`review_required` などを用語集に合わせ、表示文言をより自然な日本語へ寄せた。
- `npm run display:check` で軽量に実行でき、Playwrightより前の段階で文言ズレを検出できるようにした。
- 新規依存を追加せず、Ruby標準機能だけで実装した。

## 改善点

- スクリプトは静的mapとMarkdown表の整合だけを確認するため、画面上のすべての直書き日本語/英語を検出するわけではない。
- メッセージラベルは用語集のテンプレートと完全照合しておらず、日本語文字を含むかの検査に留まる。
- CI workflowへ `npm run display:check` をまだ組み込んでいない。
- 狭幅スクリーンショットやスクリーンリーダー確認は未実施。
- AI生成テンプレートの日本語統一は未完了。

## 優先順位

- P0: `npm run display:check`、frontend build、Playwright E2Eを通す。
- P1: CI workflowへ `npm run display:check` を追加する。
- P1: AI生成テンプレートの日本語統一を進める。
- P2: 直書き英語の検出ルールを追加する。
- P2: 狭幅スクリーンショットとスクリーンリーダー確認を追加する。

## 次アクション

- ISSUE-021へ整合チェック追加と検証結果を追記する。
- GitHub Issue #21へ進捗を同期する。
- CI組み込みは次の小さな改善として進める。

## G-STACK

### Goal

日本語UI用語集と実装の表示ラベルが継続的にズレない状態を作る。

### Strategy

UI全体の大きな再設計ではなく、既存の `display-labels.ts` に対する小さな静的チェックから始める。

### Tactics

- Ruby scriptでTypeScriptの静的mapとMarkdown表を読み取る。
- 用語集で定義済みの主要status/target labelを実装と照合する。
- 表示値に日本語文字が含まれることを確認する。
- npm scriptとして実行しやすくする。

### Assessment

保守性は改善した。ただし、CI組み込み、直書き文言検査、生成テンプレート日本語化、視覚/支援技術QAが残るため、Issue #21の完全クローズにはまだ不足する。

### Conclusion

日本語表示ラベル整合チェックはMVPとして完了。Issue #21は継続し、CI組み込みと生成テンプレート日本語化へ進む。

### Knowledge

内部値は英語のまま維持し、表示層で日本語へ変換する既存方針を守った。翻訳対象はUI表示値であり、API/DB enumは変更していない。
