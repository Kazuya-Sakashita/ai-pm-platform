# JWT key rotation staging smoke evidence template

## 評価日時

YYYY-MM-DD HH:MM:SS TZ

## 評価担当

- Operator:
- Reviewer:
- Security approver:
- Release approver:

## 使用フレームワーク

- STRIDE
- DORA Metrics
- ISO25010

## Issue番号

ISSUE-047 / GitHub #47

## 実施状況

- [ ] 実施済み
- [ ] 未実施

未実施の場合:

- 待ち理由:
- owner:
- target environment:
- next execution date:

## 対象環境

- environment:
- application URL:
- API URL:
- commit SHA:
- deploy ID:
- keyring source:

## Gate Result

実行コマンド:

```bash
npm run jwt:keyring:validate -- --environment staging --mode rotation
```

結果:

- exit code:
- active `kid`:
- verify-capable `kid` list:
- disabled `kid` list:
- retired `kid` list:
- inline secret detected: no
- missing secret env detected: no

## Smoke Result

- old verify-only `kid` token verification:
- new active `kid` token verification:
- `GET /api/v1/auth/sessions` with active `kid`:
- retired `kid` rejection code:
- disabled `kid` rejection code:
- unknown `kid` rejection code:

Expected safe error codes:

- retired: `signing_key_retired`
- disabled: `signing_key_not_active`
- unknown: `signing_key_unknown`

## Monitoring Result

- unknown `kid` count:
- retired key usage count:
- disabled key usage count:
- token/session revoke count:
- auth p95/p99:
- `authentication_not_configured` count:
- secret store failure count:
- alert status:

## Rollback Window

- max access token TTL:
- clock skew:
- deployment buffer:
- rollback allowed until:
- rollback owner:
- rollback approver:
- rollback prohibited conditions checked:

## Emergency Compromise Drill

- compromised `kid` disabled:
- raw secret removed from deployable keyring JSON:
- session revoke scope:
- high-risk operations paused:
- safe error observed:
- critical security event ID:

## 良かった点

- 

## 改善点

- 

## 優先順位

- P1:
- P2:

## 次アクション

1. 

## 結論

- [ ] pass
- [ ] fail
- [ ] blocked

理由:

## Secret Handling Confirmation

- [ ] raw JWT was not saved
- [ ] signing secret was not saved
- [ ] raw `jti` was not saved
- [ ] session ID was not saved
- [ ] full IP/User-Agent was not saved
