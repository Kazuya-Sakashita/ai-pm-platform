---
name: rspec
description: RSpec設計と実装用Skill。Request spec、Service spec、Policy spec、Job specを追加し、let!中心でデータ準備を揃えるときに使う。
---

# RSpec

## Purpose

Rails実装の振る舞い、権限、安全性、回帰をRSpecで固定する。

## When to use

- Backend実装を変更したとき。
- API contract、認可、AuditLog、Job、Serviceを検証するとき。
- 既存RSpecが不安定または読みづらいとき。

## Inputs

- 対象クラス、API、期待挙動。
- factory、helper、既存spec。
- 失敗ケースと権限パターン。

## Process

1. 重要な成功系と失敗系を決める。
2. データ準備は `let!` を基本に揃える。
3. Request specではHTTP status、error code、safe responseを確認する。
4. Service specでは分岐、Result、AuditLogを確認する。
5. secret、raw exception、PIIが出ないことを確認する。
6. 対象specから実行し、必要なら全体を実行する。

## Output

- 読みやすいRSpec。
- 成功/失敗/権限/安全性の検証結果。

## Constraints

- `let` と `let!` の混在を避ける。
- 外部APIはstubまたはadapter差し替えを使う。
- flakyな時間依存はfreeze/travelで固定する。

## Checklist

- [ ] 成功系がある。
- [ ] 失敗系がある。
- [ ] 権限拒否がある。
- [ ] safe responseを確認した。
- [ ] 対象specが成功した。
