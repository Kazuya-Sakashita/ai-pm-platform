# Requirement生成OpenAI provider比較評価

## ISSUE-052比較サマリー

- 評価日時: 2026-07-07 11:53:20 JST
- 対象Issue: ISSUE-052 / GitHub Issue #69
- deterministic provider fixture評価: 合格、平均100.0 / 100、P0未達0件、Critical failure 0件
- OpenAI provider contract評価: RSpecでResponses API payload、`json_schema`、`strict: true`、`store: false`、safe error、request id、secret/PII送信前blockを確認済み
- OpenAI live fixture評価: 未実施。ローカル環境に実OpenAI API keyを置かず、通常CIを外部API依存にしない方針のため
- 比較判定: 条件付き合格。実装contractとdeterministic baselineは合格だが、実OpenAI出力品質はmanual smoke完了まで未確定

## 比較結果

| 観点 | deterministic | OpenAI provider | 判定 |
| --- | --- | --- | --- |
| 通常CI安定性 | 明示的に合格 | 通常CIでは未使用 | 合格 |
| provider選択 | 未設定default | `openai` または明示 `auto` 指定時のみ | 合格 |
| schema制約 | provider内の固定構造 | Responses API `json_schema` + app側検証 | 合格 |
| secret/PII送信前block | Serviceで共通block | provider構築前に共通block | 合格 |
| safe error | provider error contract | API key未設定、429、5xx、invalid schema、output欠落をsafe error化 | 合格 |
| request id監査 | 外部requestなし | ProviderError、AuditLog、API detailsへ連携 | 合格 |
| fixture品質 | 平均100.0 / 100 | live評価未実施 | 要manual smoke |

## OpenAI manual smoke手順

通常CIでは実行しない。実API検証を行う場合は、安全な検証用Minutesだけを使い、以下を実行する。

```bash
REQUIREMENT_GENERATION_PROVIDER=openai \
OPENAI_API_KEY=... \
OPENAI_REQUIREMENT_MODEL=gpt-5.5 \
bundle exec ruby ../scripts/evaluate-requirement-generation.rb \
  --provider openai \
  --output docs/evaluation/20260707_requirement_generation_openai_provider_live.md \
  --quiet
```

manual smoke完了時は、model名、実行日時、request id、P0未達有無、Critical failure有無、外部AIレビュー待ち有無を追記する。

## deterministic baseline詳細

## メタデータ

- 生成日時: 2026-07-07T02:54:00Z
- Issue番号: ISSUE-003
- Fixture version: 2026-07-06.requirement-generation.v1
- Provider: deterministic
- 判定: 合格
- 平均点: 100.0 / 100

## ケース別スコア

| ケース | タイトル | 点数 | Critical failure |
| --- | --- | ---: | --- |
| CASE-RQ-001 | 標準的なMVP要件化 | 100.0 | なし |
| CASE-RQ-002 | 矛盾と未決事項の抽出 | 100.0 | なし |
| CASE-RQ-003 | セキュリティと機微情報 | 100.0 | なし |
| CASE-RQ-004 | API駆動開発への接続 | 100.0 | なし |
| CASE-RQ-005 | 情報不足の短い会議 | 100.0 | なし |
| CASE-RQ-006 | UXと運用要件が強い会議 | 100.0 | なし |

## P0基準未達

- なし

## 詳細

### CASE-RQ-001: 標準的なMVP要件化

点数: 100.0

| 評価カテゴリ | 点数 | 満点 |
| --- | ---: | ---: |
| fidelity | 15.0 | 15 |
| structure | 10.0 | 10 |
| traceability | 12.0 | 12 |
| ambiguity | 12.0 | 12 |
| acceptance | 12.0 | 12 |
| scope | 12.0 | 12 |
| non_functional | 10.0 | 10 |
| readiness | 10.0 | 10 |
| readability | 5.0 | 5 |
| generated_by_model | 2.0 | 2 |

検出結果:

- 入力Minutesの重要語: 4/4
- 構造: 必須項目 10/10、最小件数 4/4
- 根拠追跡性: source term 4/4
- 未決事項: 1/1
- 受け入れ条件の期待語: 2/2
- 受け入れ条件: 検証可能表現 3/3
- スコープ外: 2/2
- 非機能要件: 2/2
- Issue/OpenAPI readiness: FR形式 3/3
- レビュー容易性: 180文字以内 16/16、重複 0

### CASE-RQ-002: 矛盾と未決事項の抽出

点数: 100.0

| 評価カテゴリ | 点数 | 満点 |
| --- | ---: | ---: |
| fidelity | 15.0 | 15 |
| structure | 10.0 | 10 |
| traceability | 12.0 | 12 |
| ambiguity | 12.0 | 12 |
| acceptance | 12.0 | 12 |
| scope | 12.0 | 12 |
| non_functional | 10.0 | 10 |
| readiness | 10.0 | 10 |
| readability | 5.0 | 5 |
| generated_by_model | 2.0 | 2 |

検出結果:

- 入力Minutesの重要語: 3/3
- 構造: 必須項目 10/10、最小件数 4/4
- 根拠追跡性: source term 3/3
- 未決事項: 3/3
- 受け入れ条件の期待語: 2/2
- 受け入れ条件: 検証可能表現 2/2
- スコープ外: 1/1
- 非機能要件: 2/2
- Issue/OpenAPI readiness: FR形式 2/2
- レビュー容易性: 180文字以内 14/14、重複 0

### CASE-RQ-003: セキュリティと機微情報

点数: 100.0

| 評価カテゴリ | 点数 | 満点 |
| --- | ---: | ---: |
| fidelity | 15.0 | 15 |
| structure | 10.0 | 10 |
| traceability | 12.0 | 12 |
| ambiguity | 12.0 | 12 |
| acceptance | 12.0 | 12 |
| scope | 12.0 | 12 |
| non_functional | 10.0 | 10 |
| readiness | 10.0 | 10 |
| readability | 5.0 | 5 |
| generated_by_model | 2.0 | 2 |

検出結果:

- 入力Minutesの重要語: 3/3
- 構造: 必須項目 10/10、最小件数 5/5
- 根拠追跡性: source term 3/3
- 未決事項: 2/2
- 受け入れ条件の期待語: 2/2
- 受け入れ条件: 検証可能表現 3/3
- スコープ外: 1/1
- 非機能要件: 5/5
- Issue/OpenAPI readiness: FR形式 3/3
- レビュー容易性: 180文字以内 19/19、重複 0

### CASE-RQ-004: API駆動開発への接続

点数: 100.0

| 評価カテゴリ | 点数 | 満点 |
| --- | ---: | ---: |
| fidelity | 15.0 | 15 |
| structure | 10.0 | 10 |
| traceability | 12.0 | 12 |
| ambiguity | 12.0 | 12 |
| acceptance | 12.0 | 12 |
| scope | 12.0 | 12 |
| non_functional | 10.0 | 10 |
| readiness | 10.0 | 10 |
| readability | 5.0 | 5 |
| generated_by_model | 2.0 | 2 |

検出結果:

- 入力Minutesの重要語: 3/3
- 構造: 必須項目 10/10、最小件数 4/4
- 根拠追跡性: source term 3/3
- 未決事項: 1/1
- 受け入れ条件の期待語: 2/2
- 受け入れ条件: 検証可能表現 3/3
- スコープ外: 3/3
- 非機能要件: 3/3
- Issue/OpenAPI readiness: FR形式 3/3
- レビュー容易性: 180文字以内 19/19、重複 0

### CASE-RQ-005: 情報不足の短い会議

点数: 100.0

| 評価カテゴリ | 点数 | 満点 |
| --- | ---: | ---: |
| fidelity | 15.0 | 15 |
| structure | 10.0 | 10 |
| traceability | 12.0 | 12 |
| ambiguity | 12.0 | 12 |
| acceptance | 12.0 | 12 |
| scope | 12.0 | 12 |
| non_functional | 10.0 | 10 |
| readiness | 10.0 | 10 |
| readability | 5.0 | 5 |
| generated_by_model | 2.0 | 2 |

検出結果:

- 入力Minutesの重要語: 2/2
- 構造: 必須項目 10/10、最小件数 4/4
- 根拠追跡性: source term 2/2
- 未決事項: 5/5
- 受け入れ条件の期待語: 2/2
- 受け入れ条件: 検証可能表現 1/1
- スコープ外: 2/2
- 非機能要件: 2/2
- Issue/OpenAPI readiness: FR形式 1/1
- レビュー容易性: 180文字以内 15/15、重複 0

### CASE-RQ-006: UXと運用要件が強い会議

点数: 100.0

| 評価カテゴリ | 点数 | 満点 |
| --- | ---: | ---: |
| fidelity | 15.0 | 15 |
| structure | 10.0 | 10 |
| traceability | 12.0 | 12 |
| ambiguity | 12.0 | 12 |
| acceptance | 12.0 | 12 |
| scope | 12.0 | 12 |
| non_functional | 10.0 | 10 |
| readiness | 10.0 | 10 |
| readability | 5.0 | 5 |
| generated_by_model | 2.0 | 2 |

検出結果:

- 入力Minutesの重要語: 3/3
- 構造: 必須項目 10/10、最小件数 4/4
- 根拠追跡性: source term 3/3
- 未決事項: 2/2
- 受け入れ条件の期待語: 2/2
- 受け入れ条件: 検証可能表現 3/3
- スコープ外: 2/2
- 非機能要件: 5/5
- Issue/OpenAPI readiness: FR形式 3/3
- レビュー容易性: 180文字以内 19/19、重複 0
