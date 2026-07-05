# ISSUE-047: JWT key rotation staging smokeとproduction runbook gateを整備する

## Issue番号

ISSUE-047

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/47

登録日: 2026-07-06

## 背景

ISSUE-042でJWT key rotation runbookを作成したが、staging/production環境でのsmoke、monitoring、release gate、emergency key compromise手順はまだ実証されていない。

## 目的

JWT key rotationを運用可能にするため、staging smoke、production release gate、monitoring/alert、evidence保存手順を整備する。

## 完了条件

- [x] staging normal rotation smoke手順が実行または実行待ち理由付きで保存されている
- [x] emergency compromised `kid` disable手順がある
- [x] rollback可能期間とrollback禁止条件が定義されている
- [x] monitoring/alert項目が定義されている
- [x] production release gateにkeyring validationが入っている
- [x] evidence templateが `docs/review/` に保存できる
- [x] DevOps/Securityレビューが `docs/review/` に保存されている

## スコープ

- Runbook hardening
- staging smoke
- release gate
- monitoring/alert checklist
- CI/CD validation方針
- emergency operation evidence

## 非スコープ

- keyring backend implementation
- IdP/JWKS integration
- cloud provider specific KMS implementation

## 関連レビュー

- `docs/review/20260706_jwt_revocation_session_key_rotation_design_review.md`
- `docs/review/20260706_jwt_key_rotation_runbook_gate_design_review.md`
- `docs/review/20260706_jwt_key_rotation_runbook_gate_implementation_review.md`
- `docs/review/20260706_jwt_key_rotation_staging_smoke_evidence_template.md`

## 関連ADR

- `docs/decisions/ADR-0017_jwt_revocation_session_key_rotation.md`

## レビュー結果

Security/DevOps Agentは、normal rotation、emergency key compromise、unknown/retired `kid` monitoring、production misconfiguration gateをP1運用要件として指摘した。

2026-07-06 implementation reviewでは、repo内release gate、CI fixture validation、runbook/evidence templateは完了と判断した。一方で、live staging smoke、production secret store連携、monitoring dashboard/alert ruleは実環境待ちであり、release判定時のP1 gateとして残す。

## 優先度

P1

理由:

- keyringを実装してもrotationを実証しなければproduction trustに届かない
- key compromise時の初動が遅れると全API trustが崩れる
- release gateに組み込むことで設定ミスを早期に止められる

## 次アクション

1. PRでGitHub CIを通し、GitHub Issue #47へ同期する。
2. staging環境が用意できたら `docs/review/20260706_jwt_key_rotation_staging_smoke_evidence_template.md` に沿ってlive smokeを実施する。
3. production deploy workflow確定時に `npm run jwt:keyring:validate -- --environment production --mode steady` を必須preflightとして組み込む。
4. monitoring/alert ruleを実環境で作成し、rotation evidenceへ追記する。

## 実装内容

- `scripts/validate-jwt-keyring.rb` を追加し、keyring JSONをrelease gateとして検証できるようにした。
- `package.json` に `jwt:keyring:validate` を追加した。
- CIにstaging smoke fixture validationを追加した。
- `docs/release/examples/jwt-keyring.staging-smoke.example.json` を追加した。
- `docs/release/20260706_jwt_key_rotation_runbook.md` にstaging/production/emergency gate、rollback禁止条件、monitoring/alert、evidence保存手順を追記した。
- `docs/review/20260706_jwt_key_rotation_staging_smoke_evidence_template.md` を追加した。
- retired/disabled keyをsecret materialなしでも安全に拒否できるようにした。

## 検証結果

- `ruby -c scripts/validate-jwt-keyring.rb`: pass
- `npm run jwt:keyring:validate -- --file docs/release/examples/jwt-keyring.staging-smoke.example.json --environment staging --mode rotation --now 2026-07-06T00:30:00Z`: pass
- `bundle exec rspec spec/scripts/validate_jwt_keyring_spec.rb spec/services/authentication/jwt_verifier_spec.rb`: 22 examples, 0 failures
- `bundle exec rspec`: 249 examples, 0 failures
- `npm run api:verify`: pass
- `npm run display:check`: pass

## 実環境待ち

- live staging dual-verify smokeは、デプロイ済みstaging環境とsecret store injectionが未提供のため未実施。
- production preflightは実行可能なscriptとして整備済みだが、production deploy workflowへの強制組み込みは環境確定後に実施する。
- monitoring/alert ruleはrunbook checklistとして定義済みだが、実dashboard/alertの証跡はstaging/production環境で取得する。
