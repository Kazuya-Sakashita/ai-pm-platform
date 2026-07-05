# Discord DM Structured Outputs provider implementation review

## 評価日時

2026-07-05 16:57:42 JST

## 評価担当

Codex as Product Owner / CTO / Tech Lead / AI Architect / Backend Architect / Security Engineer / QA / Product Manager

## 使用フレームワーク

- G-STACK
- DDD
- STRIDE
- OWASP Top 10
- ISO25010
- DORA Metrics

## Issue番号

- ISSUE-035
- GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/35

## 評価対象

- `ConversationSummaryGeneration::OpenaiProvider`
- `ConversationSummaryGeneration::ProviderFactory`
- `ConversationSummaryGenerationService`
- `ConversationImportsController#generate_summary`
- DM整理schema/prompt docs
- request spec / service spec / provider spec

## 良かった点

- Responses API + Structured Outputs providerをDM整理へ接続し、`strict: true` のJSON schemaでsummary、decisions、action_items、Issue候補、要件候補、risk、source_quotesを契約化した。
- `CONVERSATION_SUMMARY_GENERATION_PROVIDER` のデフォルトを `deterministic` にし、通常CIやローカル検証で外部OpenAI通信が発生しないようにした。
- `openai` 強制時、API key未設定、rate limit、upstream failure、transport failure、invalid responseをsafe errorへ変換する契約を追加した。
- providerはready gate通過後に遅延構築されるため、blocked/draft/archived importではOpenAI providerを構築しない。
- provider失敗時にconversation importを `ready_for_ai` へ戻すため、rate limitなどの一時失敗後に再試行できる。
- `request_id` をAPI error details、Job/AuditLog metadataへ残し、raw provider responseやDM本文を保存しない。
- schema docとmanual smoke手順を `docs/ai/` に保存した。

## 改善点

- 実OpenAI API smokeは未実施であり、現時点の品質保証はstubbed contractとCIに限定される。
- schemaは厳格化したが、実DMでの抽出精度、source quoteの妥当性、confidence calibrationは未評価である。
- provider実装はMinutes providerと似たHTTP/normalization処理を持つため、将来的には共通OpenAI Responses clientへ抽出したい。
- 実認証/JWT actor identityが未実装のため、production-gradeの生成者監査はISSUE-039待ちである。
- OpenAI providerのretry/backoffやobservability dashboardは未実装である。

## 優先順位

| Priority | 残課題 | 対応Issue |
| --- | --- | --- |
| P0 | 実認証/JWT actor identity | ISSUE-039 |
| P1 | live OpenAI DM summary smokeの実施証跡 | 新規またはISSUE-035追記 |
| P1 | DM整理draft編集UI | ISSUE-036 |
| P1 | Review Center連動 | ISSUE-037 |
| P2 | OpenAI Responses client共通化 | 新規Issue候補 |
| P2 | 実DM評価セットとquality score | 新規Issue候補 |

## 次アクション

1. GitHub Issue #35へ実装結果を同期する。
2. CI成功後に #35 をcloseする。
3. 次はproduction blockerを優先するならISSUE-039、UIワークフローを優先するならISSUE-036へ進む。

## 検証結果

- `bundle exec rspec spec/services/conversation_summary_generation/openai_provider_spec.rb spec/services/conversation_summary_generation_service_spec.rb spec/requests/api/v1/conversation_imports_spec.rb`: 27 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: success
- `npm run display:check`: success
- `npm run frontend:build`: success
- `bundle exec rspec`: 194 examples, 0 failures
- `npm run frontend:e2e`: 25 passed
- GitHub Actions CI `28734063674`: success（commit `5dbe0a5`）

補足: 最初の `npm run frontend:e2e` はRails API `127.0.0.1:3001` 未起動のため実APIケースが失敗した。Rails APIを起動後、同じE2E全体を再実行し25 passedを確認した。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | DM整理をOpenAI Structured Outputs providerへ接続し、schema準拠とsafe failureを検証可能にする |
| Strategy | deterministic defaultを維持し、OpenAI経路はENVで明示的に有効化する |
| Tactics | provider/factory、strict schema、safe error mapping、request_id、spec、manual smoke docs |
| Assessment | ISSUE-035のstubbed contractとして合格。ただしlive smokeと実データ品質評価は未完了 |
| Conclusion | #35はCI成功後にclose可能。次は#39または#36へ進む |
| Knowledge | AI provider接続は、実API疎通より先に「外部送信条件」「schema」「失敗時監査」を固定すると安全に前進できる |

## STRIDE / OWASP観点

| 観点 | 実装評価 | 残リスク |
| --- | --- | --- |
| Information Disclosure | blocked importではproviderを構築せず、redacted/safe textだけを送る | 実DMでの検出漏れはISSUE-038の限界に依存 |
| Repudiation | request_idをAPI/Job/AuditLogへ残す | 実ユーザーidentityはISSUE-039待ち |
| Tampering | prompt injectionをdeveloper instructionとstrict schemaで抑制 | 実モデル評価は未実施 |
| OWASP A01 | Policy Object上のgenerate_summary guardを維持 | DM以外のAPI横展開は別Issue |
| OWASP A09 | raw OpenAI responseやDM本文をログに保存しない | 外部APM設定確認は未実施 |

## 判定

合格。ISSUE-035の実装条件は満たした。ただし世界レベルSaaS基準では、live smoke、実認証/JWT、実データ評価、OpenAI共通client化を次の改善として扱う。

## AIレビュー比較

Codex一次レビューのみ。Claude、ChatGPTなど外部AIレビューは未実施。外部レビュー結果が追加された場合は、schema厳密性、source quote設計、prompt injection対策、manual smoke十分性を比較する。
