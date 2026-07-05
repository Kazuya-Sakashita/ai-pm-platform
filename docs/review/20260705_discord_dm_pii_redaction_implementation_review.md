# Discord DM PII redaction implementation review

## 評価日時

2026-07-05 16:21:49 JST

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

- `backend/app/services/sensitive_content_scanner.rb`
- `backend/app/services/conversation_imports/scan_service.rb`
- `backend/spec/services/sensitive_content_scanner_spec.rb`
- `backend/spec/requests/api/v1/conversation_imports_spec.rb`
- `frontend/e2e/meeting-workspace.spec.ts`

## 良かった点

- メールアドレス、電話番号、住所風表現、URL token、API key風文字列、金融情報、法務情報を分類付きfindingとして検出できるようになった。
- safety flagのtypeはOpenAPI既存enumに合わせ、PII/credential/financial/legal/secretを契約内で表現できている。
- `redaction_suggestions` は種別ごとの安全な置換候補を返し、理由文や置換候補に生PII/tokenを含めない。
- `ConversationImports::ScanService` はblocked時に `ready_for_ai` へ進めず、AI整理生成APIも既存status gateで拒否する。
- AuditLog metadataは件数/blocked reason中心で、生メールアドレス、電話番号、tokenを保存しないことをrequest specで確認した。
- Frontend E2Eで安全チェック結果に安全な日本語コピーと置換候補が表示され、生PIIが安全チェックpanelへ出ないことを検証した。

## 改善点

- ルールベース検出のため、表記ゆれ、海外住所、氏名単体、業界固有ID、添付ファイルは検出漏れがあり得る。
- `location_hint` は種別単位であり、本文中の行番号/範囲までは示していない。
- false positive時のoverrideは未実装で、現時点では編集と再スキャンのみで解除する。
- `redacted_text` 自動置換は未実装で、ユーザーが手動でマスキング後テキストを編集する必要がある。
- 実認証/JWTが未実装のため、誰がscanしたかのproduction-grade identityはISSUE-039に残る。

## 優先順位

| Priority | 残課題 | 対応Issue |
| --- | --- | --- |
| P0 | 実認証/JWT actor identity接続 | ISSUE-039 |
| P1 | Structured Outputs provider接続前の最終AI送信gate確認 | ISSUE-035 |
| P1 | membership管理API/UI | ISSUE-040 |
| P2 | 行番号/範囲付きredaction suggestion | 新規Issue候補 |
| P2 | 承認者付きfalse positive override | 新規Issue候補 |

## 次アクション

1. ISSUE-038をGitHubへ同期し、CI成功後にcloseする。
2. 次はISSUE-035またはISSUE-039へ進む。AI provider接続を優先する場合は#35、production identityを優先する場合は#39。
3. DLP精度の向上は#35の送信gate確認後に別Issue化する。

## 検証結果

- `bundle exec rspec spec/services/sensitive_content_scanner_spec.rb spec/requests/api/v1/conversation_imports_spec.rb`: 23 examples, 0 failures
- `npm run frontend:e2e -- --grep "safe PII redaction"`: 1 passed
- `npm run api:verify`: success
- `npm run display:check`: success
- `npm run frontend:build`: success
- `bundle exec rspec`: 182 examples, 0 failures
- GitHub Actions CI `28733249235`: success（commit `4962afd`）
- GitHub Actions CI `28733328816`: success（commit `49320a5`）

補足: `npm run api:verify` では既存のNode `v22.7.0` が期待範囲より古い警告とRedocly CLI更新通知が出たが、OpenAPI lint/type生成は成功した。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | DM由来PII/credentialをAI送信前に検出し、安全なマスキング提案を出す |
| Strategy | deterministicなルールベースscan gateをBackend共通処理として強化する |
| Tactics | finding分類、safe message、種別別replacement、request spec、Frontend E2E |
| Assessment | MVPとして合格。ただし完全DLPではなく、行番号やoverrideは未実装 |
| Conclusion | #35のAI provider接続へ進む前提品質として十分。ただしproduction公開には#39が残る |
| Knowledge | DM整理機能は、生成精度より先に「AIへ送らない情報」を制御できることが信頼の土台になる |

## STRIDE / OWASP観点

| 観点 | 実装評価 | 残リスク |
| --- | --- | --- |
| Information Disclosure | PII/credential/legal/financialをblockedにし、AI整理前に止められる | 検出漏れはあり得る |
| Repudiation | AuditLogにscan結果の件数/blocked reasonが残る | actor identityはISSUE-039待ち |
| Tampering | redacted_text変更後は既存のrescan gateでsummary生成を止める | 自動置換は未実装 |
| OWASP A01 | DM Policy Objectの上でscanできる | DM以外のAPI横展開は別Issue |
| OWASP A09 | ログに生PII/tokenを残さないspecを追加した | 外部ログ/APM連携時の設定確認は未実施 |

## 判定

合格。ISSUE-038の完了条件は満たした。ただし世界レベルSaaS基準では、実認証/JWT、行番号付きマスキング補助、承認者付きoverride、外部DLPは将来の改善対象として残す。

## AIレビュー比較

Codex一次レビューのみ。Claude、ChatGPTなど外部AIレビューは未実施。外部レビュー結果が追加された場合は、PII検出範囲、false positive override、ログに残すmetadata粒度を比較する。
