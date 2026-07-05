# Discord DM PII redaction design review

## 評価日時

2026-07-05 16:13:52 JST

## 評価担当

Codex as Product Owner / CTO / Tech Lead / AI Architect / Backend Architect / Frontend Architect / Security Engineer / QA / UI/UX Designer / Product Manager

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- WCAG

## Issue番号

- ISSUE-038
- GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/38

## 評価対象

Discord DM手動インポートの `SensitiveContentScanner`、`ConversationImports::ScanService`、Frontend安全チェック表示、AI整理前ブロック条件。

## 良かった点

- OpenAPIにはすでに `personal_data`、`credential`、`financial`、`legal`、`secret` の安全フラグenumがあり、契約を壊さずに検出分類を強化できる。
- `ConversationImports::ScanService` がAI整理前の共通gateになっており、Backend側で確実に `ready_for_ai` へ進めるかを制御できる。
- Frontendには安全チェック結果とマスキング提案の表示枠があり、UI追加を最小化して改善できる。
- AuditLogは既にscan結果の件数とblocked reason中心で、生のDM本文を保存しない設計に寄せられている。

## 改善点

- 現行スキャナはsecret/credential中心で、メールアドレス、電話番号、住所風表現、金融/法務文脈を検出できない。
- `location_hint` が「本文」固定で、ユーザーが何をマスキングすべきか分かりにくい。
- `suggested_replacement` が常に `[REDACTED]` で、PII/credential/legal/financialの種別に応じた安全な置換候補になっていない。
- false positive時の扱いが曖昧で、ユーザーが安全に編集/再スキャンする運用がレビューされていない。
- ルールベース検出は完全なDLPではないため、検出漏れを前提にUIとレビュー文書で限界を明示する必要がある。

## 優先順位

| Priority | 対応 | 理由 |
| --- | --- | --- |
| P0 | Backend scan gateでPII/credentialをblockedにする | AI provider接続前の情報漏えい防止 |
| P0 | AuditLog/レスポンス理由文に生値を出さない | 二次漏えいを防ぐ |
| P1 | 種別別のlocation_hintと置換候補を出す | ユーザーのマスキング作業を減らす |
| P1 | request specとFrontend E2Eを追加する | 回帰防止とUI安全表示の保証 |
| P2 | false positive時の運用を文書化する | ルールベース検出の限界に備える |

## 次アクション

1. `SensitiveContentScanner::Finding` に分類、location hint、message、suggested replacementを持たせる。
2. メールアドレス、電話番号、URL token、API key風文字列、住所風表現、金融/法務文脈の代表パターンを追加する。
3. `ConversationImports::ScanService` でfinding情報を安全フラグとマスキング提案へ反映する。
4. request specでAI整理前blocked、safe AuditLog、redaction suggestionsを検証する。
5. Frontend E2Eで安全チェック結果の日本語表示と、生PII非表示を検証する。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | DM由来PII/credentialをAI送信前に検出し、ユーザーが安全にマスキングできるようにする |
| Strategy | ルールベースのdeterministic scan gateを先に強化し、外部DLPやAI判定は非スコープにする |
| Tactics | OpenAPI既存enumに沿ったfinding分類、safe copy、spec/E2E、レビュー保存 |
| Assessment | MVPとして妥当。ただし完全検出ではないためfalse positive/false negativeの明示が必要 |
| Conclusion | #35 Structured Outputs provider接続前に#38を完了すべき |
| Knowledge | AI PM Platformでは「AIに送らないための検出」が、生成品質と同じくらい重要なプロダクト価値になる |

## STRIDE / OWASP観点

| 観点 | リスク | 設計対応 |
| --- | --- | --- |
| Information Disclosure | DM内PII/credentialがAI providerへ送信される | scanでblockedにし、`ready_for_ai` へ進めない |
| Repudiation | 何を検出したか後から説明できない | safety flag typeとblocked reasonを保存する |
| Tampering | ユーザーがredacted_text未修正のまま生成する | statusが `ready_for_ai` の時だけ生成可能にする |
| OWASP A01 Broken Access Control | 権限外ユーザーがscan結果を見る | ISSUE-030 Policy Objectの上で動作させる |
| OWASP A02 Cryptographic Failures | 派生データにPIIが残る | ISSUE-029/#32の暗号化と合わせて防御する |
| OWASP A09 Logging Failures | ログに生PIIを出す | AuditLog metadataは件数/分類/blocked reasonのみ |

## false positive方針

- 検出対象は「AI送信前に確認すべき可能性が高い情報」として扱い、法的な個人情報判定を自動確定しない。
- false positiveの場合も、ユーザーは該当箇所を安全な表現へ編集し、再スキャンで解除する。
- MVPでは「無視して生成」ボタンは提供しない。レビューなしのoverrideは世界レベルSaaS基準では危険である。
- 将来、承認者付きoverrideを入れる場合は、理由、承認者、対象finding、期限をAuditLogへ保存する別Issueにする。

## 判定

条件付き合格。Backend scan gateとsafe UI表示を実装し、request specとFrontend E2Eが通ればISSUE-038は完了扱いにできる。ただし完全DLPではないため、外部DLP連携や承認付きoverrideは将来Issueとして残す。

## AIレビュー比較

Codex一次レビューのみ。Claude、ChatGPTなど外部AIレビューは未実施。外部レビュー結果が追加された場合は、PII検出パターン、override方針、ログに残すメタデータ粒度の差分を比較する。
