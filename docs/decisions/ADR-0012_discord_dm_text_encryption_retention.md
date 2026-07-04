# ADR-0012: Discord DM raw textは本番前に暗号化と保持期限を必須化する

## Status

Accepted

## Date

2026-07-05

## Context

Discord DM手動インポートMVPでは、ユーザーが貼り付けたDM原文、マスキング後テキスト、AI整理ドラフト、承認理由を扱う。DMは会議ログよりも個人性と機密性が高く、世界レベルSaaS基準では、単に同意チェックとsecret scanがあるだけでは本番投入に不十分である。

2026-07-05時点のBackend MVPは、OpenAPI契約、scan gate、AuditLog safe metadata、承認理由必須化を実装済みである。一方、`conversation_imports.raw_text` と `conversation_imports.redacted_text` はDB平文保存であり、認証ユーザー、project membership、削除/保持期限、鍵管理は未実装である。

## Decision

Discord DM由来テキストをproductionで扱う前に、以下を必須gateにする。

- raw textとredacted textはアプリケーション層暗号化または同等の暗号化境界で保存する。
- 暗号鍵は環境ごとに分離し、application secretやDB dump単体では復号できないようにする。
- raw textの標準保持期限は30日以内、redacted textとAI整理ドラフトの標準保持期限は180日以内にする。
- ユーザーまたはproject ownerがDMインポート単位で削除できるようにする。
- 削除時はraw/redacted textを復元不能にし、AuditLogには本文を残さず、削除実施のsafe metadataだけを残す。
- AI送信はredacted textを優先し、raw textを送る場合はscan valid、同意確認、レビュー可能なAuditLogを必須にする。
- 本番リリース判定では、暗号化、保持期限、削除/匿名化、権限、監査をセキュリティレビューのP0項目として扱う。

## Rationale

- DM原文は高センシティブデータであり、DB dump、ログ、開発者アクセス、外部AI送信のどれか一つが漏れても影響が大きい。
- raw textはレビュー根拠として価値があるが、長期保存するほどプライバシー負債が増える。
- redacted textとAI整理ドラフトは業務価値が高い一方、元会話の一部を復元できる可能性があるため無期限保存しない。
- AuditLogは監査に必要だが、本文全文を保存すると削除要求や漏洩時の影響が増える。

## Production Gate

| 項目 | 必須条件 | 未対応時の扱い |
| --- | --- | --- |
| 暗号化 | raw/redacted textが暗号化保存される | production DM importを無効化 |
| 鍵管理 | 環境別鍵とrotation手順がある | release blocker |
| 保持期限 | raw 30日以内、redacted/draft 180日以内を既定にする | release blocker |
| 削除 | import単位削除と本文復元不能化がある | release blocker |
| 権限 | project membershipで閲覧/削除を制御する | release blocker |
| 監査 | 本文なしsafe metadataだけをAuditLogへ残す | release blocker |
| AI送信 | redacted優先、scan valid必須 | release blocker |

## Consequences

### Positive

- DM整理MVPを安全にproductionへ近づけられる。
- ユーザーに対して「DM全文を無期限保存しない」と説明できる。
- セキュリティレビューとリリース判定の基準が明確になる。
- 将来のSlack DMやGoogle Drive連携にも同じデータ保持原則を転用できる。

### Negative

- 暗号化、鍵管理、削除、retention jobの実装が必要になり、MVPの実装量が増える。
- 保持期限により、過去会話を再整理したいユーザー体験には制限が出る。
- redactionが不十分な場合、redacted textでも機密情報が残る可能性がある。

## Alternatives Considered

### DB平文保存のままproductionに進む

不採用。

理由:

- DMの性質上、会議ログより漏洩影響が大きい。
- 本文がAuditLogやbackupへ残ると削除要求に対応しづらい。
- 世界レベルSaaSの信頼基準に届かない。

### raw textを保存しない

将来候補。

理由:

- 最も安全だが、AI整理結果の引用根拠、誤要約訂正、監査の説明力が落ちる。
- MVPでは短期保持と暗号化を前提に、レビュー根拠として最小期間だけ保存する方針にする。

### redacted textだけ長期保存する

条件付き採用。

理由:

- 業務価値と安全性のバランスがよい。
- ただしredaction品質が十分でない限り、無期限保存は認めない。

## Implementation Follow-up

- [Todo] `conversation_imports.raw_text` / `redacted_text` の暗号化方式を実装する。
- [Todo] retention policyと削除/匿名化APIをOpenAPIへ追加する。
- [Todo] retention jobをSolid Queueで実装し、staging smoke対象に含める。
- [Todo] project membership導入後、閲覧/削除/承認権限をPolicy Objectへ分離する。
- [Todo] backupとAuditLogに本文が残らないことをsecurity specで固定する。
