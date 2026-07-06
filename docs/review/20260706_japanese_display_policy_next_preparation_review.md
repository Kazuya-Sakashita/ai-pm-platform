# 日本語表示ポリシー 次回着手準備レビュー

## 評価日時

2026-07-06 12:35:20 JST

## 評価担当

Codex / Product Manager / Frontend Architect / QA / UI/UX Designer / Security Engineer

外部AIレビュー: Claude/ChatGPTレビューは未実施。現時点ではCodex一次レビューとして保存し、外部AIレビュー結果が追加された場合は差分分析を追記する。

## 使用フレームワーク

- G-STACK
- HEART
- WCAG
- ISO25010

## Issue番号

ISSUE-021 / GitHub #21

## 対象

- `docs/issue/ISSUE-021_japanese_display_policy.md`
- `docs/product/20260701_japanese_display_policy.md`
- `docs/product/20260701_japanese_ui_glossary.md`
- `frontend/lib/display-labels.ts`
- `scripts/check-display-labels.rb`
- `docs/issue/ISSUE-049_japanese_artifact_language_governance.md`

## 良かった点

- UI表示、status label、target label、safe messageの日本語化はかなり進んでいる。
- `display-labels.ts` に表示変換が集約され、API enumやDB statusの物理値を壊さず日本語表示できている。
- `scripts/check-display-labels.rb` により、Frontend app配下の英語のみ可視コピー、主要status/target label、GitHub照合履歴statusの漏れを検知できる。
- GitHub/レビュー/コミット文面の日本語統一はISSUE-049で運用ルール化され、クローズ済みである。
- 2026-07-06時点で `npm run display:check` と `npm run frontend:build` が成功している。

## 改善点

- Backend safe detailはFrontend `messageLabels` に依存しており、Backend側で日本語safe detailを返す範囲はまだ整理しきれていない。
- AI生成されるIssue、Review、議事録、要件定義テンプレートの日本語標準文言は、実装横断で棚卸しが必要である。
- `display:check` は複雑なJSX式、Backend error message、AI prompt/templateまでは完全検出しない。
- 狭幅スクリーンショット、支援技術確認、視覚回帰確認は未実施であり、世界レベルSaaS基準では残リスクである。
- 外部AIレビュー比較は未実施で、Codex一次レビューに留まっている。

## 優先順位

| Priority | 指摘 | 次の準備 |
| --- | --- | --- |
| P1 | #21クローズ判定に必要な最新検証 | `display:check`、`frontend:build`、必要に応じて代表E2Eを再実行する |
| P1 | Backend safe detailの範囲整理 | `messageLabels` 未登録のAPI errorを検索し、UI表示対象を分類する |
| P1 | AI生成テンプレートの日本語確認 | Issue/Review/Minutes/Requirement生成serviceとdocs/aiを棚卸しする |
| P2 | 視覚/支援技術確認 | 390px/desktop screenshotと主要導線のアクセシビリティ確認を追加候補にする |
| P2 | 外部AIレビュー比較 | 外部AI結果取得後に差分を追記する |

## 次アクション

1. #21着手時は、まずBackend safe detailとAI生成テンプレートの日本語棚卸しを行う。
2. 不足が小さければ、#21のクローズ判定レビューを作成し、GitHub Issue #21をクローズする。
3. 不足が大きければ、Backend safe detail / AI生成テンプレート / 視覚回帰を個別Issueへ分割する。
4. #21の検証コマンドとして `npm run display:check`、`npm run frontend:build`、必要に応じて代表Playwright E2Eを使う。

## 検証結果

- `npm run display:check`: 成功（52 messages、53 statuses、5 targets）
- `npm run frontend:build`: 成功

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | 日本語運用のプロダクト体験を壊さず、#21を閉じられる状態へ近づける |
| Strategy | UI表示は既存CI gateで守り、残るBackend safe detailとAI生成テンプレートを次回棚卸し対象にする |
| Tactics | display check、frontend build、関連文書確認、準備レビュー保存、Issue台帳追記 |
| Assessment | #21は次回クローズ判定候補。小さな棚卸しで閉じられる可能性が高い |
| Conclusion | 次の推奨着手Issueは #21 |
| Knowledge | 日本語統一はUIコピーだけでなく、AI生成物とsafe errorの運用境界まで含めて判定する必要がある |

## 判定

準備完了。

ISSUE-021は次回着手候補として妥当。現時点では即クローズではなく、Backend safe detailとAI生成テンプレートを短時間で棚卸ししてからクローズ判定へ進む。
