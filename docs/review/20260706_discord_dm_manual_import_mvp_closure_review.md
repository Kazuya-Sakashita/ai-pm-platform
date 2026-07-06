# Discord DM手動インポートMVP 親Issueクローズ判定レビュー

## 評価日時

2026-07-06 12:29:14 JST

## 評価担当

Codex / Product Manager / Security Engineer / AI Architect / Backend Architect / Frontend Architect / QA / UI/UX Designer

外部AIレビュー: Claude/ChatGPTレビューは未実施。現時点ではCodex一次レビューとして保存し、外部AIレビュー結果が追加された場合は差分分析を追記する。

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- HEART
- WCAG
- ISO25010

## Issue番号

ISSUE-022 / GitHub #22

## 対象

- `docs/issue/ISSUE-022_discord_dm_manual_import_mvp.md`
- `docs/issue/ISSUE-029_discord_dm_text_encryption_retention_delete.md`
- `docs/issue/ISSUE-035_discord_dm_structured_outputs_provider.md`
- `docs/issue/ISSUE-036_discord_dm_summary_draft_edit_ui.md`
- `docs/issue/ISSUE-037_conversation_summary_review_center_integration.md`
- `docs/issue/ISSUE-038_discord_dm_pii_redaction_suggestions.md`
- `frontend/app/workspace-client.tsx`
- `frontend/e2e/meeting-workspace.spec.ts`
- `docs/api/openapi.yaml`

## 判定対象の後続Issue状態

| Issue | 内容 | GitHub状態 |
| --- | --- | --- |
| #29 | DM由来テキストの暗号化、保持期限、削除基盤 | CLOSED |
| #35 | DM整理Structured Outputs provider | CLOSED |
| #36 | DM整理ドラフト編集保存UI | CLOSED |
| #37 | Review CenterとConversation Summary Draft承認連動 | CLOSED |
| #38 | PII検出とマスキング提案 | CLOSED |

## 良かった点

- Discord DM自動取得をMVP非スコープにし、ユーザーが明示的に貼り付けたDMだけを扱う方針をADRで固定した。
- Conversation Import / Summary Draft API、OpenAPI型、Backend service、Frontend操作導線が揃っている。
- 同意確認、マスキング後テキスト、AI送信前安全チェック、PII検出、整理ドラフト生成、編集、レビュー依頼、承認を一連の画面で扱える。
- raw/redacted textとsummary draft派生JSON本文の保護、retention、匿名化、safe AuditLog、Policy Objectまで後続Issueで補強済みである。
- Structured Outputs providerは通常CIで外部通信しない設計になっており、AI provider failureもsafe errorとして扱える。
- Playwrightでhappy path、PII redaction、編集保存、レビュー連動、匿名化失敗系を検証している。
- レビュー文書が各フェーズに保存され、MVP親Issueとして監査可能な状態になっている。

## 改善点

- Discord公式審査やDeveloper Policyに対する詳細リーガルレビューは未実施である。
- 実OpenAI API smoke、実GitHub App smoke、staging/production worker smokeは環境とcredential待ちである。
- consent evidenceはcheckboxと文言version中心であり、将来的には同意取得者、取得日時、相手方識別、法務根拠をより細かく扱う必要がある。
- 実認証/JWTは導入済みだが、IdP/JWKS、Enterprise SSO、全Project配下APIの完全認可は継続課題である。
- スクリーンリーダー実機確認、支援技術レビュー、プロダクト全体の視覚回帰は未実施である。

## 優先順位

| Priority | 指摘 | 対応 |
| --- | --- | --- |
| P0 | DM手動インポートMVPの実装条件 | 完了済み。親Issue #22はクローズ可能 |
| P1 | 実環境smokeとcredential依存検証 | ISSUE-004 / release gateへ移管 |
| P1 | 同意証跡の粒度 | 将来の法務/監査Issueで強化 |
| P2 | スクリーンリーダーと視覚回帰 | UI品質改善Issueで継続 |

## 次アクション

1. GitHub Issue #22へ後続Issue完了状況と残リスク移管をコメントする。
2. GitHub Issue #22をクローズする。
3. `docs/issue/ISSUE-022_discord_dm_manual_import_mvp.md` にクローズ状態を記録する。
4. 次の実作業は残Open Issueの中から、#21日本語表示、#6セキュリティ設計、#5レビュー基盤、#4GitHub/OpenAPI親Issueの順に見直す。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | Discord DMを安全に手動インポートし、AI整理ドラフトとして下流工程へ渡せるMVPを作る |
| Strategy | 自動取得を避け、手動貼り付け、同意確認、安全チェック、AI整理、編集、レビュー、承認へ段階化する |
| Tactics | Conversation Import API/UI、Structured Outputs provider、データ保護、PII検出、編集UI、Review Center連動、E2E |
| Assessment | MVP親Issueの完了条件は満たした。production release証跡は別gateで継続 |
| Conclusion | GitHub Issue #22はクローズ可能 |
| Knowledge | センシティブなチャットAI化は、自動取得よりも同意付き手動入力とレビューゲートから始める方が安全に価値検証できる |

## 判定

合格。

ISSUE-022はDiscord DM手動インポートMVPの親Issueとしてクローズ可能。ただし、実環境smoke、法務/同意証跡強化、支援技術レビューは後続のrelease gateまたは個別Issueで継続する。
