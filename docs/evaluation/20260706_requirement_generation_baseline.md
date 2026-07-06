# Requirement生成品質ベースライン

## メタデータ

- 生成日時: 2026-07-06T11:07:01Z
- Issue番号: ISSUE-003
- Fixture version: 2026-07-06.requirement-generation.v1
- Provider: deterministic
- 判定: 基準未達
- 平均点: 91.0 / 100

## ケース別スコア

| ケース | タイトル | 点数 | Critical failure |
| --- | --- | ---: | --- |
| CASE-RQ-001 | 標準的なMVP要件化 | 100.0 | なし |
| CASE-RQ-002 | 矛盾と未決事項の抽出 | 100.0 | なし |
| CASE-RQ-003 | セキュリティと機微情報 | 79.2 | なし |
| CASE-RQ-004 | API駆動開発への接続 | 88.0 | なし |
| CASE-RQ-005 | 情報不足の短い会議 | 94.0 | なし |
| CASE-RQ-006 | UXと運用要件が強い会議 | 85.0 | なし |

## P0基準未達

- CASE-RQ-003: スコープ制御と幻覚耐性 0.0/12
- CASE-RQ-003: 非機能、セキュリティ、監査 2.0/10
- CASE-RQ-004: スコープ制御と幻覚耐性 0.0/12
- CASE-RQ-005: スコープ制御と幻覚耐性 6.0/12
- CASE-RQ-006: スコープ制御と幻覚耐性 6.0/12
- CASE-RQ-006: 非機能、セキュリティ、監査 2.0/10

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

点数: 79.2

| 評価カテゴリ | 点数 | 満点 |
| --- | ---: | ---: |
| fidelity | 15.0 | 15 |
| structure | 9.2 | 10 |
| traceability | 12.0 | 12 |
| ambiguity | 12.0 | 12 |
| acceptance | 12.0 | 12 |
| scope | 0.0 | 12 |
| non_functional | 2.0 | 10 |
| readiness | 10.0 | 10 |
| readability | 5.0 | 5 |
| generated_by_model | 2.0 | 2 |

検出結果:

- 入力Minutesの重要語: 3/3
- 構造: 必須項目 10/10、最小件数 4/5
- 根拠追跡性: source term 3/3
- 未決事項: 2/2
- 受け入れ条件の期待語: 2/2
- 受け入れ条件: 検証可能表現 3/3
- スコープ外: 0/1
- 非機能要件: 1/5
- Issue/OpenAPI readiness: FR形式 3/3
- レビュー容易性: 180文字以内 16/16、重複 0

### CASE-RQ-004: API駆動開発への接続

点数: 88.0

| 評価カテゴリ | 点数 | 満点 |
| --- | ---: | ---: |
| fidelity | 15.0 | 15 |
| structure | 10.0 | 10 |
| traceability | 12.0 | 12 |
| ambiguity | 12.0 | 12 |
| acceptance | 12.0 | 12 |
| scope | 0.0 | 12 |
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
- スコープ外: 0/3
- 非機能要件: 3/3
- Issue/OpenAPI readiness: FR形式 3/3
- レビュー容易性: 180文字以内 16/16、重複 0

### CASE-RQ-005: 情報不足の短い会議

点数: 94.0

| 評価カテゴリ | 点数 | 満点 |
| --- | ---: | ---: |
| fidelity | 15.0 | 15 |
| structure | 10.0 | 10 |
| traceability | 12.0 | 12 |
| ambiguity | 12.0 | 12 |
| acceptance | 12.0 | 12 |
| scope | 6.0 | 12 |
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
- スコープ外: 1/2
- 非機能要件: 2/2
- Issue/OpenAPI readiness: FR形式 1/1
- レビュー容易性: 180文字以内 14/14、重複 0

### CASE-RQ-006: UXと運用要件が強い会議

点数: 85.0

| 評価カテゴリ | 点数 | 満点 |
| --- | ---: | ---: |
| fidelity | 15.0 | 15 |
| structure | 9.0 | 10 |
| traceability | 12.0 | 12 |
| ambiguity | 12.0 | 12 |
| acceptance | 12.0 | 12 |
| scope | 6.0 | 12 |
| non_functional | 2.0 | 10 |
| readiness | 10.0 | 10 |
| readability | 5.0 | 5 |
| generated_by_model | 2.0 | 2 |

検出結果:

- 入力Minutesの重要語: 3/3
- 構造: 必須項目 10/10、最小件数 3/4
- 根拠追跡性: source term 3/3
- 未決事項: 2/2
- 受け入れ条件の期待語: 2/2
- 受け入れ条件: 検証可能表現 3/3
- スコープ外: 1/2
- 非機能要件: 1/5
- Issue/OpenAPI readiness: FR形式 3/3
- レビュー容易性: 180文字以内 16/16、重複 0
