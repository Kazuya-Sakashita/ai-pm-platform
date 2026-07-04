# Discord DM保持期限・匿名化実装レビュー

## 評価日時

2026-07-05 19:25 JST

## 評価担当

Codex / CTO / Tech Lead / Backend Architect / Frontend Architect / Security Engineer / QA / Product Manager

## Issue番号

ISSUE-029

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- DORA Metrics

## 対象

- Active Record Encryption設定
- Conversation Import retention fields
- `DELETE /conversation-imports/{conversation_import_id}`
- `ConversationImports::RetentionService`
- `ConversationImportRetentionJob`
- Frontend DM匿名化導線
- OpenAPI contract / generated TypeScript schema

## 良かった点

- `raw_text` と `redacted_text` をActive Record Encryption対象にし、DB dump単体でDM本文を読めない状態へ進めた。
- productionでは暗号化key未設定をboot blockerにし、開発/テストだけ既存平文データ読み取りを許容する境界にした。
- raw text 30日、import/draft 180日の保持期限timestampをAPIとDBへ追加した。
- `DELETE /conversation-imports/{id}` を匿名化操作として実装し、本文、参加者、安全フラグ、整理ドラフト候補、引用を削除済み状態へ置換した。
- retention service/jobを追加し、期限切れraw text purgeとimport匿名化を定期実行できるようにした。
- AuditLogは件数、理由、期限などのsafe metadataだけを保存し、本文やsecret値を残さないspecを追加した。
- Frontendへ保持期限表示とDM匿名化ボタンを追加し、Playwrightで確認ダイアログ、DELETE呼び出し、匿名化後表示を固定した。
- OpenAPIを更新し、Frontend型を再生成した。

## 改善点

- project membership認可が未実装のため、削除/匿名化を実ユーザー権限で制御できない。
- key rotation手順、KMS連携、環境別key保管方針は未実装である。
- 既存backup内の平文データ削除は、この実装だけでは保証できない。
- `conversation_summary_drafts` のJSON本文は暗号化ではなくretention/anonymizationで保護しているため、180日以内のDB漏洩リスクは残る。
- 匿名化は論理的な本文削除であり、物理削除やlegal holdの設計は未実装。
- Frontendはhappy path中心で、匿名化失敗、キャンセル、権限エラー、期限切れ表示のモバイルE2Eが不足している。

## 優先順位

- P0: project membership認可と実ユーザーactorのAuditLog連携。
- P0: production key管理、rotation、backup削除方針の追加ADR。
- P0: summary draft JSON本文の暗号化またはより短いretention検討。
- P1: 匿名化失敗/キャンセル/期限切れ表示のFrontend E2E。
- P1: retention jobのstaging/production worker smoke。
- P2: DM関連UIをworkspace-clientからcomponent分割。

## 次アクション

1. project membership/Policy ObjectのIssueを切り、削除/承認/閲覧権限を定義する。
2. key rotationとbackup削除方針ADRを追加する。
3. summary draft JSON本文の暗号化可否を検証する。
4. retention jobをstaging worker smoke runbookへ追加する。
5. Frontendの失敗系E2Eを追加する。

## 検証結果

- `bundle exec rails db:migrate`: success
- `RAILS_ENV=test bundle exec rails db:migrate`: success
- `bundle exec rspec spec/requests/api/v1/conversation_imports_spec.rb`: 10 examples, 0 failures
- `bundle exec rspec`: 167 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: success
- `npm run display:check`: success
- `npm run frontend:build`: success
- `npm run frontend:e2e -- e2e/meeting-workspace.spec.ts --grep "imports, scans"`: 1 passed

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | DM由来テキストをproduction blockerから一段引き下げる |
| Strategy | 暗号化、保持期限、匿名化、監査を小さな縦sliceで実装 |
| Tactics | AR Encryption、retention timestamps、DELETE endpoint、retention job、request spec、Playwright |
| Assessment | MVPとして条件付き合格。ただし認可、key rotation、backup削除は未完了 |
| Conclusion | ISSUE-029の初期実装sliceは完了。production-ready判定には追加P0が必要 |
| Knowledge | DMデータ保護は単一機能ではなく、暗号化、期限、削除、認可、監査、backup運用の総合品質で決まる |

## STRIDE / OWASP

| 観点 | 現状 | 残リスク |
| --- | --- | --- |
| Spoofing | actorはsystem固定 | 実ユーザー認証/認可が未接続 |
| Tampering | 匿名化操作はAuditLogへ記録 | 管理者操作の否認防止は不十分 |
| Repudiation | safe metadataで削除理由を保存 | 実行者、承認者、二者確認は未実装 |
| Information Disclosure | raw/redacted textは暗号化、期限切れ匿名化あり | summary JSON、backup、key管理が残る |
| Denial of Service | batch sizeあり | 大量データ時の実行時間監視が必要 |
| Elevation of Privilege | APIはproject scopedではある | membership policy未実装 |

## AIレビュー比較

Codex一次レビューのみ。Claude、ChatGPTなど外部AIレビューは未実施。外部レビュー結果が追加された場合は、key管理、backup削除、JSON暗号化、認可の相違点を分析する。
