# Discord DM手動インポートFrontend MVP実装レビュー

## 評価日時

2026-07-05 18:30 JST

## 評価担当

Codex / Product Owner / CTO / Tech Lead / AI Architect / Backend Architect / Frontend Architect / Security Engineer / QA / UI/UX Designer / Product Manager

外部AIレビュー: Claude / ChatGPTレビューは未実施。Codex一次レビューとして保存し、外部レビュー結果が追加された場合は差分分析を追記する。

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- WCAG
- ISO25010
- RICE

## Issue番号

- Local: ISSUE-022
- GitHub Issue: #22

## 対象

- Discord DM手動インポートFrontend MVP
- Conversation Import API接続
- Conversation Summary Draft生成/承認UI
- raw text暗号化・保持期限ADR

## 良かった点

- 既存OpenAPI clientを使い、`ConversationImport` / `ConversationSummaryDraft` 型に沿ってFrontendを実装した。
- 会議ログ入力とは別の「DM整理」パネルを追加し、DM由来データのプライバシー境界をUI上でも分けた。
- 保存、scan、整理生成、承認の順序をUIで表現し、Backendの `ready_for_ai` gateと整合させた。
- 同意確認チェック、マスキング後テキスト、承認理由をUIで扱い、DM整理を未レビューのまま下流へ進めない導線にした。
- 安全チェック結果、マスキング提案、Issue候補、要件候補を同一パネルで確認できるようにした。
- 表示ラベルにDM用statusとtargetを追加し、ユーザー向けUIに英語statusが出ないようにした。
- Playwrightで保存payload、同意version、マスキング後テキスト、承認理由、承認後表示を固定した。
- `ADR-0012` により、現時点の平文保存MVPをproduction-readyと誤判定しないproduction gateを明文化した。

## 改善点

- raw text / redacted textはまだDB平文保存であり、本番投入不可。暗号化、鍵管理、retention、削除/匿名化APIが必要。
- FrontendのDM整理パネルは既存workspace-clientに追加しており、ファイル肥大化が進んでいる。次の大きな機能追加前にcomponent分割が必要。
- 整理ドラフトはread-only表示で、AI誤要約の編集保存UIは未実装。
- safety flagの種類表示は日本語化したが、flag messageやredaction suggestion reasonはBackend由来文言に依存する。
- 承認後に要件定義/Issueドラフトへ直接接続するReview Center連動は未実装。
- 認証/認可が未実装のため、consent_confirmed_by、approved_by、project membershipに基づく閲覧制御がない。
- E2Eはmock happy path中心であり、secret検出、同意なし、stale draft、生成失敗、モバイル横幅のDM専用検証が不足している。
- WCAG観点ではcheckboxとread-only textareaの基本操作はあるが、スクリーンリーダー実機確認やfocus order全体確認は未実施。

## 優先順位

| 優先度 | 項目 | 理由 |
| --- | --- | --- |
| P0 | raw/redacted text暗号化、retention、削除/匿名化API | DMは高センシティブデータでありproduction blocker |
| P0 | project membership認可と承認者/同意確認者の実ユーザー紐付け | 他プロジェクト閲覧と否認防止に必須 |
| P1 | DM整理ドラフト編集保存UI | AI誤要約修正と人間レビュー品質に必要 |
| P1 | secret検出/同意なし/生成失敗のFrontend E2E | 安全導線の退行検知に必要 |
| P1 | Review CenterとConversation Summary Draft承認連動 | AI PMの統制体験として重要 |
| P2 | workspace-clientのcomponent分割 | 保守性と変更容易性の改善 |

## 次アクション

1. `ADR-0012` に沿って、暗号化、retention、削除/匿名化APIをIssue化する。
2. DM整理ドラフト編集保存UIを追加し、`PATCH /conversation-summary-drafts/{id}` をFrontendから使う。
3. secret検出、同意なし、stale draft、生成失敗のE2Eを追加する。
4. Review CenterでConversation Summary Draftレビューを一覧/承認できる導線を設計する。
5. 認証/認可導入時に、DMインポート閲覧、更新、承認、削除のPolicy Objectを作る。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | DMに埋もれた仕様相談を、同意とレビュー付きでAI整理するMVPとして前進 |
| Strategy | 自動取得ではなく手動貼り付けに絞り、会議ログとは別UIでプライバシー境界を明示 |
| Tactics | OpenAPI client、scan gate、read-only整理ドラフト、承認理由、E2E payload検証 |
| Assessment | MVPとしては条件付き合格。ただしproduction-readyではない |
| Conclusion | Issue #22のFrontend MVP sliceは完了。セキュリティ/認可/retentionは継続P0 |
| Knowledge | DM整理は価値が高いが、保存・削除・権限の統制なしではSaaS品質に届かない |

## STRIDE / OWASP

| 観点 | 現状 | 残リスク |
| --- | --- | --- |
| Spoofing | 同意確認チェックはUI/APIにある | 実ユーザーと同意確認者が未接続 |
| Tampering | raw/redacted更新後に再scanするBackend gateあり | Frontend差分履歴や版管理は未実装 |
| Repudiation | 承認理由を必須化 | approved_byが未接続 |
| Information Disclosure | redacted text優先、AuditLog safe metadata方針 | DB平文保存、認可未実装 |
| Denial of Service | 文字数上限はModel validationで存在 | Frontend側の事前文字数表示やrate limit表示なし |
| Elevation of Privilege | project scoped endpoint | project membership未実装 |

## WCAG / UX

- ボタン、入力、checkboxはラベル付きで操作できる。
- 既存の8px以下radiusと密度を保ち、ツール画面として過度な装飾を避けた。
- モバイル1カラムCSSを追加した。
- ただし、DMパネル専用のモバイルPlaywright、focus order、スクリーンリーダー確認は未実施。

## 検証結果

- `npm run display:check`: success
- `npm run api:verify`: success
- `npm run frontend:build`: success
- `npm run frontend:e2e -- e2e/meeting-workspace.spec.ts --grep "imports, scans"`: 1 passed
- `npm run frontend:e2e -- e2e/meeting-workspace.spec.ts --grep "pending GitHub reconciliation controls"`: 1 passed
- `git diff --check`: pass
- GitHub Actions CI `28713806416`: success（commit `e8f62e2`）
- GitHub Issue #22同期コメント: `https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/22#issuecomment-4883209598`

## 判定

条件付き合格。

Issue #22のFrontend MVPとして、手動DM貼り付けから安全チェック、AI整理ドラフト、承認までのブラウザ導線は実装済み。ただし、暗号化、retention、認可、削除/匿名化、編集レビュー、失敗系E2Eが未完了のため、Issue #22全体は継続OPENが妥当。
