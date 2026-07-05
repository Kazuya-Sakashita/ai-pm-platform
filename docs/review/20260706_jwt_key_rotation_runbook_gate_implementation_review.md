# JWT key rotation runbook gate implementation review

## 評価日時

2026-07-06 07:32:43 JST

## 評価担当

- Codex
- Security Engineer
- DevOps
- QA
- CTO

外部AIレビュー: Claude/ChatGPTレビューは未実施。現時点ではCodex一次レビューとして保存し、外部AIレビュー結果が追加された場合は差分分析を追記する。

## 使用フレームワーク

- G-STACK
- STRIDE
- DORA Metrics
- ISO25010

## 対象

- Issue: ISSUE-047 / GitHub #47
- `scripts/validate-jwt-keyring.rb`
- `.github/workflows/ci.yml`
- `docs/release/20260706_jwt_key_rotation_runbook.md`
- `docs/release/examples/jwt-keyring.staging-smoke.example.json`
- `docs/review/20260706_jwt_key_rotation_staging_smoke_evidence_template.md`
- `backend/app/services/authentication/keyring.rb`

## G-STACK

### Goal

JWT key rotationをproduction deploy前に機械的に検証し、staging smokeとemergency key disableの証跡を残せる状態にする。

### Strategy

本番secret値を扱わず、`secret_env` 参照、active key数、rotation window、disabled/retired keyの安全な扱いをrelease gateで検証する。

### Tactics

- `npm run jwt:keyring:validate` を追加した。
- CIにstaging smoke fixture validationを追加した。
- staging/production/emergencyの実行手順をrunbookへ追記した。
- staging smoke evidence templateを `docs/review/` に追加した。
- retired/disabled keyはsecret materialなしでも拒否できるようにした。

### Assessment

人手runbookから、最低限の機械検証を持つrelease gateへ進んだ。inline secret混入、active key二重設定、secret env欠落、verify-only keyのretirement漏れを事前に落とせるようになった点は大きい。一方で、live staging smoke、production secret store連携、monitoring dashboard/alert設定はまだ実環境待ちである。

### Conclusion

ISSUE-047のrepo内完了条件は満たした。ただし世界レベルSaaS基準では、staging/productionの実環境証跡が未取得であるため、リリース判定時にはevidence templateを使ったlive smokeを必須gateとして残す。

### Knowledge

- disabled/retired keyにsecret materialを要求しないことで、compromise後にsecretを安全に削除できる。
- release gateはsecret値ではなくsecret参照と存在だけを検証する。
- CI fixtureはgate scriptの退行検知であり、live staging smokeの代替ではない。

## 良かった点

- keyring validationをCLI化し、CI/CDと手元の両方で実行できるようにした。
- staging/productionではinline secretを禁止し、`secret_env` 参照を必須にした。
- rotation modeでverify-only keyの `retire_after` を必須化した。
- CIにdummy secret env付きfixture validationを追加し、gateの退行を検知できるようにした。
- emergency compromise時にdisabled keyをsecret materialなしで扱えるようにした。
- evidence templateがAGENTS.mdのレビュー必須項目を含む形で保存された。

## 改善点

- live staging environmentがないため、実トークンを使ったdual-verify smokeは未実施。
- monitoring/alertはrunbook checklistであり、実dashboardやalert ruleとしては未設定。
- production deploy systemにpreflightを強制する仕組みは、GitHub Actions fixture validationまでで止まっている。
- keyring JSON schemaをOpenAPI/JSON Schemaとして共有していないため、外部deploy toolingとの型契約は弱い。
- emergency drillは文書化されたが、定期演習のスケジュールとownerは未設定。

## 優先順位

- P1: staging環境作成後、evidence templateに沿ってlive dual-verify smokeを実施する。
- P1: production deploy workflowに `npm run jwt:keyring:validate -- --environment production --mode steady` を必須preflightとして組み込む。
- P1: `signing_key_unknown`、`signing_key_retired`、`signing_key_not_active` のalert ruleを実環境で設定する。
- P2: keyring configのJSON Schemaを作成し、secret store/deploy toolingでも同じschemaを使う。
- P2: quarterly emergency key compromise drillをrelease calendarへ追加する。

## 次アクション

1. PRでGitHub CIを通し、Issue #47へ証跡を同期する。
2. staging環境が用意できた時点でlive smoke evidenceを追加する。
3. production deploy workflowが確定したらpreflight必須化を別Issueで追跡する。

## Issue番号

ISSUE-047 / GitHub #47

## 検証

- `ruby -c scripts/validate-jwt-keyring.rb`: pass
- `npm run jwt:keyring:validate -- --file docs/release/examples/jwt-keyring.staging-smoke.example.json --environment staging --mode rotation --now 2026-07-06T00:30:00Z`: pass
- `bundle exec rspec spec/scripts/validate_jwt_keyring_spec.rb spec/services/authentication/jwt_verifier_spec.rb`: 22 examples, 0 failures
- `bundle exec rspec`: 249 examples, 0 failures
- `npm run api:verify`: pass
- `npm run display:check`: pass
