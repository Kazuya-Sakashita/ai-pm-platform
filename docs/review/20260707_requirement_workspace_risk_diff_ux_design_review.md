# ISSUE-053 Requirement Workspace未決事項・リスク・差分強調UX 設計レビュー

## 評価日時

2026-07-07 08:31 JST

## 評価担当

Codex（UI/UX Designer / Frontend Architect / QA / Product Manager / Security Engineer）

外部AIレビュー: Claude、ChatGPTレビューは未実施。現時点ではCodex一次レビューとして保存し、外部AIレビュー結果が追加された場合は差分分析を追記する。

## 使用フレームワーク

- G-STACK
- HEART
- WCAG
- ISO25010
- MoSCoW

## 対象

- Issue番号: ISSUE-053 / GitHub #70
- 対象画面: Requirement Workspace
- 対象データ: Requirement、Requirement Review、Requirement履歴タイムライン

## 良かった点

- 既存実装で承認ブロッカー、Review状態、履歴タイムラインが同一画面に揃っている。
- Backendの承認判定を正とし、Frontendは補助表示に徹しているため責務分離が崩れていない。
- Requirement履歴APIにより、差分、レビュー状態遷移、下流Draft stale化をUIで再利用できる。
- 既存の色体系とchip、validation panelを使えるため、新しいデザインシステムを追加せずに改善できる。

## 改善点

- 要件量が増えた場合、未決事項、リスク、差分、レビュー状態の優先順位が一目で分かりにくい。
- 現在の承認ブロッカーは件数中心で、次に読むべき本文やリスクの先頭項目が見えない。
- 履歴タイムラインは有用だが、最新差分だけを素早く確認する導線が弱い。
- 色付きborderだけでは状態識別が弱く、WCAG観点ではテキストラベル、件数、アイコンを併用する必要がある。
- モバイル幅では長いテキストが続くため、判断材料を短いカードとリストへ分ける必要がある。

## 改善案

- Requirement Workspace上部に判断サマリーを追加し、未決事項、リスク、レビュー、最新差分、下流Draftの状態をカード化する。
- 未決事項とリスクは本文編集欄までスクロールしなくても先頭3件を読めるようにする。
- 最新差分は履歴タイムラインとは別に、変更フィールドと安全プレビューを短く表示する。
- 各カードには状態ラベル、件数、次アクション文言を入れ、色だけに依存しない。
- モバイルでは1列表示に落とし、カード内テキストが横あふれしないようにする。

## 優先順位

| 優先度 | 指摘 | 改善案 |
| --- | --- | --- |
| P0 | 承認ブロッカーの判定をFrontendだけで完結させると危険 | 判定は既存Backend gateを正とし、Frontendは説明と導線に限定する |
| P1 | 長文Requirementで未決事項とリスクが埋もれる | 判断サマリーと注目リストを上部に追加する |
| P1 | 差分確認に履歴全体を読む必要がある | 最新差分だけを短く切り出す |
| P2 | 色だけの状態表示はアクセシビリティ不足 | 件数、状態ラベル、アイコン、説明文を併用する |

## 次アクション

1. Requirement Workspaceへ判断サマリーを追加する。
2. 未決事項、リスク、最新差分の注目リストを追加する。
3. Playwrightで主要表示とモバイル幅を確認する。
4. `display:check`、`frontend:build`、関連E2Eを実行する。
5. 実装レビューを `docs/review/` に保存する。

## Issue番号

- ISSUE-053
- GitHub Issue: #70

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | レビュー担当者が未決事項、リスク、差分、承認前注意点を短時間で判断できるようにする |
| Strategy | 新規APIを増やさず、既存Requirement、Review、履歴データを画面上部で再構成する |
| Tactics | 判断サマリー、注目リスト、最新差分、安全な短縮表示、モバイル1列化、Playwright確認 |
| Assessment | API変更なしで価値を出せる一方、履歴ページングや全文diffは今後の拡張余地として残る |
| Conclusion | ISSUE-053はFrontend中心の低リスク改善として実装へ進めてよい |
| Knowledge | AI PMのレビュー画面では、完全な情報量より先に「次に判断すべきもの」を示すことが重要 |

## 判定

実装へ進めてよい。ただし、承認可否の最終判定はBackendの `RequirementApprovalGate` を正とし、Frontend表示だけで完了判定しない。
