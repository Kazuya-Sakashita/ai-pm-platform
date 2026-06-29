# 20260630_discord_minutes_backend_slice_review

## 評価日時

2026-06-30 07:51 JST

## 評価担当

Codex as Product Owner, CTO, Tech Lead, AI Architect, Backend Architect, QA, Security Engineer

## 使用フレームワーク

G-STACK、DDD、ISO25010、STRIDE、HEART

## 評価対象

- GitHub Issue #2
- `backend/app/controllers/api/v1/minutes_controller.rb`
- `backend/app/models/minute.rb`
- `backend/app/services/minutes_generation_service.rb`
- `backend/spec/requests/api/v1/minutes_spec.rb`
- `backend/spec/requests/api/v1/reviews_spec.rb`
- `docs/api/openapi.yaml`

## 良かった点

- Discordログ手動貼り付けを `source_type: discord_log` として保存し、Minutes生成へ接続した。
- deterministic placeholderにより、summary、decisions、open_questions、action_itemsを分離して保存できる。
- Minutes show/update/approveを追加し、Meeting Workspaceの主要導線に必要なBackend APIが揃い始めた。
- Minutes review resultを既存Reviews APIで保存できることをrequest specで確認した。
- JobsとAuditLogsへMinutes生成を記録し、後続のAI/worker実装へ接続しやすい。
- OpenAPI contractとTypeScript schemaを更新し、`api:verify` を通した。

## 改善点

- 実OpenAI APIは未接続であり、現状はAI生成ではなくplaceholder生成である。世界レベルSaaS基準では、この状態でGitHub #2を完了扱いにしてはいけない。
- deterministic parserは日本語/英語の簡易keyword抽出であり、品質評価、幻覚対策、引用根拠、confidence scoreがない。
- 生成jobは同期実行で即時 `succeeded` になっており、将来の非同期worker/queueとはまだ乖離がある。
- Minutes生成時のPII redaction、secret scan、raw_text暗号化は未実装。
- FrontendからMeeting作成、Generate Minutes、Review requestを実行するUI接続が未実装。

## 優先順位

1. P0: OpenAI-backed minutes generation providerを追加する
2. P0: 生成prompt、JSON schema、fallback、error maskingを設計する
3. P0: Meeting Workspace UIからMeeting/Minutes APIを呼ぶ
4. P0: Minutes生成結果に対するreview request導線を接続する
5. P1: Async job/worker化する
6. P1: raw_textとAI出力の暗号化、PII/secret redactionを追加する

## 次アクション

- GitHub #2はOPENのまま維持する。
- 次はOpenAI-backed minutes generation provider、またはMeeting Workspace UI接続を進める。
- OpenAI接続前にprompt/JSON schema/error maskingの小さなADRまたはAI設計docを追加する。

## Issue番号

ISSUE-002 / GitHub #2

GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/2
