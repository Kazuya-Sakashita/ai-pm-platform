# JWT key rotation runbook gate design review

## 評価日時

2026-07-06 07:28:46 JST

## 評価担当

- Codex
- Security Engineer
- DevOps
- CTO
- QA

外部AIレビュー: Claude/ChatGPTレビューは未実施。現時点ではCodex一次レビューとして保存し、外部AIレビュー結果が追加された場合は差分分析を追記する。

## 使用フレームワーク

- G-STACK
- STRIDE
- DORA Metrics
- ISO25010

## 対象

- Issue: ISSUE-047 / GitHub #47
- `docs/issue/ISSUE-047_jwt_key_rotation_smoke_runbook_gate.md`
- `docs/release/20260706_jwt_key_rotation_runbook.md`
- `docs/decisions/ADR-0017_jwt_revocation_session_key_rotation.md`
- `backend/app/services/authentication/keyring.rb`
- `.github/workflows/ci.yml`

## G-STACK

### Goal

JWT key rotationを、通常rotationと緊急compromiseの両方で、再現可能、監査可能、かつ本番事故を防げるrelease gateへ引き上げる。

### Strategy

人手runbookだけでなく、CI/CDまたはdeploy preflightで機械的に失敗させる検証コマンドを追加する。staging smokeとproduction gateは同じkeyring schemaを使い、secret値は表示、保存、ログ出力しない。

### Tactics

- keyring JSONを検証するscriptを追加する。
- production/stagingではinline secretを禁止し、`secret_env` 参照と環境変数存在を検証する。
- `kid` 重複、active key数、rotation window、invalid status、invalid timeをrelease前に落とす。
- staging smoke evidence templateを `docs/review/` に保存する。
- CIにfixture validationを追加し、gateの破損を検知する。

### Assessment

現状runbookは運用手順として読みやすいが、release gateが文書依存であり、production misconfigurationを自動で止められない。特にactive key二重設定、inline secret混入、rotation中のverify-only欠落、期限切れkeyの残留は、世界レベルSaaS基準ではP1リスクである。

### Conclusion

ISSUE-047は実装に進める。ただし、完了条件は「runbook追記」では足りない。CI/CDで実行可能なkeyring validationと、staging未実施時の明確な待ち理由、production gate checklist、証跡templateまで含めて完了とする。

### Knowledge

- key compromise時は、disabled keyにsecret materialを要求しない方が安全である。
- 本番gateはsecret値ではなく、secret参照名と存在確認だけを扱う。
- smoke evidenceは成功ログよりも、失敗時のsafe error codeとrollback禁止条件を残すことが重要である。

## 良かった点

- ADR-0017で `kid/sid/sv/jti`、session revoke、key rotation、safe error contractが整理されている。
- 既存runbookに通常rotation、rollback、emergency compromise、session revocationの大枠がある。
- Keyring実装は `active`、`verify_only`、`retired`、`disabled` を扱えるため、運用gateへ接続しやすい。
- CIが既にRSpec、OpenAPI、表示ラベル、frontend build、E2Eまで通す構成になっている。

## 改善点

- production/staging keyringを機械的に検証するrelease gateがない。
- runbookに実行コマンド、expected result、evidence template、staging未実施時の記録方法が不足している。
- disabled/retired keyをsecret materialなしで扱う方針が明文化されていない。
- monitoring/alert項目は設計書にあるが、rotation smokeの合否判定に接続されていない。
- CIでgate script自体の退行を検知するfixture validationがない。

## 優先順位

- P1: keyring validation scriptとCI fixture validationを追加する。
- P1: production/stagingではinline secretを禁止し、`secret_env` 存在を検証する。
- P1: staging smoke evidence templateを `docs/review/` に保存する。
- P1: runbookへrollback可能期間、rollback禁止条件、emergency disabled `kid` 手順、monitoring合否を追記する。
- P2: 将来、cloud secret store/KMSと連携するdeploy provider別preflightへ拡張する。

## 次アクション

1. `scripts/validate-jwt-keyring.rb` を追加する。
2. `package.json` に `jwt:keyring:validate` を追加する。
3. CIでexample keyringをrotation mode検証する。
4. runbookとevidence templateを更新する。
5. RSpecとlocal validationを実行し、実装レビューを保存する。

## Issue番号

ISSUE-047 / GitHub #47
