# 2026-06-30 OpenAI Minutes Generation Provider 実装レビュー

## 評価日時

2026-06-30 09:10 JST

## 評価担当

Codex as Product Owner / CTO / Tech Lead / AI Architect / Backend Architect / Security Engineer / QA / Product Manager

外部AIレビュー: 未実施。Claude / ChatGPT 等の別AIレビューは追加待ち。

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- RICE

## 良かった点

- deterministic placeholderからprovider構成へ分離し、CIでは外部通信なし、本番ではOpenAI連携という運用現実に合う形にした。
- Responses APIとStructured Outputsを使い、議事録のsummary、decisions、open_questions、action_itemsを契約化した。
- OpenAI失敗時に成功扱いせず、failed job、safe error、audit logを残すようにした。
- OpenAI送信前に明確なsecret patternをブロックし、最小限のデータ漏洩対策を入れた。
- request specとservice specで、成功経路、未接続、sensitive content、invalid AI responseを検証した。

## 改善点

- 実OpenAI API keyでのlive検証は未実施。世界レベルSaaS基準では、本番相当のAPI疎通、レート制限、失敗時再試行、observability確認が必要。
- secret scanは初期patternであり、PII redaction、機密文脈の低信頼検出、ユーザー確認フローは未実装。
- raw_textとAI outputの暗号化、保持期間、削除ポリシーが未実装。
- 現在は同期処理であり、長文会議や外部API遅延に対してworker/retry/timeout管理が不足している。
- model/promptの評価指標、回帰テスト用fixture、human review accuracy評価が未整備。
- Frontend Meeting Workspaceから生成、修正、レビュー依頼までを一気通貫で操作できない。

## 優先順位

1. P0: Meeting Workspace UIからMeeting作成、Minutes生成、生成結果表示を接続する
2. P0: 生成結果に対するReview request導線を接続する
3. P0: 本番OpenAI API keyを使ったlive smoke test手順を作る
4. P1: worker化、retry、rate limit、idempotencyの実装
5. P1: PII redaction、raw_text暗号化、retention policyを追加する
6. P1: prompt/output fixtureによるAI品質回帰テストを追加する

## 次アクション

- ISSUE-002の次sliceとしてFrontend Meeting Workspace API接続を進める。
- OpenAI live検証はAPI key設定後に実施し、結果をこのレビューまたは別レビューへ追記する。
- ISSUE-006でsecret scan強化、PII redaction、保存データ暗号化を扱う。

## Issue番号

- GitHub Issue: #2

## G-STACK

### Goal

DiscordログからAI議事録を生成し、次工程の要件定義へ進める信頼できるBackend能力を作る。

### Strategy

OpenAI providerを直接本番経路にしつつ、deterministic fallbackを維持して開発速度とテスト安定性を両立する。

### Tactics

- Provider interfaceを導入
- Responses API + Structured OutputsでJSON契約化
- failed jobとaudit logで失敗を監査可能にする
- secret scanで送信前ブロックを入れる

### Assessment

Backend能力は前進したが、まだUI未接続、live API未検証、security hardening不足がある。ISSUE-002をcloseするには早い。

### Conclusion

このsliceは採用。ただし完成扱いではなく、Meeting Workspace UI接続とlive smoke testが次のP0。

### Knowledge

OpenAI model/APIは変化しやすいため、`OPENAI_MINUTES_MODEL` による差し替えを前提とし、model固定に依存しすぎない。

## STRIDE

| 脅威 | 評価 | 対応 |
| --- | --- | --- |
| Spoofing | API key未設定や誤設定を424で検出 | 環境設定レビューが必要 |
| Tampering | transcript内prompt injectionをdeveloper promptで明示拒否 | AI評価fixtureが必要 |
| Repudiation | failed/succeeded jobとaudit logを保存 | actor_id強化は未実装 |
| Information Disclosure | secret patternを送信前ブロック | PII redactionは未実装 |
| Denial of Service | timeout設定あり | rate limit/retry/worker化は未実装 |
| Elevation of Privilege | providerは権限変更をしない | tenant/auth実装後に再評価 |

## 判定

条件付き合格。

ISSUE-002のBackend AI生成sliceとしては前進。ただし、世界レベルSaaS基準ではUI接続、live検証、セキュリティ強化が未完了のため、GitHub #2はopenのまま継続する。

## 検証結果

- `npm run api:verify`: 成功。OpenAPI contract warningなし。Node version warningのみ既知。
- `bundle exec rspec`: 24 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- 本番OpenAI API keyによるlive generation: 未実施
