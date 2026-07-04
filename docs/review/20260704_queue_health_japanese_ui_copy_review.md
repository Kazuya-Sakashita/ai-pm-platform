# Queue Health Japanese UI Copy Review

## 評価日時

2026-07-04 21:12 JST

## 評価担当

Codex / Frontend Architect / UI/UX Designer / QA / Product Manager

外部AIレビュー: 未実施。Claude、ChatGPT等の外部レビューは環境から直接実行できないため、Codex一次レビューとして保存する。

## 使用フレームワーク

- G-STACK
- WCAG
- ISO25010

## Issue番号

- ISSUE-021
- 関連: ISSUE-025

## 良かった点

- Queue health監視MVP追加直後に、運用監視パネル内の英語UIコピーを検出できた。
- `Worker`、`Failed`、`Recurring`、`stale`、`Queue health` など、ユーザーが読む表示を日本語へ寄せた。
- 内部queue名やAPI enumは英語のまま維持し、表示ラベルだけを日本語化するISSUE-021の境界を守った。
- E2Eの期待値も日本語表示へ更新し、表示回帰を検知できるようにした。

## 改善点

- 直書き英語文言を自動検出する仕組みはまだない。
- queue名 `github_reconciliation` / `default` は内部運用名として表示しており、将来は表示名mapが必要になる可能性がある。
- 狭幅スクリーンショットとスクリーンリーダーでの読み上げ確認は未実施。

## 優先順位

- P0: Queue healthパネルの主要表示を日本語へ修正する。
- P0: Queue health E2Eを日本語表示へ更新する。
- P1: 直書き英語文言検出を追加する。
- P2: queue名表示mapと視覚回帰確認を検討する。

## 次アクション

- `npm run display:check`、`npm run frontend:build`、`npm run frontend:e2e -- e2e/queue-health.spec.ts` を再実行する。
- ISSUE-021へ日本語UIコピー修正結果を同期する。
- 直書き英語文言検出ルールを後続で設計する。

## G-STACK

### Goal

AI PM Platformのユーザー向け表示を日本語中心に保ち、運用監視パネルでも迷わず状態を読めるようにする。

### Strategy

内部値は英語のまま維持し、ユーザーが読むラベル、aria-label、空状態、集計表示を日本語にする。

### Tactics

- Queue healthパネルのラベルを日本語へ変更する。
- aria-labelも日本語へ変更する。
- Playwright E2Eの期待文言を日本語へ更新する。

### Assessment

小さな修正だが、世界レベルSaaS基準では新機能追加時に表示品質を同時に守る必要がある。今回の修正でISSUE-025のUIはISSUE-021の方針により近づいた。

### Conclusion

実装修正へ進めてよい。残る課題は直書き英語検出、queue表示名map、視覚/支援技術QAである。

### Knowledge

運用画面では英語の専門語が混ざりやすいが、日本語プロダクトでは「状態を理解できる日本語」と「内部識別子」の境界を分けることが重要である。

## WCAG / UX確認

- 状態や集計は色だけでなく日本語テキストで表示する。
- aria-labelも日本語へ寄せ、支援技術利用時の理解しやすさを上げる。
- queue名の内部値は運用者向け識別子として現時点では許容するが、一般ユーザー向けには表示名mapを検討する。
