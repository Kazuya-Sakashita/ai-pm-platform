---
name: rails-backend
description: Rails Backend実装用Skill。Controller/Model肥大化を避け、Service、Result、Query、Policy、Serializerへ責務分離しながらAPIやJobを実装するときに使う。
---

# Rails Backend

## Purpose

Rails実装を保守しやすく、監査可能な責務分離で進める。

## When to use

- Rails Controller、Model、Service、Job、Request specを変更するとき。
- 認証、認可、AuditLog、外部連携を扱うとき。
- 複雑な条件分岐や業務処理があるとき。

## Inputs

- 対象API contract。
- 関連Model、Service、Policy。
- RSpec対象。

## Process

1. Controllerは受付、認可、入力、レスポンスに限定する。
2. 業務処理はService Objectへ分離する。
3. 成功/失敗はResult Objectまたは明確な戻り値で扱う。
4. 一覧や検索はQuery Objectを検討する。
5. API JSONはSerializerまたは既存api_jsonに寄せる。
6. AuditLogとsafe errorを確認する。
7. Request specとService specを追加する。

## Output

- 責務が分離されたRails実装。
- RSpec。
- 必要なAuditLogとsafe error。

## Constraints

- Modelに複雑な業務処理を詰め込まない。
- Controllerに外部APIやDB操作の詳細を寄せない。
- 過剰設計しない。
- raw secret、raw exception、不要PIIを返さない。

## Checklist

- [ ] Controllerが薄い。
- [ ] Service/Query/Policyの責務が明確。
- [ ] 認可がある。
- [ ] AuditLogが必要な箇所にある。
- [ ] RSpecがある。
