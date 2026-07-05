# Discord DM Structured Outputs provider design review

## 評価日時

2026-07-05 16:35:44 JST

## 評価担当

Codex as Product Owner / CTO / Tech Lead / AI Architect / Backend Architect / Security Engineer / QA / Product Manager

## 使用フレームワーク

- G-STACK
- DDD
- STRIDE
- OWASP Top 10
- ISO25010

## Issue番号

- ISSUE-035
- GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/35

## 評価対象

Discord DM整理の `ConversationSummaryGenerationService`、provider境界、OpenAI Structured Outputs接続、safe failure contract。

## 良かった点

- Minutes生成でResponses API + Structured Outputs providerの既存実装があり、DM整理でも同じ失敗契約とHTTP client構造を再利用できる。
- ISSUE-038でAI送信前のPII/credential scan gateが強化済みであり、OpenAI接続前の最低限の安全条件が整った。
- `ConversationSummaryDraft` はsummary/decisions/source_quotesなどを暗号化payloadへ保存するため、派生AI出力の保存先としてはISSUE-032の保護方針に乗れる。
- ControllerはJobとAuditLogを既に持っており、provider failureをfailed jobとして保存できる。

## 改善点

- 現状のDM整理はdeterministic provider固定で、実AI品質、schema準拠、invalid response、rate limitのcontractが検証されていない。
- `ConversationSummaryGeneration::ProviderError` にrequest_idがなく、OpenAI失敗時の問い合わせ/監査がMinutes側より弱い。
- provider失敗時に `summarizing` のまま残ると再実行できないリスクがある。
- `docs/ai/20260702_discord_dm_summary_prompt_schema.md` のschema案が現在のOpenAPI schemaとずれている。
- OpenAI実API smoke手順がないため、通常CIと本番疎通検証の境界が曖昧である。

## 優先順位

| Priority | 対応 | 理由 |
| --- | --- | --- |
| P0 | OpenAI providerを明示ENV時のみ使う | CI安定性と意図しない外部送信を防ぐ |
| P0 | invalid/rate limit/upstream failureをsafe errorへ変換 | 失敗を成功扱いしない |
| P0 | blocked/not ready importではproviderを構築/呼び出ししない | AI送信前gateの保証 |
| P1 | request_idをJob/AuditLog/API detailsへ渡す | 監査と運用調査を可能にする |
| P1 | schema docとmanual smoke手順を更新 | 後続レビューと実運用検証に必要 |

## 次アクション

1. `ConversationSummaryGeneration::OpenaiProvider` を追加する。
2. `ProviderFactory` を追加し、`CONVERSATION_SUMMARY_GENERATION_PROVIDER` でdeterministic/openai/autoを切り替える。
3. service側はready gate後にproviderを遅延構築し、blocked importではOpenAI providerを呼ばない。
4. request spec/service specでOpenAI成功、未接続、rate limit、invalid response、blocked gateを固定する。
5. schema docとmanual smoke手順を更新する。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | DMからレビュー可能な整理ドラフトをStructured Outputsで生成できるようにする |
| Strategy | Minutes providerの実証済みパターンをDM整理へ横展開し、通常CIは外部通信に依存させない |
| Tactics | provider/factory、strict json_schema、safe failure、request_id、manual smoke |
| Assessment | 方針は妥当。ただし本番公開にはISSUE-039の実認証とlive smoke証跡が残る |
| Conclusion | #35はOpenAI実APIをCIに入れず、stubbed contractとmanual smoke手順で完了判定する |
| Knowledge | AI PM PlatformのAI機能は、生成品質だけでなく「送信前gate」「schema準拠」「失敗監査」が一体で品質を決める |

## STRIDE / OWASP観点

| 観点 | リスク | 設計対応 |
| --- | --- | --- |
| Information Disclosure | redacted前DMやblocked DMがOpenAIへ送信される | ready gate後にproviderを遅延構築し、blocked時は呼ばない |
| Repudiation | OpenAI失敗時のrequest idが残らない | ProviderErrorにrequest_idを追加し、Job/AuditLog/API detailsへ保存 |
| Tampering | AIがschema外の値やprompt injectionに従う | strict json_schemaとdeveloper instructionsで制約する |
| OWASP A01 | 権限外ユーザーが生成する | ISSUE-030 Policy Objectの `generate_summary` guard上で動作 |
| OWASP A09 | 失敗詳細にPIIやprovider raw bodyを出す | safe_detailだけをAPI/Jobへ保存 |

## OpenAI公式docs確認

- Structured Outputsは `text.format` または `response_format` へ `json_schema` と `strict: true` を指定する形が案内されている。
- 既存Minutes providerと同じResponses API `text.format.json_schema` 方式へ揃える。
- JSON Schemaはclearなkey/descriptionとevalでの改善が推奨されているため、DM整理schemaは後続の品質評価Issueで継続改善する。

## 判定

条件付き合格。providerの実装、stubbed spec、manual smoke手順、レビュー文書が揃えばISSUE-035の完了条件を満たせる。実OpenAI API smokeの実行証跡と実認証/JWTは後続作業として残す。

## AIレビュー比較

Codex一次レビューのみ。Claude、ChatGPTなど外部AIレビューは未実施。外部レビュー結果が追加された場合は、schema粒度、prompt injection対策、manual smokeの十分性を比較する。
