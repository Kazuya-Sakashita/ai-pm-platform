# ADR-0018: Product JobとSolid Queue jobの明示マッピング

## Status

Accepted

## Date

2026-07-07

## Context

failed job retry/discard操作では、Solid Queue failed executionからProject境界を検証する必要がある。ISSUE-059ではMVPとしてSolid Queue job argumentsからProduct Job ID候補を復元している。

ただし、この方式はActiveJobの引数構造に依存する。job引数の形式変更、複数Product Job IDの混入、別種jobの追加があると、境界検証が不安定になる。

## Decision

Product JobとSolid Queue jobの対応を `job_queue_mappings` tableへ保存する。

保存する主な値:

- Project ID
- Product Job ID
- provider
- Solid Queue job ID
- ActiveJob ID
- queue name
- job class name
- scheduled at

Resolverは以下の順番でProject境界を検証する。

1. `job_queue_mappings` の明示マッピングを優先する。
2. マッピングがない既存jobでは、従来どおりSolid Queue argumentsからProduct Job ID候補を復元する。
3. 複数候補、未解決、Project mismatchは安全側で操作拒否する。

## Alternatives

### Product jobs tableへ `solid_queue_job_id` を追加

単純だが、同一Product Jobが複数回rescheduleされる場合に過去のSolid Queue job IDを保持できない。failed executionが古いSolid Queue jobを指す場合、境界検証が不安定になる。

### AuditLogへenqueue情報を保存

監査には有効だが、failed job操作時の一意なlookupには向かない。検索条件が複雑になり、Project境界検証の責務がAuditLogに寄りすぎる。

### arguments復元だけを継続

既存実装のまま最小だが、ActiveJob payloadへの依存が残るため、長期運用の安全性が不足する。

## Consequences

良い影響:

- failed job操作のProject境界を明示的な保存データで検証できる。
- 同一Product Jobの複数Solid Queue job履歴を保持できる。
- retry後再失敗率などSLO計測の前提が整う。
- 既存jobはfallbackで扱えるため、段階移行できる。

注意点:

- enqueue後にmapping保存が失敗した場合、既存fallbackへ戻る。ただし新規jobではmapping保存失敗をAuditLogへ安全に残す必要がある。
- Solid Queue以外のqueue providerを導入する場合はprovider列を拡張する。

## Follow-up

- ISSUE-062 / GitHub Issue #94で実装する。
- ISSUE-063 / GitHub Issue #96でretry後再失敗率、通知、承認gateへ接続する。
