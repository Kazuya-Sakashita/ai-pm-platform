# Japanese Display Label CI Gate Review

## 評価日時

2026-07-04 13:00 JST

## 評価担当

Codex / Product Owner / Frontend Architect / QA / UI/UX Designer / Tech Lead / DevOps

外部AIレビュー: 未実施。Claude、ChatGPT等の外部レビューは環境から直接実行できないため、Codex一次レビューとして保存する。

## 使用フレームワーク

- G-STACK
- HEART
- ISO25010
- WCAG
- DORA Metrics

## Issue番号

- ISSUE-021
- GitHub Issue #21

## 良かった点

- `npm run display:check` をCIへ追加し、日本語UI用語集と `frontend/lib/display-labels.ts` のズレをmain反映前に検知できるようにした。
- 既存の軽量check scriptを再利用し、新規依存やCI job分割を増やさずに品質ゲートを追加した。
- OpenAPI型生成後、Frontend build前に実行する順序にしたため、API enum追加後の表示ラベル漏れを早期に止めやすい。
- Playwrightより前段で失敗するため、文言整合だけの不具合を短時間で発見できる。

## 改善点

- 直書き英語文言の網羅検出はまだCIに含まれていない。
- AI生成テンプレートの日本語統一はまだ検査対象外である。
- Backend safe detailの日本語化範囲は未整理で、Frontendのmessage mapに依存している。
- 狭幅スクリーンショット、スクリーンリーダー確認、視覚回帰はまだCIに含めていない。
- CIではNode engineを `.node-version` に合わせるが、ローカル環境ではNode version warningが出る場合がある。

## 優先順位

- P0: CIで `npm run display:check` が通ることを確認する。
- P1: 直書き英語文言の検出ルールを追加する。
- P1: AI生成テンプレートの日本語統一を進める。
- P2: 狭幅スクリーンショットと支援技術確認を追加する。
- P2: Backend safe detailの日本語化境界を整理する。

## 次アクション

- Issue #21へCI組み込みと検証結果を同期する。
- GitHub Actionsで成功確認後、Issue #21へCI run URLをコメントする。
- 直書き英語検出とAI生成テンプレート日本語化を次の改善候補として進める。

## G-STACK

### Goal

日本語表示ラベルの劣化をmain反映前に止める。

### Strategy

既存の `display:check` をCIへ接続し、最小の変更で継続的な品質ゲートにする。

### Tactics

- `.github/workflows/ci.yml` に `Check Japanese display labels` stepを追加する。
- OpenAPI検証後、Frontend build前に実行する。
- Issue台帳とレビュー文書へ改善点と残タスクを記録する。

### Assessment

日本語表示の保守性は改善した。ただし、世界レベルSaaS基準では、直書き文言検出、生成テンプレート統一、視覚/支援技術QAまで含めて初めて完成に近づく。

### Conclusion

CI gate追加は完了。Issue #21は前進したが、残タスクがあるためopen維持が妥当。

### Knowledge

内部enumとDB statusは英語のまま維持し、ユーザー向け表示だけをCIで日本語ラベルとして検査する。
