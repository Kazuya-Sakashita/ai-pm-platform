# 2026-07-08 Solid Queue worker smoke readiness review

## 評価日時

2026-07-08 11:35:02 JST

## 評価担当

Codex / DevOps / Security Engineer / QA / Tech Lead

## Issue番号

ISSUE-004 / GitHub Issue #4

## 対象

- `scripts/solid-queue-worker-smoke-readiness.rb`
- `docs/release/20260704_solid_queue_staging_worker_smoke_runbook.md`
- Solid Queue staging / production worker smoke準備

## 使用フレームワーク

- G-STACK
- STRIDE
- DORA Metrics
- ISO25010

## 評価サマリー

staging / production worker smokeを手作業SQLと画面確認だけに依存させないため、Rails runner用のread-only readiness scriptを追加した。scriptはActiveJob adapter、Solid Queue table、worker heartbeat、recurring task、queue latency、failed execution count、Queue health release gate、必要secretの存在確認をJSONで出力する。

証跡はpresenceやcount、safe failure codeに限定し、`DATABASE_URL`、`QUEUE_DATABASE_URL`、encryption key、raw exception、backtrace、serialized job arguments、DM本文、AI promptは出力しない。

## 良かった点

- staging / production worker smokeの合否判断を `safe_failures` として機械的に確認できるようになった。
- `--smoke-environment` を使い、Rails runnerの `--environment` と衝突しないようにした。
- production-like環境では `QUEUE_DATABASE_URL` とActive Record Encryption keyの存在を値なしで確認できる。
- cleanup / retention recurring taskがconfiguredかつloadedかを同時に確認できる。
- Queue health APIと同じ安全方針で、worker heartbeat、failed execution、release gate状態を確認できる。

## 改善点

- 実staging / production環境がないため、worker heartbeatとrecurring task loadedの合格証跡はまだ取得できていない。
- local developmentではSolid Queue tableが未準備で、scriptは `solid_queue_tables_unavailable` として安全失敗した。
- `safe_failures` は機械判定できるが、GitHub Actionsやdeploy pipelineの必須gateにはまだ接続していない。
- failed job retry/discardの実操作まではこのscriptで実行しない。操作証跡は既存runbookとtemplateで別途確認が必要。

## 改善案

1. staging deploy後に `--smoke-environment staging --production-like --expect-solid-queue --require-worker` で実行する。
2. `safe_failures` が空のJSONを `docs/review/YYYYMMDD_solid_queue_worker_smoke_review.md` へ保存する。
3. productionではまずobservation-onlyで実行し、release owner承認後に `--require-worker` の合格証跡を保存する。
4. deploy pipelineにreadiness scriptをoptional gateとして組み込み、stagingでは必須化する。
5. failed job retry/discardは安全なstaging failed executionを用意して、既存templateで別証跡化する。

## 優先順位

| 優先度 | 項目 | 理由 |
| --- | --- | --- |
| P0 | stagingでreadiness scriptを実行 | Issue #4のworker smoke残件に直結 |
| P0 | `safe_failures` 空の証跡保存 | 完了判定に必要 |
| P1 | deploy pipeline gate化 | 手作業抜け漏れを防ぐ |
| P1 | failed job retry/discard staging実操作証跡 | 運用復旧機能の本番判断に必要 |
| P2 | production observation-only evidence | 本番公開前の運用確認に必要 |

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | staging / production worker smokeを安全で再現可能な証跡にする |
| Strategy | read-only Rails runnerでworker/queue/recurring/secret presenceをまとめて確認する |
| Tactics | safe JSON、`safe_failures`、runbook接続、secret非出力 |
| Assessment | 実行土台は改善したが、実環境証跡は未取得 |
| Conclusion | scriptとrunbook更新は採用。Issue #4は実staging/prod証跡取得までOPEN |
| Knowledge | worker smokeは「workerが起動した」だけでなく、recurring load、Queue health、failed job release gateまで含める |

## STRIDE / Security

- Spoofing: operatorや環境名は証跡用であり、認証主体としては扱わない。
- Tampering: scriptはread-onlyで、queue databaseやProduct dataを変更しない。
- Repudiation: JSON証跡にchecked_at、environment、safe failuresを残せる。
- Information Disclosure: secret値、DB URL、raw job arguments、raw exception、DM本文を出力しない。
- Denial of Service: worker heartbeat、queue latency、failed execution countを確認対象にした。
- Elevation of Privilege: failed job操作はscriptでは実行せず、既存の権限付きAPI/runbookへ分離した。

## 検証結果

- `ruby -c scripts/solid-queue-worker-smoke-readiness.rb`: Syntax OK
- `ruby scripts/solid-queue-worker-smoke-readiness.rb --smoke-environment local --no-require-worker --no-expect-solid-queue --no-production-like`: `rails_environment_not_loaded` で安全失敗
- Rails runner実行:
  - command: `cd backend && bundle exec ruby bin/rails runner ../scripts/solid-queue-worker-smoke-readiness.rb --smoke-environment local --no-require-worker --no-expect-solid-queue --no-production-like`
  - result: exit 1
  - safe failure: `solid_queue_tables_unavailable`
  - 理由: local development DBではSolid Queue tableが未準備

保存していない情報:

- `DATABASE_URL`
- `QUEUE_DATABASE_URL`
- Rails master key
- Active Record Encryption key
- raw exception / backtrace
- serialized job arguments
- DM body
- AI prompt / model output

## 次アクション

1. staging環境でreadiness scriptを実行し、`safe_failures` が空の証跡を保存する。
2. productionはobservation-onlyから開始し、release owner承認後にworker heartbeat証跡を保存する。
3. failed job retry/discard staging smokeを既存templateで実施する。
4. GitHub Issue #4へstaging/prod実行結果を同期する。

## 結論

Solid Queue worker smokeの実行準備は一段前進した。ただし、世界レベルSaaS基準ではlocal script追加だけでは完了ではない。staging / production-equivalent環境で、worker heartbeat、recurring task loaded、Queue health、failed job release gate、secret非露出を実証するまでISSUE-004は継続OPENとする。
