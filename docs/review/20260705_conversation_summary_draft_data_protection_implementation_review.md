# Conversation Summary Draft データ保護実装レビュー

## 評価日時

2026-07-05 10:13:57 JST

## 評価担当

Codex / Security Engineer / CTO / Backend Architect / Tech Lead / QA / Product Manager

## 使用フレームワーク

- G-STACK
- STRIDE
- ISO25010
- OWASP Top 10

## 対象

- GitHub Issue: #32
- `ConversationSummaryDraft`
- `conversation_summary_drafts.protected_payload`
- `docs/security/20260705_conversation_summary_draft_data_classification.md`
- `docs/decisions/ADR-0014_conversation_summary_draft_protected_payload.md`

## 良かった点

- `summary`、候補JSON、`source_quotes`、`validation_errors` を暗号化payloadへ集約し、DB dump単体でDM由来本文を読みにくくした。
- OpenAPIレスポンスの形を変えず、既存Frontend/API互換を維持した。
- 旧 `summary` / JSONB列を削除せず、`暗号化済み` と空配列へ無害化することで段階migrationとrollbackの余地を残した。
- request specでAPIレスポンス、DB保存値、匿名化後レスポンスを検証した。
- model specでmigration backfill相当の `update_columns` 経路でも暗号化属性が平文保存されないことを確認した。
- `reload` 後に古いpayload cacheを返す不具合をテスト中に検出し、属性値連動のcacheへ修正した。

## 改善点

- アプリケーション権限と暗号鍵の両方を取得された場合は復号可能であり、KMS/rotation/監査の運用実装が必要。
- Project membership認可が未実装のため、復号後APIレスポンスのアクセス制御はISSUE-030に依存している。
- 旧backupにはmigration前の平文summary draftが残る可能性があるため、restore前retention/anonymization replayの実運用証跡が必要。
- summary draft本文検索は非対応になった。検索要件が出た場合、安全な派生index設計が必要。
- 一覧APIでlatest summary draftを含める場合、件数増加時の復号コスト計測が未実施。

## 優先順位

| 優先度 | 内容 | 状態 |
| --- | --- | --- |
| P0 | summary draft派生本文の暗号化payload保存 | 完了 |
| P0 | DB保存値にセンシティブ本文が残らないrequest spec | 完了 |
| P0 | 匿名化後レスポンスにセンシティブ本文が残らないrequest spec | 完了 |
| P1 | ISSUE-029へ結果同期 | 完了 |
| P1 | Project membership認可 | ISSUE-030で継続 |
| P2 | summary draft検索/一覧復号性能評価 | 将来Issue候補 |

## 検証結果

- `bundle exec rails db:migrate`: success
- `bundle exec rspec spec/models/conversation_summary_draft_spec.rb spec/requests/api/v1/conversation_summary_drafts_spec.rb spec/requests/api/v1/conversation_imports_spec.rb`: 17 examples, 0 failures
- `bundle exec rspec`: 170 examples, 0 failures
- `npm run api:verify`: success

補足: `npm run api:verify` で Node `v22.7.0` が期待範囲 `>=22.12.0 || >=20.19.0 <21.0.0` を満たさない警告が出たが、OpenAPI lintとtype生成は成功した。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | DB dump単体にAI整理本文を残さない |
| Strategy | API互換を維持し、保存層だけ暗号化payloadへ移行 |
| Tactics | migration、model accessor、request/model spec、ADR、security doc |
| Assessment | P0リスクは下がったが、認可/KMS/backup restore証跡は継続課題 |
| Conclusion | ISSUE-032は完了可能。次はISSUE-030の認可境界へ進むべき |
| Knowledge | Active Record Encryption、ADR-0013、STRIDE、ISO25010 |

## STRIDE

| 脅威 | 評価 | 対応 |
| --- | --- | --- |
| Spoofing | 復号APIの利用者認証/認可が未成熟 | ISSUE-030 |
| Tampering | payload/旧列の不整合 | model accessorとspecで保護 |
| Repudiation | 閲覧AuditLogは未実装 | 将来のaccess auditで対応 |
| Information Disclosure | DB平文保存が主要リスク | `protected_payload` 暗号化で軽減 |
| Denial of Service | 復号回数増加 | 一覧性能を別途監視 |
| Elevation of Privilege | key漏えい時は復号可能 | ADR-0013のKMS/rotation方針 |

## OWASP Top 10

| 項目 | 評価 |
| --- | --- |
| A01 Broken Access Control | ISSUE-030まで残リスク |
| A02 Cryptographic Failures | 保存時暗号化で改善。鍵管理はADR-0013で継続 |
| A04 Insecure Design | 派生データを機密分類し、設計レビューを保存 |
| A09 Security Logging and Monitoring Failures | AuditLogは本文非保存。閲覧監査は未実装 |

## 次アクション

1. GitHub Issue #32へ実装結果を同期してクローズする。
2. GitHub Issue #29へISSUE-032完了結果を追記する。
3. 次の推奨順としてISSUE-030のProject membership/Policy Objectへ進む。

## Issue番号

- #32
