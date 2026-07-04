# 直書き英語UIコピー検出レビュー

## 評価日時

2026-07-04 21:27 JST

## 評価担当

Codex / Frontend Architect / QA / UI/UX Designer

## Issue番号

ISSUE-021

## 使用フレームワーク

- G-STACK
- WCAG
- ISO25010

## 対象

- `scripts/check-display-labels.rb`
- `frontend/app/layout.tsx`
- `frontend/app/workspace-client.tsx`
- `frontend/e2e/meeting-workspace.spec.ts`

## 良かった点

- `display:check` に、ユーザーに見える可能性が高い英語のみコピーの検出を追加した。
- JSX text、`aria-label`、`placeholder`、`title`、`alt`、表示系property、status/error message setterを対象にし、API enumや内部識別子を過剰に検出しない境界にした。
- metadata descriptionの英語コピーを日本語へ変更した。
- `GitHub` 単独表示を `GitHub連携`、`公開先`、`公開済みGitHub Issue` へ寄せ、ユーザーが文脈を読み取りやすい表示にした。
- E2Eの期待値を更新し、GitHub Issue紐付け導線の表示回帰を確認した。

## 改善点

- 今回の検出はFrontend app配下の初期ルールであり、Backend safe detailやAI生成テンプレートまでは対象外である。
- JSX内の複雑な式や子コンポーネント経由の表示文字列は、正規表現だけでは検出漏れの可能性がある。
- `AI PM` や `AI PM Platform` などのブランド語は許可しているが、将来ブランド/プロダクト用語の許可ルールをドキュメント化する必要がある。
- E2E fixtureやテスト名には英語が残る。これはユーザー表示ではないが、テストデータが画面に出る場合の境界を継続確認する必要がある。

## 優先順位

- P0: Frontendのユーザー可視コピーに英語のみ文字列が混入しないよう `display:check` で検出する。
- P0: 既存の英語metadata descriptionとGitHub単独ラベルを修正する。
- P1: Backend safe detailとAI生成テンプレートの日本語チェックへ範囲を広げる。
- P1: ブランド/技術用語の許可リスト運用方針を用語集へ追記する。

## 次アクション

- Backend safe detailの日本語化範囲を整理する。
- AI生成Issue、Review、要件定義テンプレートの日本語統一を進める。
- `display:check` の検出対象を必要に応じてBackend/API response fixtureへ拡張する。
- スクリーンショットまたは支援技術確認で、日本語UIが実画面上で読みやすいことを確認する。

## 検証

- `npm run display:check`: success
- `npm run frontend:build`: success
- `npm run frontend:e2e -- --grep "links an existing GitHub Issue|shows repository validation errors"`: 2 passed
- `git diff --check`: pass

## G-STACK

### Goal

日本語運用プロダクトとして、ユーザーに見える英語のみコピーの混入を早期検知する。

### Strategy

内部enumやAPI識別子は英語維持しつつ、Frontendの可視コピーだけを静的検査する。

### Tactics

- `display:check` に可視コピー検出を追加する。
- 英語のみのmetadata descriptionとラベルを日本語文脈へ修正する。
- E2Eで変更したGitHub Issue表示導線を確認する。

### Assessment

世界レベルSaaS基準では、表示品質は実装後レビューだけでなくCI gateで守る必要がある。今回の検出は有効だが、ASTベースではないため完全ではない。

### Conclusion

ISSUE-021の「直書き英語文言検出」は初期MVPとして完了。次はBackend safe detailとAI生成テンプレートへ範囲を広げる。

### Knowledge

日本語UIであっても `GitHub` や `OpenAPI` のような技術/ブランド語は残る。問題は英語語句そのものではなく、ユーザーが文脈なしに英語コピーとして読む状態である。

## AIレビュー比較

Codex一次レビューのみ。Claude、ChatGPTなど外部AIレビューは未実施のため、外部レビュー結果が追加された場合は相違点を追記する。
